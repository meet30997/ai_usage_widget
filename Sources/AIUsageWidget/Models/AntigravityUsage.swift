import Foundation

enum AntigravityQuotaCadence: String {
    case fiveHour = "5-hour"
    case weekly = "Weekly"
}

struct AntigravityQuotaWindow: Identifiable, Equatable {
    var id: String { "\(family)-\(cadence.rawValue)" }
    let family: String
    let cadence: AntigravityQuotaCadence
    let remainingPercent: Double?
    let resetText: String

    var usedPercent: Double? {
        remainingPercent.map { max(0, min(100, 100 - $0)) }
    }
}

struct AntigravityDailyUsage: Identifiable {
    var id: String { date }
    let date: String
    let sessionCount: Int
    let tokensUsed: Int64
}

struct AntigravityModelUsage: Identifiable {
    var id: String { modelName }
    let modelName: String
    let sessionCount: Int
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64

    var totalTokens: Int64 { inputTokens + outputTokens }
}

struct AntigravityUsageData {
    var quotaWindows: [AntigravityQuotaWindow] = []
    var accountEmail = ""
    var accountPlan = ""
    var liveSource = ""
    var liveError = "Open Antigravity to read live quotas"
    var hasLiveStatus = false
    var quotaFetchedAt: Date?

    var dailyUsage: [AntigravityDailyUsage] = []
    var modelUsage: [AntigravityModelUsage] = []
    var totalSessions = 0
    var totalTokens: Int64 = 0
    var historyIsPartial = false
    var historyDiagnostic = ""

    var weeklyUsedPercent: Double? {
        quotaWindows
            .filter { $0.cadence == .weekly }
            .compactMap(\.usedPercent)
            .max()
    }

    var todayUsage: AntigravityDailyUsage? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return dailyUsage.first { $0.date == today }
    }

    var todayTokens: Int64 { todayUsage?.tokensUsed ?? 0 }
    var todaySessions: Int { todayUsage?.sessionCount ?? 0 }
}
