// DesignSystem.swift
// Cadence — iOS 26 Native Design System
// All colors reference UIKit/SwiftUI system semantics for automatic dark/light & tint support.

import SwiftUI
import UIKit

// MARK: - Unified Layout Constants
// Single source of truth for all spacing, corner radii, and sizing across the app.
// Matches Apple Health / Fitness app proportions for iOS-native feel.
enum CadenceLayout {
    /// Standard corner radius for all Apple HIG grouped cards
    static let cardCornerRadius: CGFloat = 12
    /// Standard corner radius for all buttons
    static let buttonCornerRadius: CGFloat = 14
    /// Standard primary button height (matches Apple Fitness CTA buttons)
    static let buttonHeight: CGFloat = 56
    /// Minimum height for metric tiles so Words/Min, Fillers, Rhythm are always equal
    static let metricTileMinHeight: CGFloat = 120
}

// MARK: - System Background Aliases
// These forward to UIKit semantic colors so they respect dark/light mode automatically.
extension Color {
    /// Primary app background (Forced dark mode preferred for fitness aesthetic)
    static let cadenceBG        = Color(.systemBackground)
    /// Lifted card surface (Exact Apple HIG grouped list card color)
    static let cadenceCard      = Color(.secondarySystemGroupedBackground)
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

// MARK: - Native Apple Navigation & Toolbar Buttons (Fitness App Style)
struct FitnessNavButton: View {
    let icon: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 17
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemFill)) // Subtle translucent grey on black
                
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Native Apple Floating Pill Bar (For grouped actions)
struct FitnessPillBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemFill), in: Capsule())
    }
}

// MARK: - iOS 26 Native Card Modifier
struct CadenceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CadenceLayout.cardCornerRadius, style: .continuous))
    }
}

extension View {
    func cadenceCard() -> some View {
        modifier(CadenceCardModifier())
    }
    
    // For elements like status pills (e.g. Timer, Eye contact hint)
    func cadenceStatusPill() -> some View {
        self.background(Color(.secondarySystemFill), in: Capsule())
    }
}

// MARK: - Primary Button Style (Native vibrant fill)
struct CadencePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: CadenceLayout.buttonHeight)
            .background(Color.cadenceAccent) // Solid native primary color
            .clipShape(RoundedRectangle(cornerRadius: CadenceLayout.buttonCornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style (Native subtle tint style)
struct CadenceSecondaryButtonStyle: ButtonStyle {
    var tintColor: Color = .mint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tintColor)
            .frame(maxWidth: .infinity)
            .frame(height: CadenceLayout.buttonHeight)
            .background(tintColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: CadenceLayout.buttonCornerRadius, style: .continuous))
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

// MARK: - Section Header (Apple Fitness style bold headers)
struct CadenceSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - Grouped List Header (Apple Settings style uppercase)
struct CadenceListHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }
}

// MARK: - Native iOS List Row (Fitness / Settings style)
struct CadenceListRow<TrailingContent: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let trailingContent: TrailingContent
    
    var body: some View {
        HStack(spacing: 16) {
            // HIG standard colored circle icon
            ZStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            trailingContent
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
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
// Fixed: All tiles now share a uniform minimum height so Words/Min, Fillers,
// and Rhythm are always the same size regardless of label text wrapping.
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
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            StatBadge(text: badge, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: CadenceLayout.metricTileMinHeight)
        .padding(14)
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
