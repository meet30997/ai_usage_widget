import SwiftUI

struct CombinedModelItem: Identifiable {
    var id: String { "\(agent):\(modelName)" }
    let modelName: String
    let agent: String
    let tokens: Int64
    let gradient: LinearGradient
    let primaryColor: Color
}

struct ModelBreakdownView: View {
    @ObservedObject var manager: UsageManager
    
    var combinedModels: [CombinedModelItem] {
        var items: [CombinedModelItem] = []
        
        for m in manager.codexData.modelBreakdown {
            items.append(CombinedModelItem(
                modelName: m.modelName,
                agent: "Codex",
                tokens: m.totalTokens,
                gradient: MacTheme.codexGradient,
                primaryColor: MacTheme.codexPrimary
            ))
        }
        
        for m in manager.claudeData.modelUsage {
            items.append(CombinedModelItem(
                modelName: m.modelName,
                agent: "Claude",
                tokens: m.totalTokens,
                gradient: MacTheme.claudeGradient,
                primaryColor: MacTheme.claudePrimary
            ))
        }

        for m in manager.antigravityData.modelUsage {
            items.append(CombinedModelItem(
                modelName: m.modelName,
                agent: "Antigravity",
                tokens: m.totalTokens,
                gradient: MacTheme.antigravityGradient,
                primaryColor: MacTheme.antigravityPrimary
            ))
        }
        
        return items.sorted { $0.tokens > $1.tokens }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("ALL MODELS BREAKDOWN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    Text("\(combinedModels.count) Models Tracked")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 2)
                
                let grandTotal = max(combinedModels.map { $0.tokens }.reduce(0, +), 1)
                
                VStack(spacing: 8) {
                    ForEach(Array(combinedModels.enumerated()), id: \.element.id) { index, item in
                        let percentage = Double(item.tokens) / Double(grandTotal) * 100.0
                        
                        GlassCard(cornerRadius: 12, padding: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    // Rank Badge
                                    Text("#\(index + 1)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 24, alignment: .leading)
                                    
                                    Text(item.modelName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    // Agent Badge
                                    Text(item.agent)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(item.primaryColor.opacity(0.18))
                                        .foregroundColor(item.primaryColor)
                                        .clipShape(Capsule())
                                    
                                    // Total Tokens
                                    Text(UsageManager.formatTokens(item.tokens))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(item.primaryColor)
                                }
                                
                                ModernProgressBar(valuePct: percentage, accentGradient: item.gradient, height: 5)
                                
                                HStack {
                                    Text(String(format: "%.1f%% of total usage", percentage))
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}
