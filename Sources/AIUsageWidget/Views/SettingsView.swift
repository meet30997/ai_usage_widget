import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: UsageManager
    @Binding var selectedTab: AppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Title
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MacTheme.accentBlue)
                    
                    Text("Settings & Configuration")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 2)

                // Menu Bar Display Options Group
                GlassCard(cornerRadius: 12, padding: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MENU BAR DISPLAY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .tracking(0.5)

                        Toggle(isOn: $manager.showQuotaInMenuBar) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show live quota percentages in Menu Bar")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Shows weekly percent used for Claude, Codex, and Antigravity")
                                    .font(.system(size: 9.5, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }

                // Refresh Interval Card Group
                GlassCard(cornerRadius: 12, padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REFRESH INTERVAL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .tracking(0.5)

                        HStack {
                            Text("Auto-refresh background interval")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()

                            Picker("", selection: $manager.refreshIntervalSeconds) {
                                Text("1 minute").tag(60.0)
                                Text("5 minutes").tag(300.0)
                                Text("10 minutes").tag(600.0)
                                Text("30 minutes").tag(1800.0)
                                Text("Manual Only").tag(0.0)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 130)
                        }
                    }
                }

                // Local Data Sources Status Group
                GlassCard(cornerRadius: 12, padding: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LOCAL DATA SOURCES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .tracking(0.5)

                        SourceRow(
                            name: "Codex SQLite Database",
                            path: "~/.codex/state_5.sqlite",
                            exists: sourceExists("~/.codex/state_5.sqlite")
                        )

                        SourceRow(
                            name: "Claude Stats Cache",
                            path: "~/.claude/stats-cache.json",
                            exists: sourceExists("~/.claude/stats-cache.json")
                        )

                        SourceRow(
                            name: "Antigravity Conversations",
                            path: "~/.gemini/antigravity/conversations",
                            exists: sourceExists("~/.gemini/antigravity/conversations")
                        )

                        SourceRow(
                            name: "Antigravity CLI Conversations",
                            path: "~/.gemini/antigravity-cli/conversations",
                            exists: sourceExists("~/.gemini/antigravity-cli/conversations")
                        )
                    }
                }

                // Application Info & Actions Card
                GlassCard(cornerRadius: 12, padding: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("APPLICATION")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .tracking(0.5)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI Usage Tracker for macOS")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Version \(appVersion) (Native SwiftUI & SQLite)")
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                NSApplication.shared.terminate(nil)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "power")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Quit App")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(MacTheme.danger)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(MacTheme.danger.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(MacTheme.danger.opacity(0.3), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func sourceExists(_ path: String) -> Bool {
        FileManager.default.fileExists(
            atPath: NSString(string: path).expandingTildeInPath
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }
}
