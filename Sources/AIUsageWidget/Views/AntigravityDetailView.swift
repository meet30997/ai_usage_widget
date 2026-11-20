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
                    Text(antigravity.hasLiveStatus ? antigravity.liveSource : (antigravity.quotaWindows.isEmpty ? "Unavailable" : "Last reading"))
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
                    ForEach(Array(antigravity.quotaWindows.enumerated()), id: \.offset) { index, window in
                        if index > 0 { Divider().opacity(0.2) }
                        if let remaining = window.remainingPercent {
                            let used = 100 - remaining
                            ProgressBarRow(
                                label: "\(window.family) \(window.cadence.rawValue.lowercased())",
                                valueText: String(format: "%.2f%% remaining", remaining),
                                progressPct: remaining,
                                resetText: window.resetText.isEmpty ? nil : window.resetText,
                                accentGradient: progressGradient(usedPct: used),
                                valueColor: progressTextColor(usedPct: used)
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
                    Label("Last quota reading. \(antigravity.liveError)", systemImage: "clock.badge.exclamationmark")
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
                        title: "Total Tokens",
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}
