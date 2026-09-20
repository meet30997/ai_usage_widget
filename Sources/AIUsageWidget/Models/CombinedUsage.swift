import Foundation

struct CombinedDailyPoint: Identifiable {
    var id: String { date }
    let date: String
    let codexTokens: Int64
    let claudeTokens: Int64
    let antigravityTokens: Int64
    let codexSessions: Int
    let claudeSessions: Int
    let antigravitySessions: Int
    
    var totalTokens: Int64 {
        codexTokens + claudeTokens + antigravityTokens
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let d = formatter.date(from: date) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d"
            return outputFormatter.string(from: d)
        }
        return date
    }
}
