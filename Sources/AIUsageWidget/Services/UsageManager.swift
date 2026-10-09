import Foundation
import Combine
import AppKit

class UsageManager: ObservableObject {
    static let shared = UsageManager()
    
    @Published var claudeData = ClaudeUsageData()
    @Published var codexData = CodexUsageData()
    @Published var antigravityData = AntigravityUsageData()
    @Published var combinedDailyPoints: [CombinedDailyPoint] = []
    @Published var lastRefreshed: Date = Date()
    @Published var isRefreshing: Bool = false
    @Published var selectedTab: AppTab = .overview
    
    @Published var refreshIntervalSeconds: Double = 60.0 {
        didSet {
            UserDefaults.standard.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds")
            setupTimer()
        }
    }
    
    @Published var showQuotaInMenuBar: Bool = true {
        didSet {
            UserDefaults.standard.set(showQuotaInMenuBar, forKey: "showQuotaInMenuBar")
        }
    }
    
    @Published var showTodayTokensInMenuBar: Bool = true {
        didSet {
            UserDefaults.standard.set(showTodayTokensInMenuBar, forKey: "showTodayTokensInMenuBar")
        }
    }
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let savedRefreshInterval = UserDefaults.standard.object(forKey: "refreshIntervalSeconds") as? Double ?? 60.0
        self.refreshIntervalSeconds = savedRefreshInterval
        let savedShowQuota = UserDefaults.standard.object(forKey: "showQuotaInMenuBar") as? Bool ?? true
        self.showQuotaInMenuBar = savedShowQuota
        self.showTodayTokensInMenuBar = UserDefaults.standard.object(forKey: "showTodayTokensInMenuBar") as? Bool ?? true
        
