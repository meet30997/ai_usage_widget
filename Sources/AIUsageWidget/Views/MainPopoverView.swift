import SwiftUI

struct MainPopoverView: View {
    @StateObject private var manager = UsageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(manager: manager, selectedTab: $manager.selectedTab)
            
            Divider()
                .opacity(0.3)
            
            // Tab View Body
            Group {
                switch manager.selectedTab {
                case .overview:
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 14) {
                            TodayCardView(manager: manager)
                            DailyChartView(manager: manager)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                case .claude:
                    ClaudeDetailView(manager: manager)
                case .codex:
                    CodexDetailView(manager: manager)
                case .antigravity:
                    AntigravityDetailView(manager: manager)
                case .models:
                    ModelBreakdownView(manager: manager)
                case .settings:
                    SettingsView(manager: manager, selectedTab: $manager.selectedTab)
                }
            }
        }
        .frame(width: 410, height: 520)
    }
}
