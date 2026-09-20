import SwiftUI

struct DailyChartView: View {
    @ObservedObject var manager: UsageManager
    @State private var hoveredPoint: CombinedDailyPoint? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DAILY TOKEN TRENDS (14 DAYS)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                Spacer()
                
                HStack(spacing: 10) {
                    LegendItem(gradient: MacTheme.codexGradient, label: "Codex")
                    LegendItem(gradient: MacTheme.claudeGradient, label: "Claude")
                    LegendItem(gradient: MacTheme.antigravityGradient, label: "Antigravity")
                }
            }
            .padding(.horizontal, 2)
            
            if manager.combinedDailyPoints.isEmpty {
                GlassCard {
                    Text("No activity recorded yet.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                }
            } else {
                let maxTokens = max(manager.combinedDailyPoints.map { $0.totalTokens }.max() ?? 1, 1)
                
                GlassCard(cornerRadius: 14, padding: 12) {
                    VStack(spacing: 10) {
                        // Hover Details Box Header
                        ZStack {
                            if let hovered = hoveredPoint {
                                HStack(spacing: 8) {
                                    Text(hovered.formattedDate)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(MacTheme.codexPrimary)
                                            .frame(width: 6, height: 6)
                                        Text("Codex: \(UsageManager.formatTokens(hovered.codexTokens))")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(MacTheme.codexPrimary)
                                    }

                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(MacTheme.antigravityPrimary)
                                            .frame(width: 6, height: 6)
                                        Text("AG: \(UsageManager.formatTokens(hovered.antigravityTokens))")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(MacTheme.antigravityPrimary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(MacTheme.claudePrimary)
                                            .frame(width: 6, height: 6)
                                        Text("Claude: \(UsageManager.formatTokens(hovered.claudeTokens))")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(MacTheme.claudePrimary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                HStack {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 10))
                                    Text("Hover over bars to inspect daily token volume")
                                        .font(.system(size: 10, weight: .medium))
                                    Spacer()
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                            }
                        }
                        .frame(height: 26)
                        
                        // Stacked Bar Chart
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(manager.combinedDailyPoints) { point in
                                let isHovered = hoveredPoint?.id == point.id
                                
                                VStack(spacing: 5) {
                                    GeometryReader { geo in
                                        let availableHeight = geo.size.height
                                        let totalHeight = CGFloat(point.totalTokens) / CGFloat(maxTokens) * availableHeight
                                        let codexHeight = point.totalTokens > 0
                                            ? totalHeight * CGFloat(point.codexTokens) / CGFloat(point.totalTokens)
                                            : 0
                                        let claudeHeight = point.totalTokens > 0
                                            ? totalHeight * CGFloat(point.claudeTokens) / CGFloat(point.totalTokens)
                                            : 0
                                        let antigravityHeight = point.totalTokens > 0
                                            ? totalHeight * CGFloat(point.antigravityTokens) / CGFloat(point.totalTokens)
                                            : 0
                                        
                                        VStack(spacing: 1.5) {
                                            Spacer(minLength: 0)
                                            
                                            // Claude Portion (Orange Gradient)
                                            if point.claudeTokens > 0 {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .fill(MacTheme.claudeGradient)
                                                    .frame(height: max(claudeHeight, 4))
                                                    .shadow(color: MacTheme.claudePrimary.opacity(isHovered ? 0.4 : 0.0), radius: 4)
                                            }

                                            if point.antigravityTokens > 0 {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .fill(MacTheme.antigravityGradient)
                                                    .frame(height: max(antigravityHeight, 4))
                                                    .shadow(color: MacTheme.antigravityPrimary.opacity(isHovered ? 0.4 : 0), radius: 4)
                                            }
                                            
                                            // Codex Portion (Green Gradient)
                                            if point.codexTokens > 0 {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .fill(MacTheme.codexGradient)
                                                    .frame(height: max(codexHeight, 4))
                                                    .shadow(color: MacTheme.codexPrimary.opacity(isHovered ? 0.4 : 0.0), radius: 4)
                                            }
                                        }
                                    }
                                    .frame(height: 95)
                                    
                                    Text(point.formattedDate)
                                        .font(.system(size: 8.5, weight: isHovered ? .bold : .medium, design: .monospaced))
                                        .foregroundColor(isHovered ? .primary : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                                )
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if hovering {
                                            hoveredPoint = point
                                        } else if hoveredPoint?.id == point.id {
                                            hoveredPoint = nil
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                }
            }
        }
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let gradient: LinearGradient
    let label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(gradient)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}
