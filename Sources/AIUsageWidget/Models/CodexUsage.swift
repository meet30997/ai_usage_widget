import Foundation

struct CodexDailyUsage: Identifiable {
    var id: String { date }
    let date: String
    let sessionCount: Int
    let tokensUsed: Int64
}

struct CodexModelUsage: Identifiable {
    var id: String { modelName }
    let modelName: String
    let sessionCount: Int
    let totalTokens: Int64
}

struct CodexResetItem: Identifiable, Codable, Equatable {
    var id: String { "\(index)-\(expiryText)" }
    let index: Int
    let name: String
    let expiryText: String
}

struct CodexUsageData {
    var dailyUsage: [CodexDailyUsage] = []
    var modelBreakdown: [CodexModelUsage] = []
    var totalSessions: Int = 0
    var totalTokens: Int64 = 0
    
    // Official /status Attributes
    var accountEmail: String = ""
    var accountPlan: String = ""
    var activeModel: String = ""
    
    // Rolling local activity window (not a subscription quota).
    var tokensIn1WeekWindow: Int64 = 0
    var sessionsIn1WeekWindow: Int = 0

    // Latest subscription rate-limit windows reported by Codex.
    var fiveHourLimitUsedPct: Double?
    var fiveHourLimitResetText: String = ""
    var weeklyLimitUsedPct: Double?
    var weeklyLimitResetText: String = ""
    var resets: [CodexResetItem] = []
    var availableResetCreditsCount: Int?

    var availableResetsCount: Int { availableResetCreditsCount ?? resets.count }
    var hasResetsAvailable: Bool { availableResetsCount > 0 }
    
    var todayUsage: CodexDailyUsage? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        return dailyUsage.first { $0.date == todayStr }
    }
    
    var todayTokens: Int64 {
        todayUsage?.tokensUsed ?? 0
    }
    
    var todaySessions: Int {
        todayUsage?.sessionCount ?? 0
    }
}
