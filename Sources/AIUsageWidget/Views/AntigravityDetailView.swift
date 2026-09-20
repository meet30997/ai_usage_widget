import SwiftUI

struct AntigravityStatusCard: View {
    let antigravity: AntigravityUsageData

    var body: some View {
        GlowingBrandCard(
            brandGradient: MacTheme.antigravityGradient,
            borderColor: MacTheme.antigravityPrimary,
            cornerRadius: 14
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 7) {
                        if let image = BrandAssets.shared.antigravityIcon14 {
                            Image(nsImage: image)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MacTheme.antigravityGradient)
                        }
                        Text("Google Antigravity")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Text(antigravity.hasLiveStatus ? antigravity.liveSource : "Offline")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(MacTheme.antigravityPrimary.opacity(0.18))
                        .foregroundColor(antigravity.hasLiveStatus ? MacTheme.antigravityPrimary : .secondary)
                        .clipShape(Capsule())
                }

                if !antigravity.accountEmail.isEmpty || !antigravity.accountPlan.isEmpty {
                    HStack(spacing: 5) {
                        if !antigravity.accountPlan.isEmpty {
                            Text(antigravity.accountPlan)
                        }
                        if !antigravity.accountPlan.isEmpty && !antigravity.accountEmail.isEmpty { Text("•") }
                        if !antigravity.accountEmail.isEmpty { Text(antigravity.accountEmail) }
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
                }

                if antigravity.quotaWindows.isEmpty {
                    HStack {
                        Text("Live quotas")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(antigravity.liveError)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    ForEach(Array(antigravity.quotaWindows.enumerated()), id: \.element.id) { index, window in
                        if index > 0 { Divider().opacity(0.2) }
                        if let remaining = window.remainingPercent {
                            let used = 100 - remaining
                            ProgressBarRow(
                                label: "\(window.family) \(window.cadence.rawValue.lowercased())",
                                valueText: String(format: "%.2f%% remaining", remaining),
                                progressPct: remaining,
                                resetText: window.resetText.isEmpty ? nil : window.resetText,
                                accentGradient: progressGradient(usedPct: used)
                            )
                        } else {
                            HStack {
                                Text("\(window.family) \(window.cadence.rawValue.lowercased())")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Spacer()
                                Text("Unavailable")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !antigravity.hasLiveStatus && !antigravity.quotaWindows.isEmpty {
                    Label(antigravity.liveError, systemImage: "clock.badge.exclamationmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(MacTheme.warning)
                }
            }
        }
    }
}

struct AntigravityDetailView: View {
    @ObservedObject var manager: UsageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AntigravityStatusCard(antigravity: manager.antigravityData)

                HStack(spacing: 8) {
                    DetailCard(
                        title: manager.antigravityData.historyIsPartial ? "Tracked Tokens*" : "Total Tokens",
                        value: UsageManager.formatTokens(manager.antigravityData.totalTokens),
                        icon: "bolt.ring.closed",
                        accentGradient: MacTheme.antigravityGradient,
                        primaryColor: MacTheme.antigravityPrimary
                    )
                    DetailCard(
                        title: "Sessions",
                        value: "\(manager.antigravityData.totalSessions)",
                        icon: "square.stack.3d.up.fill",
                        accentGradient: MacTheme.antigravityGradient,
                        primaryColor: MacTheme.antigravityPrimary
                    )
                }

                if !manager.antigravityData.historyDiagnostic.isEmpty {
                    Label(manager.antigravityData.historyDiagnostic, systemImage: manager.antigravityData.historyIsPartial ? "exclamationmark.triangle" : "info.circle")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(manager.antigravityData.historyIsPartial ? MacTheme.warning : .secondary)
                }

                sectionTitle("ANTIGRAVITY MODELS")
                VStack(spacing: 6) {
                    ForEach(manager.antigravityData.modelUsage) { model in
                        GlassCard(cornerRadius: 10, padding: 8) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(model.modelName)
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(UsageManager.formatTokens(model.totalTokens))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(MacTheme.antigravityPrimary)
                                }
                                HStack(spacing: 6) {
                                    LabelBadge(label: "In", val: UsageManager.formatTokens(model.inputTokens))
                                    LabelBadge(label: "Out", val: UsageManager.formatTokens(model.outputTokens))
                                    LabelBadge(label: "Cache", val: UsageManager.formatTokens(model.cacheReadTokens))
                                }
                            }
                        }
                    }
                }

                sectionTitle("RECENT DAILY ACTIVITY")
                VStack(spacing: 6) {
                    ForEach(manager.antigravityData.dailyUsage.prefix(10)) { item in
                        GlassCard(cornerRadius: 10, padding: 8) {
                            HStack {
                                Text(item.date)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                Spacer()
                                Text("\(item.sessionCount) session\(item.sessionCount == 1 ? "" : "s")")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(UsageManager.formatTokens(item.tokensUsed))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(MacTheme.antigravityPrimary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }
}
