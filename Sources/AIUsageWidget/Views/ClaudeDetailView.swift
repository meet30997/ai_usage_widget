import SwiftUI

struct ClaudeDetailView: View {
    @ObservedObject var manager: UsageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Official Claude Subscription Status Card
                ClaudeStatusCard(claude: manager.claudeData)
                
                // Header Stats Grid
                HStack(spacing: 10) {
                    DetailCard(
                        title: "Total Messages",
                        value: "\(manager.claudeData.totalMessages)",
                        icon: "bubble.left.and.bubble.right.fill",
                        accentGradient: MacTheme.claudeGradient,
                        primaryColor: MacTheme.claudePrimary
                    )
                    
                    DetailCard(
                        title: "Total Sessions",
                        value: "\(manager.claudeData.totalSessions)",
                        icon: "square.stack.3d.up.fill",
                        accentGradient: LinearGradient(colors: [Color.purple, Color.pink], startPoint: .leading, endPoint: .trailing),
                        primaryColor: .pink
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}