        refreshData()
        setupTimer()
    }
    
    func refreshData() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        // Each reader shells out to its own CLI (several seconds apiece), so
        // fetch them concurrently and wait for the slowest.
        var claude = ClaudeUsageData()
        var codex = CodexUsageData()
        var antigravity = AntigravityUsageData()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async(group: group) { claude = ClaudeDataReader.shared.fetchUsageData() }
        queue.async(group: group) { codex = CodexDataReader.shared.fetchUsageData() }
        queue.async(group: group) { antigravity = AntigravityDataReader.shared.fetchUsageData() }

        group.notify(queue: queue) { [weak self] in
            let combined = Self.computeCombinedPoints(claude: claude, codex: codex, antigravity: antigravity)

            DispatchQueue.main.async {
                self?.claudeData = Self.mergeClaudeSnapshot(new: claude, previous: self?.claudeData)
                self?.codexData = codex
                if antigravity.hasLiveStatus || self?.antigravityData.hasLiveStatus != true {
                    self?.antigravityData = antigravity
                } else {
                    var retained = antigravity
                    retained.quotaWindows = self?.antigravityData.quotaWindows ?? []
                    retained.accountEmail = self?.antigravityData.accountEmail ?? ""
                    retained.accountPlan = self?.antigravityData.accountPlan ?? ""
                    retained.liveSource = self?.antigravityData.liveSource ?? ""
                    retained.quotaFetchedAt = self?.antigravityData.quotaFetchedAt
                    retained.liveError = "Last live quota snapshot; open Antigravity to refresh"
                    retained.hasLiveStatus = false
                    self?.antigravityData = retained
                }
                self?.combinedDailyPoints = combined
                self?.lastRefreshed = Date()
                self?.isRefreshing = false
            }
        }
    }
    
    private func setupTimer() {
        timer?.invalidate()
        guard refreshIntervalSeconds > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }
    
    static func computeCombinedPoints(
        claude: ClaudeUsageData,
        codex: CodexUsageData,
        antigravity: AntigravityUsageData = AntigravityUsageData(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CombinedDailyPoint] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        
        var claudeTokensMap: [String: Int64] = [:]
        var claudeSessionsMap: [String: Int] = [:]
        var codexTokensMap: [String: Int64] = [:]
        var codexSessionsMap: [String: Int] = [:]
        var antigravityTokensMap: [String: Int64] = [:]
        var antigravitySessionsMap: [String: Int] = [:]
        
        for item in claude.dailyModelTokens {
            claudeTokensMap[item.date, default: 0] += item.totalTokens
        }
        for item in claude.dailyActivity {
            claudeSessionsMap[item.date, default: 0] += item.sessionCount
        }
        for item in codex.dailyUsage {
            codexTokensMap[item.date, default: 0] += item.tokensUsed
            codexSessionsMap[item.date, default: 0] += item.sessionCount
        }
        for item in antigravity.dailyUsage {
            antigravityTokensMap[item.date, default: 0] += item.tokensUsed
            antigravitySessionsMap[item.date, default: 0] += item.sessionCount
        }
        
        // Generate the last 14 calendar dates. Future-dated or malformed cache
        // entries must not shift the visible window away from today.
        var recentDates: [String] = []
        for dayOffset in (0..<14).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                recentDates.append(formatter.string(from: date))
            }
        }
        
        return recentDates.map { date in
            CombinedDailyPoint(
                date: date,
                codexTokens: codexTokensMap[date] ?? 0,
                claudeTokens: claudeTokensMap[date] ?? 0,
                antigravityTokens: antigravityTokensMap[date] ?? 0,
                codexSessions: codexSessionsMap[date] ?? 0,
                claudeSessions: claudeSessionsMap[date] ?? 0,
                antigravitySessions: antigravitySessionsMap[date] ?? 0
            )
        }
    }
    
    static func formatTokens(_ count: Int64) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.2fB", Double(count) / 1_000_000_000.0)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }

    /// A timed-out or flaky `claude -p /usage` shouldn't wipe the quota
    /// display, so carry the last live reading forward (marked stale).
    /// Sign-out is never masked: it needs the user to act.
    static func mergeClaudeSnapshot(new: ClaudeUsageData, previous: ClaudeUsageData?) -> ClaudeUsageData {
        guard !new.hasLiveStatus,
              new.liveIssue == .unavailable,
              let previous, previous.hasLiveStatus else { return new }
        var merged = new
        merged.hasLiveStatus = true
        merged.isStaleSnapshot = true
        merged.sessionUsedPct = previous.sessionUsedPct
        merged.sessionReset = previous.sessionReset
        merged.weekAllModelsPct = previous.weekAllModelsPct
        merged.weekAllModelsReset = previous.weekAllModelsReset
        merged.weekFablePct = previous.weekFablePct
        merged.weekFableReset = previous.weekFableReset
        merged.weekModelLabel = previous.weekModelLabel
        return merged
    }

    static func claudeWeeklyMenuBarText(for data: ClaudeUsageData) -> String? {
        if data.hasLiveStatus {
            return "\(Int(round(data.weekAllModelsPct)))%"
        } else if data.liveIssue == .signedOut {
            return "Expired"
        }
        return nil
    }

    /// Today's combined token count, or nil when the user hid it or when
    /// it would just be a lone "0" next to the quota percentages.
    static func todayTokensMenuBarText(total: Int64, showTodayTokens: Bool, showQuota: Bool) -> String? {
        guard showTodayTokens else { return nil }
        if total == 0 && showQuota { return nil }
        return formatTokens(total)
    }

    static func codexWeeklyMenuBarText(for data: CodexUsageData) -> String? {
        guard let weekly = data.weeklyLimitUsedPct else { return nil }
        return "\(Int(round(weekly)))%"
    }

    static func antigravityWeeklyMenuBarText(for data: AntigravityUsageData) -> String? {
        guard data.hasLiveStatus, let weekly = data.weeklyUsedPercent else { return nil }
        return "\(Int(round(weekly)))%"
    }
    
    var menuBarImage: NSImage {
        let total = codexData.todayTokens + claudeData.todayTokens + antigravityData.todayTokens
        let totalStr = Self.todayTokensMenuBarText(
            total: total,
            showTodayTokens: showTodayTokensInMenuBar,
            showQuota: showQuotaInMenuBar
        )
        let claudeText = Self.claudeWeeklyMenuBarText(for: claudeData)
        let codexText = Self.codexWeeklyMenuBarText(for: codexData)
        let antigravityText = Self.antigravityWeeklyMenuBarText(for: antigravityData)
        
        return BrandAssets.shared.createMenuBarImage(
            totalTokensText: totalStr,
            claudeText: claudeText,
            codexText: codexText,
            antigravityText: antigravityText,
            showQuota: showQuotaInMenuBar
        )
    }
    
    var menuBarTitle: String {
        let total = codexData.todayTokens + claudeData.todayTokens + antigravityData.todayTokens
        let tokensStr = "⚡️ \(Self.formatTokens(total))"
        
        guard showQuotaInMenuBar else {
            return tokensStr
        }
        
        var parts: [String] = [tokensStr]
        
        if let claudeText = Self.claudeWeeklyMenuBarText(for: claudeData) {
            parts.append("🧠 \(claudeText)")
        }
        
        if let codexText = Self.codexWeeklyMenuBarText(for: codexData) {
            parts.append("💻 \(codexText)")
        }
        if let antigravityText = Self.antigravityWeeklyMenuBarText(for: antigravityData) {
            parts.append("🚀 \(antigravityText)")
        }
        
        return parts.joined(separator: "  ")
    }
}
