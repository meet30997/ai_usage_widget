import SwiftUI

struct CodexDetailView: View {
    @ObservedObject var manager: UsageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Official Codex Status Card
                CodexStatusCard(codex: manager.codexData)
                
                // Lifetime Summary Cards Grid
                HStack(spacing: 8) {
                    DetailCard(
                        title: "Total Tokens",
                        value: UsageManager.formatTokens(manager.codexData.totalTokens),
                        icon: "bolt.ring.closed",
                        accentGradient: MacTheme.codexGradient,
                        primaryColor: MacTheme.codexPrimary
                    )
                    
                    DetailCard(
                        title: "Sessions",
                        value: "\(manager.codexData.totalSessions)",
                        icon: "square.stack.3d.up.fill",
                        accentGradient: LinearGradient(colors: [Color.teal, Color.cyan], startPoint: .leading, endPoint: .trailing),
                        primaryColor: .teal
                    )
                    
                    DetailCard(
                        title: "Resets",
                        value: "\(manager.codexData.availableResetsCount)",
                        icon: "arrow.triangle.2.circlepath",
                        accentGradient: LinearGradient(colors: [Color.mint, Color.green], startPoint: .leading, endPoint: .trailing),
                        primaryColor: .mint
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}
