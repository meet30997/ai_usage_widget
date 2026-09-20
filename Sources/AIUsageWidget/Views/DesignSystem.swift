import SwiftUI
import AppKit

// MARK: - Modern macOS Design System Tokens

enum MacTheme {
    // Brand Gradients & Colors
    static let claudePrimary = Color(red: 0.95, green: 0.48, blue: 0.22)
    static let claudeSecondary = Color(red: 0.88, green: 0.32, blue: 0.18)
    static let claudeGradient = LinearGradient(
        colors: [claudePrimary, claudeSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let codexPrimary = Color(red: 0.12, green: 0.78, blue: 0.54)
    static let codexSecondary = Color(red: 0.05, green: 0.60, blue: 0.55)
    static let codexGradient = LinearGradient(
        colors: [codexPrimary, codexSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let antigravityPrimary = Color(red: 0.36, green: 0.48, blue: 0.98)
    static let antigravitySecondary = Color(red: 0.67, green: 0.34, blue: 0.95)
    static let antigravityGradient = LinearGradient(
        colors: [antigravityPrimary, antigravitySecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentBlue = Color(red: 0.22, green: 0.52, blue: 0.95)
    static let accentPurple = Color(red: 0.58, green: 0.36, blue: 0.94)
    
    // Status Colors
    static let success = Color(red: 0.20, green: 0.80, blue: 0.48)
    static let warning = Color(red: 0.98, green: 0.65, blue: 0.15)
    static let danger = Color(red: 0.95, green: 0.30, blue: 0.30)
    
    // Card Background & Glass
    static let cardBackground = Color(NSColor.controlBackgroundColor).opacity(0.45)
    static let glassBorder = Color.white.opacity(0.12)
    static let darkGlassBorder = Color.white.opacity(0.06)
}

// MARK: - Custom Glass Card Container

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content
    
    init(cornerRadius: CGFloat = 12, padding: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Glowing Brand Card

struct GlowingBrandCard<Content: View>: View {
    let brandGradient: LinearGradient
    let borderColor: Color
    let cornerRadius: CGFloat
    let content: Content
    
    init(brandGradient: LinearGradient, borderColor: Color, cornerRadius: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.brandGradient = brandGradient
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(brandGradient.opacity(0.06))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [borderColor.opacity(0.45), borderColor.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: borderColor.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Pulsing Live Indicator

struct PulsingLiveBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(MacTheme.success)
                .frame(width: 6, height: 6)
            
            Text("LIVE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(MacTheme.success)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(MacTheme.success.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(MacTheme.success.opacity(0.3), lineWidth: 0.75)
        )
    }
}

// MARK: - Modern Animated Progress Bar

struct ModernProgressBar: View {
    let valuePct: Double
    let accentGradient: LinearGradient
    let height: CGFloat
    
    init(valuePct: Double, accentGradient: LinearGradient, height: CGFloat = 6) {
        self.valuePct = valuePct
        self.accentGradient = accentGradient
        self.height = height
    }
    
    var clampedPct: Double {
        max(0, min(100, valuePct))
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                
                if clampedPct > 0 {
                    Capsule()
                        .fill(accentGradient)
                        .frame(width: geo.size.width * CGFloat(clampedPct / 100.0))
                        .shadow(color: Color.primary.opacity(0.15), radius: 2, x: 0, y: 1)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Glass Segmented Control Button

struct GlassSegmentButton: View {
    let title: String
    let icon: String
    var brandImage: NSImage? = nil
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3.5) {
                if let brandImg = brandImage {
                    Image(nsImage: brandImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 11, height: 11)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                }
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4.5)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .primary : .secondary)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(NSColor.controlAccentColor).opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color(NSColor.controlAccentColor).opacity(0.4), lineWidth: 0.75)
                            )
                            .shadow(color: Color(NSColor.controlAccentColor).opacity(0.15), radius: 4, x: 0, y: 2)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
