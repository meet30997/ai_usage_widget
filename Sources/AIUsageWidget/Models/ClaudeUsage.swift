import Foundation

struct ClaudeDailyActivity: Identifiable, Codable {
    var id: String { date }
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
}

struct ClaudeDailyModelTokens: Identifiable {
    var id: String { date }
    let date: String
    let tokensByModel: [String: Int64]
    
    var totalTokens: Int64 {
        tokensByModel.values.reduce(0, +)
    }
}

struct ClaudeModelDetail: Identifiable {
    var id: String { modelName }
    let modelName: String
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadInputTokens: Int64
    let cacheCreationInputTokens: Int64
    
    // Excludes cacheReadInputTokens: cache reads repeat on nearly every
    // turn as prior context gets replayed, so counting them here would
    // dwarf every other figure in the app and break comparability with
    // the daily totals, which use the same in+out+cache_creation definition.
    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheCreationInputTokens
    }
}

/// Why `claude -p /usage` produced no live quota.
enum ClaudeLiveIssue: Equatable {
    /// The CLI reported it is logged out or its OAuth token expired.
    case signedOut
    /// The CLI could not be found at any known install location.
    case cliMissing
    /// The CLI ran but timed out or returned nothing parseable.
    case unavailable
}

struct ClaudeUsageData {
    var dailyActivity: [ClaudeDailyActivity] = []
    var dailyModelTokens: [ClaudeDailyModelTokens] = []
    var modelUsage: [ClaudeModelDetail] = []
    var totalSessions: Int = 0
    var totalMessages: Int = 0
    var lastComputedDate: String = ""
    
    // Official Live Subscription Quota Status (from claude -p /usage)
    var sessionUsedPct: Double = 0.0
    var sessionReset: String = ""
    var weekAllModelsPct: Double = 0.0
    var weekAllModelsReset: String = ""
    var weekFablePct: Double = 0.0
    var weekFableReset: String = ""
    var weekModelLabel: String = "Model-specific weekly limit"
    var hasLiveStatus: Bool = false
    var liveIssue: ClaudeLiveIssue?
    /// True when the quota fields are a previous snapshot carried over
    /// after a transient CLI failure, rather than a fresh reading.
    var isStaleSnapshot: Bool = false

    var todayActivity: ClaudeDailyActivity? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        return dailyActivity.first { $0.date == todayStr }
    }
    
    var todayTokens: Int64 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        return dailyModelTokens.first { $0.date == todayStr }?.totalTokens ?? 0
    }
    
    var todayMessages: Int {
        todayActivity?.messageCount ?? 0
    }
    
    var grandTotalTokens: Int64 {
        modelUsage.reduce(0) { $0 + $1.totalTokens }
    }
}
