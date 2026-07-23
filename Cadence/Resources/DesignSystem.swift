// DesignSystem.swift
// Cadence — iOS 26 Native Design System
// All colors reference UIKit/SwiftUI system semantics for automatic dark/light & tint support.

import SwiftUI

// MARK: - System Background Aliases
// These forward to UIKit semantic colors so they respect dark/light mode automatically.
extension Color {
    /// Primary app background — black in dark mode, white in light mode
    static let cadenceBG        = Color(.systemBackground)
    /// Lifted card surface — dark gray in dark mode, very light gray in light mode
    static let cadenceCard      = Color(.secondarySystemBackground)
    /// Nested element surface
    static let cadenceCardLight = Color(.tertiarySystemBackground)
}

// MARK: - Accent / Semantic Color Tokens
extension Color {
    static let cadenceAccent  = Color.mint
    static let cadenceAccent2 = Color.cyan
    static let cadenceGood    = Color.mint
    static let cadenceWarn    = Color.orange
    static let cadenceBad     = Color.red
    static let cadenceNeutral = Color.yellow
}

// MARK: - ShapeStyle convenience (for foregroundStyle / fill / stroke)
extension ShapeStyle where Self == Color {
    static var cadenceAccent:  Color { .mint   }
    static var cadenceAccent2: Color { .cyan   }
    static var cadenceGood:    Color { .mint   }
    static var cadenceWarn:    Color { .orange }
    static var cadenceBad:     Color { .red    }
    static var cadenceNeutral: Color { .yellow }
}

// MARK: - Gradient Helpers
extension LinearGradient {
    /// Mint → cyan — used for primary CTAs and hero accents
    static let cadencePrimary = LinearGradient(
        colors: [Color.mint, Color.cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Subtle mint tint for backgrounds
    static let cadenceSubtle = LinearGradient(
        colors: [Color.mint.opacity(0.12), Color.cyan.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - iOS 26 Native Glass Card Modifier
// Uses .regularMaterial so the system background shows through — creating the genuine
// frosted-glass effect Apple uses in Control Center, Spotlight, and widgets.
struct CadenceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
    }
}

extension View {
    func cadenceCard() -> some View {
        modifier(CadenceCardModifier())
    }
}

// MARK: - Primary Button Style (Mint gradient fill)
struct CadencePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient.cadencePrimary
                    .opacity(configuration.isPressed ? 0.78 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Section Header (iOS HIG style — grey ALL CAPS)
struct CadenceSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - Device Helpers
enum Device {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    static var scale: CGFloat {
        isPad ? 1.4 : 1.0
    }
}

// MARK: - Metric Tile
struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    let badge: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            StatBadge(text: badge, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cadenceCard()
    }
}

// MARK: - Stagger entrance animation
extension View {
    func staggerIn(_ appeared: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(delay),
                value: appeared
            )
    }
}
