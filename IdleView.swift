// IdleView.swift
// Cadence — Home Screen

// IdleView.swift
// Cadence — Practice Home Tab
// Apple HIG: clear hierarchy, generous spacing, minimal decoration

import SwiftUI

private let SW = UIScreen.main.bounds.width
private let CW = SW - 48

struct IdleView: View {
    @EnvironmentObject var session: SessionManager

    @State private var pulse = false
    @State private var orbRotation: Double = 0
    @State private var contentVisible = false
    @State private var dnaHeights: [CGFloat] = [
        14, 26, 20, 32, 14, 28, 22, 18, 30, 14, 24, 32,
        18, 26, 14, 28, 20, 16, 32, 24, 18, 26, 30, 14
    ]
    private let dnaColors: [Color] = [
        .mint, .orange, .mint, .mint, .yellow, .mint,
        .red,  .mint,  .mint, .orange,.mint,  .mint,
        .mint, .yellow,.mint, .orange,.mint,  .mint,
        .mint, .mint,  .yellow,.mint, .orange,.mint
    ]
    private var barW: CGFloat {
        let n = CGFloat(dnaColors.count)
        return (CW - (n - 1) * 4 - 24) / n
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.06), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient glow behind orb
            Circle()
                .fill(Color.mint.opacity(0.07))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(y: -220)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── ORB ───────────────────────────────────
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.mint.opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                                .frame(width: CGFloat(148 + i * 46))
                                .scaleEffect(pulse ? 1.0 : 0.9)
                                .animation(
                                    .easeInOut(duration: 2.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.4),
                                    value: pulse
                                )
                        }
                        Circle()
                            .trim(from: 0, to: 0.22)
                            .stroke(
                                AngularGradient(colors: [Color.mint.opacity(0.8), .clear], center: .center),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .frame(width: 140)
                            .rotationEffect(.degrees(orbRotation))
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.mint.opacity(0.18), Color.mint.opacity(0.03)],
                                center: .center, startRadius: 0, endRadius: 62
                            ))
                            .frame(width: 124)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 38, weight: .thin))
                            .foregroundStyle(
                                LinearGradient(colors: [.white, .mint], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .padding(.top, 52)

                    // ── WORDMARK ──────────────────────────────
                    VStack(spacing: 6) {
                        Text("Cadence")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(white: 0.78)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        Text("See the shape of your speech")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(white: 0.40))
                    }
                    .padding(.top, 28)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.15), value: contentVisible)

                    // ── SPEECH FLOW DNA ───────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.mint)
                            Text("SPEECH FLOW DNA")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(white: 0.38))
                                .tracking(2.0)
                        }

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.mint.opacity(0.10), lineWidth: 1)
                                )
                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach(0..<dnaColors.count, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(dnaColors[i])
                                        .frame(width: barW, height: dnaHeights[i])
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                        .frame(height: 72)

                        HStack(spacing: 16) {
                            DNALegend(color: .mint,   label: "Confident")
                            DNALegend(color: .orange, label: "Filler")
                            DNALegend(color: .yellow, label: "Pause")
                            DNALegend(color: .red,    label: "Lost Flow")
                        }
                    }
                    .padding(.top, 28)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: contentVisible)

                    // ── FEATURE CHIPS ─────────────────────────
                    // Apple HIG: use chips/pills for feature discovery,
                    // not list rows. Horizontal scroll keeps it compact.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FeatureChip(
                                icon: "doc.text.magnifyingglass",
                                title: "Read & Analyze",
                                subtitle: "Word-by-word live",
                                color: .cyan,
                                isNew: true
                            )
                            FeatureChip(
                                icon: "camera.fill",
                                title: "Live Mirror",
                                subtitle: "Eye contact check",
                                color: .mint,
                                isNew: false
                            )
                            FeatureChip(
                                icon: "waveform",
                                title: "Word Watch",
                                subtitle: "Catch repetitions",
                                color: .orange,
                                isNew: false
                            )
                            FeatureChip(
                                icon: "bolt.fill",
                                title: "Coach Tips",
                                subtitle: "Real-time feedback",
                                color: .yellow,
                                isNew: false
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.45), value: contentVisible)

                    // ── BEGIN PRACTICE ────────────────────────
                    Button {
                        session.startSession()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Begin Practice")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.mint, Color(red: 0.18, green: 0.84, blue: 0.66)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.mint.opacity(0.35), radius: 20, y: 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.55), value: contentVisible)

                    // Bottom padding — tab bar is 82pt tall
                    Spacer().frame(height: 28)
                }
            }
        }
        .onAppear {
            pulse = true
            contentVisible = true
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
            for i in 0..<dnaHeights.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(
                        .easeInOut(duration: 1.2 + Double(i) * 0.11)
                        .repeatForever(autoreverses: true)
                    ) {
                        dnaHeights[i] = CGFloat.random(in: 10...(i % 3 == 0 ? 38 : 30))
                    }
                }
            }
        }
    }
}

// MARK: - DNA Legend
struct DNALegend: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(white: 0.38))
        }
    }
}

// MARK: - Feature Chip
// Apple HIG: compact, tappable, horizontally scrollable chips
// instead of full-width list rows
struct FeatureChip: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(color)
                }
                Spacer()
                if isNew {
                    Text("NEW")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.18))
                        .cornerRadius(6)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.42))
            }
        }
        .padding(14)
        .frame(width: 140)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}
