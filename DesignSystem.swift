// DesignSystem.swift
// Cadence — Dark Green Mint Theme
// Single source of truth for colors, gradients, and reusable components.

import SwiftUI

// MARK: - App Background
extension Color {
    /// Primary dark green canvas — used on all full-screen backgrounds
    static let cadenceBG        = Color(red: 0.04, green: 0.05, blue: 0.04)
    /// Slightly lifted card surface
    static let cadenceCard      = Color(red: 0.08, green: 0.09, blue: 0.08)
    /// Even lighter surface for nested elements
    static let cadenceCardLight = Color(red: 0.11, green: 0.12, blue: 0.11)
}

// MARK: - Semantic Color Tokens
extension Color {
    static let cadenceAccent  = Color.mint
    static let cadenceAccent2 = Color.cyan
    static let cadenceGood    = Color.mint
    static let cadenceWarn    = Color.orange
    static let cadenceBad     = Color.red
    static let cadenceNeutral = Color.yellow
}

// MARK: - ShapeStyle tokens (needed for foregroundStyle / fill / stroke)
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

// MARK: - Glass Card Modifier
struct CadenceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cadenceCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.mint.opacity(0.10), lineWidth: 1)
            )
    }
}

extension View {
    func cadenceCard() -> some View {
        modifier(CadenceCardModifier())
    }
}

// MARK: - Primary Button Style (Mint gradient)
struct CadencePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient.cadencePrimary
                    .opacity(configuration.isPressed ? 0.82 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
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
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Section Header
struct CadenceSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.mint.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
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
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
            StatBadge(text: badge, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cadenceCard()
    }
}

// MARK: - Stagger entrance animation
extension View {
    func staggerIn(_ appeared: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.82).delay(delay),
                value: appeared
            )
    }
}
