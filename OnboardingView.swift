// OnboardingView.swift
// Cadence — Dark Green Mint Theme

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    private let features: [FeatureRow] = [
        FeatureRow(icon: "waveform.path.ecg",          iconColor: Color.purple, title: "Speech Flow DNA",  description: "Every session generates a unique visual — the exact shape of your speech. No two are alike."),
        FeatureRow(icon: "speedometer",                iconColor: Color.mint,   title: "Pacing & Rhythm",  description: "Track every word. See where you rushed or dragged. Ideal pace: 120–160 WPM."),
        FeatureRow(icon: "exclamationmark.bubble.fill", iconColor: Color.orange, title: "Filler Words",     description: "Um, uh, like, so — caught in real time. Replace each with a 1-second pause."),
        FeatureRow(icon: "eye.fill",                   iconColor: Color.cyan,   title: "Eye Contact",      description: "Front camera alerts you the moment you look away. Build instant trust.")
    ]

    var body: some View {
        ZStack {
            Color.cadenceBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── HERO ──────────────────────────────────────────
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.mint.opacity(0.10))
                                .frame(width: 96, height: 96)
                            Circle()
                                .strokeBorder(Color.mint.opacity(0.20), lineWidth: 1.5)
                                .frame(width: 96, height: 96)
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(LinearGradient.cadencePrimary)
                                .symbolRenderingMode(.hierarchical)
                        }

                        Text("Meet Cadence")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        Text("Your speech has a shape. Cadence makes it visible.")
                            .font(.body)
                            .foregroundStyle(Color.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 44)

                    // ── FEATURES ──────────────────────────────────────
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.element.id) { i, feature in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(feature.iconColor.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: feature.icon)
                                        .font(.system(size: 19, weight: .regular))
                                        .foregroundStyle(feature.iconColor)
                                        .symbolRenderingMode(.hierarchical)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(feature.description)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.45))
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)

                            if i < features.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.07))
                                    .padding(.leading, 80)
                            }
                        }
                    }
                    .background(Color.cadenceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.mint.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // ── CTA ───────────────────────────────────────────
                    Button(action: onComplete) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                            Text("Get Started")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LinearGradient.cadencePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.mint.opacity(0.30), radius: 14, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 52)
                }
            }
        }
    }
}

// MARK: - Model
struct FeatureRow: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}
