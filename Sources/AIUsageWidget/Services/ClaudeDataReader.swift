import Foundation
import AppKit

class ClaudeDataReader {
    static let shared = ClaudeDataReader()
    
    private let statsFilePath: String
    private let claudeBinaryPath: String
    private let transcriptScanner = ClaudeTranscriptScanner()
    
    init(customPath: String? = nil) {
        if let path = customPath {
            self.statsFilePath = path
        } else {
            self.statsFilePath = NSString(string: "~/.claude/stats-cache.json").expandingTildeInPath
        }
        
        let candidates = [
            NSString(string: "~/.local/bin/claude").expandingTildeInPath,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        self.claudeBinaryPath = candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        } ?? ""
    }
    
    func fetchUsageData() -> ClaudeUsageData {
        var data = ClaudeUsageData()
        let fileURL = URL(fileURLWithPath: statsFilePath)
        
        // 1. Read JSON stats-cache.json for historical daily tokens and messages
        if FileManager.default.fileExists(atPath: statsFilePath),
           let jsonData = try? Data(contentsOf: fileURL),
           let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            data.lastComputedDate = root["lastComputedDate"] as? String ?? ""
            data.totalSessions = root["totalSessions"] as? Int ?? 0
            data.totalMessages = root["totalMessages"] as? Int ?? 0
            
            // Parse dailyActivity
            if let activityArray = root["dailyActivity"] as? [[String: Any]] {
                data.dailyActivity = activityArray.compactMap { dict in
                    guard let date = dict["date"] as? String else { return nil }
                    return ClaudeDailyActivity(
                        date: date,
                        messageCount: dict["messageCount"] as? Int ?? 0,
                        sessionCount: dict["sessionCount"] as? Int ?? 0,
                        toolCallCount: dict["toolCallCount"] as? Int ?? 0
                    )
                }
            }
            
            // Parse dailyModelTokens
            if let tokensArray = root["dailyModelTokens"] as? [[String: Any]] {
                data.dailyModelTokens = tokensArray.compactMap { dict in
                    guard let date = dict["date"] as? String,
                          let rawByModel = dict["tokensByModel"] as? [String: Any] else { return nil }
                    
                    var byModel: [String: Int64] = [:]
                    for (k, v) in rawByModel {
                        if let valNum = v as? NSNumber {
                            byModel[k] = valNum.int64Value
                        }
                    }
                    return ClaudeDailyModelTokens(date: date, tokensByModel: byModel)
                }
            }
            
            // Parse modelUsage
            if let modelDict = root["modelUsage"] as? [String: [String: Any]] {
                data.modelUsage = modelDict.map { (modelName, details) in
                    let input = (details["inputTokens"] as? NSNumber)?.int64Value ?? 0
                    let output = (details["outputTokens"] as? NSNumber)?.int64Value ?? 0
                    let cacheRead = (details["cacheReadInputTokens"] as? NSNumber)?.int64Value ?? 0
                    let cacheCreate = (details["cacheCreationInputTokens"] as? NSNumber)?.int64Value ?? 0
                    
                    return ClaudeModelDetail(
                        modelName: modelName,
                        inputTokens: input,
                        outputTokens: output,
                        cacheReadInputTokens: cacheRead,
                        cacheCreationInputTokens: cacheCreate
                    )
                }.sorted { $0.totalTokens > $1.totalTokens }
            }
        }
        
        // 2. Fill in days stats-cache.json hasn't caught up on (it can lag
        // by weeks) from the session transcripts.
        mergeRecentStatsFromTranscripts(&data)

        // 3. Execute claude -p /usage CLI command for live subscription status
        fetchLiveCLIUsage(&data)

