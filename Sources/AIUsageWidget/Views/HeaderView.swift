import SwiftUI
import AppKit

enum AppTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case claude = "Claude"
    case codex = "Codex"
    case antigravity = "Antigravity"
    case models = "Models"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .claude: return "brain.head.profile"
        case .codex: return "terminal.fill"
        case .antigravity: return "sparkles"
        case .models: return "cpu.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var brandImage: NSImage? {
        switch self {
        case .claude: return BrandAssets.shared.claudeIcon14
        case .codex: return BrandAssets.shared.codexIcon14
        case .antigravity: return BrandAssets.shared.antigravityIcon14
        default: return nil
        }
    }
}

struct HeaderView: View {
    @ObservedObject var manager: UsageManager
    @Binding var selectedTab: AppTab
    
    @State private var rotationAngle: Double = 0
    @State private var isRefreshHovered = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Top Bar: Title, Live Status Badge, Refresh Button
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.cyan.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("TokenBar")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("macOS Usage Monitor")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    PulsingLiveBadge()
                }
                
                Spacer(minLength: 4)
                
                // Refresh Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        manager.refreshData()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(Angle(degrees: rotationAngle))
                        
                        Text(manager.isRefreshing ? "Updating..." : "Refresh")
                            .font(.system(size: 9.5, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .foregroundColor(isRefreshHovered ? .primary : .secondary)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(isRefreshHovered ? 0.1 : 0.05))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(manager.isRefreshing)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRefreshHovered = hovering
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            // Tab Navigation Pill Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(AppTab.allCases) { tab in
                        GlassSegmentButton(
                            title: tab.rawValue,
                            icon: tab.iconName,
                            brandImage: tab.brandImage,
                            isSelected: selectedTab == tab
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        }
                        .frame(minWidth: tab == .antigravity ? 86 : 62)
                    }
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .onChange(of: manager.isRefreshing) { refreshing in
            if refreshing {
                startSpinning()
            }
        }
    }
    
    private func startSpinning() {
        withAnimation(.linear(duration: 0.8)) {
            rotationAngle += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if manager.isRefreshing {
                startSpinning()
            }
        }
    }
}
