import SwiftUI

struct TodayCardView: View {
    @ObservedObject var manager: UsageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LIVE AGENT SUBSCRIPTION STATUS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                Spacer()
            }
            .padding(.horizontal, 2)

            // 1. Claude Official Live Status Card
            ClaudeStatusCard(claude: manager.claudeData)
            
            // 2. Codex Official Live Status Card
            CodexStatusCard(codex: manager.codexData)
        }
    }
}

// MARK: - Claude Status Card

struct ClaudeStatusCard: View {
    let claude: ClaudeUsageData
    
    var body: some View {
        let sessionPct = claude.sessionUsedPct
        let weekAllPct = claude.weekAllModelsPct
        let weekFablePct = claude.weekFablePct
        
        GlowingBrandCard(
            brandGradient: MacTheme.claudeGradient,
            borderColor: MacTheme.claudePrimary,
            cornerRadius: 14
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Card Header
                HStack {
                    HStack(spacing: 7) {
                        if let img = BrandAssets.shared.claudeIcon14 {
                            Image(nsImage: img)
                        } else {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MacTheme.claudeGradient)
                        }
                        
                        Text("Claude Agent")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Claude Code")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(MacTheme.claudePrimary.opacity(0.18))
                        .foregroundColor(MacTheme.claudePrimary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(MacTheme.claudePrimary.opacity(0.3), lineWidth: 0.5)
                        )
                }
                
                // Current Session
                if claude.hasLiveStatus {
                    ProgressBarRow(
                        label: "Current session",
                        valueText: String(format: "%.0f%% used", sessionPct),
                        progressPct: sessionPct,
                        resetText: claude.sessionReset.isEmpty ? nil : "resets \(claude.sessionReset)",
                        accentGradient: progressGradient(usedPct: sessionPct)
                    )
                    
                    Divider().opacity(0.2)
                    
                    // Current Week (All Models)
                    ProgressBarRow(
                        label: "Current week (all models)",
                        valueText: String(format: "%.0f%% used", weekAllPct),
                        progressPct: weekAllPct,
                        resetText: claude.weekAllModelsReset.isEmpty ? nil : "resets \(claude.weekAllModelsReset)",
                        accentGradient: progressGradient(usedPct: weekAllPct)
                    )
                    
                    Divider().opacity(0.2)
                    
                    // Current Week (Fable)
                    ProgressBarRow(
                        label: "Current week (\(claude.weekModelLabel))",
                        valueText: String(format: "%.0f%% used", weekFablePct),
                        progressPct: weekFablePct,
                        resetText: claude.weekFableReset.isEmpty ? nil : "resets \(claude.weekFableReset)",
                        accentGradient: progressGradient(usedPct: weekFablePct)
                    )
                } else {
                    HStack {
                        Text("Session limits")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("Local session expired")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Codex Status Card

struct CodexStatusCard: View {
    let codex: CodexUsageData
    
    var body: some View {
        GlowingBrandCard(
            brandGradient: MacTheme.codexGradient,
            borderColor: MacTheme.codexPrimary,
            cornerRadius: 14
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Card Header
                HStack {
                    HStack(spacing: 7) {
                        if let img = BrandAssets.shared.codexIcon14 {
                            Image(nsImage: img)
                        } else {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MacTheme.codexGradient)
                        }
                        
                        Text("OpenAI Codex")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(codex.accountPlan.isEmpty ? "Local" : codex.accountPlan)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(MacTheme.codexPrimary.opacity(0.18))
                        .foregroundColor(MacTheme.codexPrimary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(MacTheme.codexPrimary.opacity(0.3), lineWidth: 0.5)
                        )
                }
                
                // Account Details Subheader
                if !codex.activeModel.isEmpty || !codex.accountEmail.isEmpty {
                    HStack(spacing: 6) {
                        if !codex.activeModel.isEmpty {
                            Label(codex.activeModel, systemImage: "sparkles")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        if !codex.activeModel.isEmpty && !codex.accountEmail.isEmpty {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        if !codex.accountEmail.isEmpty {
                            Text(codex.accountEmail)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider().opacity(0.2)

                if let usedPct = codex.fiveHourLimitUsedPct {
                    ProgressBarRow(
                        label: "5-hour limit",
                        valueText: String(format: "%.0f%% used", usedPct),
                        progressPct: usedPct,
                        resetText: codex.fiveHourLimitResetText,
                        accentGradient: progressGradient(usedPct: usedPct)
                    )
                } else {
                    HStack {
                        Text("5-hour limit")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("No snapshot recorded")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Divider().opacity(0.2)

                if let usedPct = codex.weeklyLimitUsedPct {
                    ProgressBarRow(
                        label: "Weekly limit",
                        valueText: String(format: "%.0f%% used", usedPct),
                        progressPct: usedPct,
                        resetText: codex.weeklyLimitResetText,
                        accentGradient: progressGradient(usedPct: usedPct)
                    )
                } else {
                    HStack {
                        Text("Weekly limit")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("No snapshot recorded")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Divider().opacity(0.2)

                // Resets Section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Limit Resets Available", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MacTheme.codexPrimary)
                        
                        Spacer()
                        
                        Text(
                            codex.availableResetCreditsCount != nil
                                ? (codex.hasResetsAvailable ? "\(codex.availableResetsCount) Available" : "None Available")
                                : "Unavailable"
                        )
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(codex.hasResetsAvailable ? MacTheme.codexPrimary : .secondary)
                    }

                    ForEach(codex.resets) { item in
                        HStack(spacing: 6) {
                            Text("\(item.index).")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(MacTheme.codexPrimary)
                            Text(item.name)
                                .font(.system(size: 10, weight: .medium))
                            Spacer()
                            Text("Expires \(item.expiryText)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                    
                    let missingResetDetails = max(0, codex.availableResetsCount - codex.resets.count)
                    if missingResetDetails > 0 {
                        ForEach(0..<missingResetDetails, id: \.self) { offset in
                            let index = codex.resets.count + offset + 1
                            HStack(spacing: 6) {
                                Text("\(index).")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(MacTheme.codexPrimary)
                                Text("Reset credit")
                                    .font(.system(size: 10, weight: .medium))
                                Spacer()
                                Text("Expiry not provided")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Progress Bar Row

struct ProgressBarRow: View {
    let label: String
    let valueText: String
    let progressPct: Double
    let resetText: String?
    let accentGradient: LinearGradient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 4)
                
                Text(valueText)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(progressTextColor(usedPct: progressPct))
                    .lineLimit(1)
            }
            
            ModernProgressBar(valuePct: progressPct, accentGradient: accentGradient, height: 6)
            
            if let reset = resetText, !reset.isEmpty {
                HStack {
                    Label(reset, systemImage: "clock")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Helper Gradients

func progressGradient(usedPct: Double) -> LinearGradient {
    if usedPct >= 85.0 {
        return LinearGradient(colors: [MacTheme.danger, Color.red], startPoint: .leading, endPoint: .trailing)
    } else if usedPct >= 60.0 {
        return LinearGradient(colors: [MacTheme.warning, Color.orange], startPoint: .leading, endPoint: .trailing)
    } else {
        return LinearGradient(colors: [MacTheme.success, MacTheme.codexPrimary], startPoint: .leading, endPoint: .trailing)
    }
}

func progressTextColor(usedPct: Double) -> Color {
    if usedPct >= 85.0 {
        return MacTheme.danger
    } else if usedPct >= 60.0 {
        return MacTheme.warning
    } else {
        return MacTheme.success
    }
}