        return data
    }

    /// Fills in every day after stats-cache.json's `lastComputedDate` from
    /// the session transcripts, and adds those days to the all-time totals.
    private func mergeRecentStatsFromTranscripts(_ data: inout ClaudeUsageData) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"

        // Days up to and including lastComputedDate are already in the
        // cache's totals; anything newer must be added on top.
        let lastComputed = dayFormatter.date(from: data.lastComputedDate)
        var cutoff = Date.distantPast
        if let lastComputed, let next = calendar.date(byAdding: .day, value: 1, to: lastComputed) {
            cutoff = calendar.startOfDay(for: next)
        }
        // Always rescan today, even if the cache claims to cover it, since
        // the cache can be written mid-day.
        cutoff = min(cutoff, startOfToday)

        let summary = transcriptScanner.scan(since: cutoff)
        let recentDays = Set(summary.tokensByDay.keys).union(summary.activityByDay.keys)
        guard !recentDays.isEmpty else { return }

        data.dailyModelTokens.removeAll { recentDays.contains($0.date) }
        data.dailyActivity.removeAll { recentDays.contains($0.date) }
        for day in recentDays {
            if let models = summary.tokensByDay[day] {
                data.dailyModelTokens.append(ClaudeDailyModelTokens(
                    date: day,
                    tokensByModel: models.mapValues(\.total)
                ))
            }
            if let activity = summary.activityByDay[day] {
                data.dailyActivity.append(ClaudeDailyActivity(
                    date: day,
                    messageCount: activity.messageCount,
                    sessionCount: activity.sessionIDs.count,
                    toolCallCount: activity.toolCallCount
                ))
            }
        }
        data.dailyModelTokens.sort { $0.date < $1.date }
        data.dailyActivity.sort { $0.date < $1.date }

        // All-time totals: only add days the cache hasn't counted yet.
        let cachedThrough = data.lastComputedDate
        let isNew: (String) -> Bool = { cachedThrough.isEmpty || $0 > cachedThrough }
        var models = Dictionary(data.modelUsage.map { ($0.modelName, $0) }, uniquingKeysWith: { first, _ in first })
        for (day, byModel) in summary.tokensByDay where isNew(day) {
            for (name, counts) in byModel {
                let existing = models[name]
                models[name] = ClaudeModelDetail(
                    modelName: name,
                    inputTokens: (existing?.inputTokens ?? 0) + counts.input,
                    outputTokens: (existing?.outputTokens ?? 0) + counts.output,
                    cacheReadInputTokens: (existing?.cacheReadInputTokens ?? 0) + counts.cacheRead,
                    cacheCreationInputTokens: (existing?.cacheCreationInputTokens ?? 0) + counts.cacheCreation
                )
            }
        }
        data.modelUsage = models.values.sorted { $0.totalTokens > $1.totalTokens }
        data.totalMessages += summary.activityByDay
            .filter { isNew($0.key) }
            .reduce(0) { $0 + $1.value.messageCount }
        data.totalSessions += summary.sessionStarts.values
            .filter { isNew(dayFormatter.string(from: $0)) }
            .count
    }
    
    private func fetchLiveCLIUsage(_ data: inout ClaudeUsageData) {
        guard !claudeBinaryPath.isEmpty else {
            data.liveIssue = .cliMissing
            return
        }

        guard let result = runCLI(arguments: [
            "-p", "/usage",
            "--output-format", "json",
            "--tools", "",
            "--no-session-persistence"
        ], timeout: 15) else {
            data.liveIssue = .unavailable
            return
        }

        // With --output-format json the report (or the error message) is in
        // "result"; fall back to the raw text for older CLI versions.
        var reportText = result.stdout
        if let jsonData = result.stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let text = json["result"] as? String {
            reportText = text
        }

        if result.status == 0 {
            parseUsageText(reportText, into: &data)
        }
        guard !data.hasLiveStatus else { return }

        if Self.isAuthFailure(result.stdout + "\n" + result.stderr) || !isLoggedIn() {
            data.liveIssue = .signedOut
        } else {
            data.liveIssue = .unavailable
        }
    }

    /// Messages the Claude CLI prints when it has no usable credentials,
    /// e.g. "Not logged in · Please run /login" or
    /// "OAuth token has expired. Please obtain a new token…".
    static func isAuthFailure(_ output: String) -> Bool {
        let text = output.lowercased()
        let markers = [
            "/login", "not logged in", "log in", "oauth", "token has expired",
            "token expired", "invalid api key", "authentication_error", "unauthorized"
        ]
        return markers.contains { text.contains($0) }
    }

    /// `claude auth status --json` is fast and does not hit the network, so
    /// it is a cheap way to tell "signed out" from "network hiccup".
    private func isLoggedIn() -> Bool {
        guard let result = runCLI(arguments: ["auth", "status", "--json"], timeout: 5),
              let jsonData = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let loggedIn = json["loggedIn"] as? Bool else {
            // Unknown: don't claim the user is signed out.
            return true
        }
        return loggedIn
    }

    /// Runs the Claude CLI with a clean environment. Returns nil on launch
    /// failure or timeout.
    private func runCLI(arguments: [String], timeout: TimeInterval) -> (status: Int32, stdout: String, stderr: String)? {
        let homeDir = NSHomeDirectory()
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "dev.aiusagetracker.app", isDirectory: true)
            .appendingPathComponent("cli_workdir", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: claudeBinaryPath)
        task.arguments = arguments
        task.currentDirectoryURL = workDirectory
        
        // Clean environment: avoid setting SHELL to prevent loading login shell configs (.zprofile, .zshrc)
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:\(homeDir)/.local/bin"
        env["HOME"] = homeDir
        env["USER"] = NSUserName()
        env["TERM"] = "dumb"
        env["CI"] = "1"
        env["NO_COLOR"] = "1"
        env.removeValue(forKey: "SHELL")
        task.environment = env
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        task.standardInput = FileHandle.nullDevice
        
        do {
            try task.run()
        } catch {
            return nil
        }
        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if task.isRunning {
            task.terminate()
            return nil
        }
        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (task.terminationStatus, stdout, stderr)
    }

    /// Opens a terminal window running `claude auth login`. Uses a
    /// `.command` file so it opens in the user's default terminal app and
    /// needs no Apple Events / Automation permission.
    @discardableResult
    func openLoginInTerminal() -> Bool {
        guard !claudeBinaryPath.isEmpty else { return false }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "dev.aiusagetracker.app", isDirectory: true)
        let scriptURL = dir.appendingPathComponent("claude-login.command")
        let quotedBinary = "'" + claudeBinaryPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let script = """
        #!/bin/zsh
        clear
        echo "Signing in to Claude Code..."
        echo
        \(quotedBinary) auth login
        echo
        echo "Done. You can close this window; the usage widget picks up the new session on its next refresh."
        """

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        } catch {
            return false
        }
        return NSWorkspace.shared.open(scriptURL)
    }
    
    private func parseUsageText(_ text: String, into data: inout ClaudeUsageData) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Current session:") {
                if let pct = extractPercentage(trimmed) {
                    data.sessionUsedPct = pct
                    data.hasLiveStatus = true
                }
                if let resets = extractResetText(trimmed) {
                    data.sessionReset = resets
                }
            } else if trimmed.contains("Current week (all models):") {
                if let pct = extractPercentage(trimmed) {
                    data.weekAllModelsPct = pct
                    data.hasLiveStatus = true
                }
                if let resets = extractResetText(trimmed) {
                    data.weekAllModelsReset = resets
                }
            } else if trimmed.contains("Current week (Fable):") || trimmed.contains("Current week (") {
                if let pct = extractPercentage(trimmed) {
                    data.weekFablePct = pct
                    data.hasLiveStatus = true
                }
                if let open = trimmed.range(of: "Current week ("),
                   let close = trimmed[open.upperBound...].firstIndex(of: ")") {
                    data.weekModelLabel = String(trimmed[open.upperBound..<close])
                }
                if let resets = extractResetText(trimmed) {
                    data.weekFableReset = resets
                }
            }
        }
    }
    
    private func extractPercentage(_ str: String) -> Double? {
        let pattern = "(\\d+(?:\\.\\d+)?)%"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
           let range = Range(match.range(at: 1), in: str) {
            return Double(str[range])
        }
        return nil
    }

    private func extractResetText(_ str: String) -> String? {
        if let resetRange = str.range(of: "resets ") {
            return String(str[resetRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
