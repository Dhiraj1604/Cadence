// IdleView.swift
// Cadence — iOS 26 Liquid Glass

import SwiftUI

struct IdleView: View {
    @EnvironmentObject var session: SessionManager
    @State private var orbRotation: Double = 0
    @State private var pulse = false
    @State private var dnaHeights: [CGFloat] = Array(repeating: 18, count: 18)

    private let dnaColors: [Color] = [
        .mint, .orange, .mint, .mint, .yellow, .mint,
        .red, .mint, .mint, .orange, .mint, .mint,
        .mint, .yellow, .mint, .orange, .mint, .mint
    ]

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────────
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.14, blue: 0.12),
                    Color(red: 0.02, green: 0.07, blue: 0.06),
                    Color.black
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.mint.opacity(0.12), .clear],
                center: UnitPoint(x: 0.5, y: 0.05),
                startRadius: 0, endRadius: 260
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── ORB + TITLE ─────────────────────────────────
                VStack(spacing: 8) {
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.mint.opacity(0.1 - Double(i) * 0.03), lineWidth: 1.5)
                                .frame(width: CGFloat(66 + i * 20))
                                .scaleEffect(pulse ? 1.0 : 0.88)
                                .animation(
                                    .easeInOut(duration: 2.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.45),
                                    value: pulse
                                )
                        }
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(
                                AngularGradient(colors: [Color.mint, .clear], center: .center),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: 64)
                            .rotationEffect(.degrees(orbRotation))
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.mint.opacity(0.2), .clear],
                                center: .center, startRadius: 0, endRadius: 28
                            ))
                            .frame(width: 52)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(LinearGradient(
                                colors: [.white, .mint], startPoint: .top, endPoint: .bottom
                            ))
                    }
                    .frame(height: 70)

                    VStack(spacing: 4) {
                        Text("Cadence")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("See the shape of your speech")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .padding(.top, 56)
                .padding(.bottom, 20)

                // ── SPEECH FLOW DNA — top ───────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Text("Speech Flow DNA")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(.mint)
                    }

                    // Animated bars
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(0..<dnaColors.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(dnaColors[i].gradient)
                                .frame(maxWidth: .infinity)
                                .frame(height: dnaHeights[i])
                                .shadow(color: dnaColors[i].opacity(0.4), radius: 4)
                        }
                    }
                    .frame(height: 44)

                    // Legend
                    HStack(spacing: 16) {
                        ForEach([
                            ("Confident", Color.mint),
                            ("Filler",    Color.orange),
                            ("Pause",     Color.yellow),
                            ("Lost Flow", Color.red)
                        ], id: \.0) { label, color in
                            HStack(spacing: 5) {
                                Circle().fill(color).frame(width: 6, height: 6)
                                Text(label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                // ── LIVE TELEMETRY HEADER ───────────────────────
                HStack {
                    Text("LIVE TELEMETRY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .tracking(1.5)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Color.mint).frame(width: 6, height: 6)
                        Text("On-device")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.mint.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.mint.opacity(0.3), lineWidth: 0.5))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

                // ── 2×2 FEATURE CARDS — below DNA ──────────────
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    IdleFeatureCard(symbol: "speedometer",                 title: "Pacing",      subtitle: "Words / min",   color: .mint)
                    IdleFeatureCard(symbol: "waveform.path",               title: "Rhythm",      subtitle: "Flow & pauses", color: .purple)
                    IdleFeatureCard(symbol: "exclamationmark.bubble.fill", title: "Fillers",     subtitle: "Um, uh, like",  color: .orange)
                    IdleFeatureCard(symbol: "eye.fill",                    title: "Eye Contact", subtitle: "Look up cues",  color: .cyan)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 16)

                // ── CTA BUTTONS ─────────────────────────────────
                VStack(spacing: 12) {
                    Button { session.startSession() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Start Live Practice")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LinearGradient(
                            colors: [Color(red: 0.2, green: 1.0, blue: 0.8), .mint],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.mint.opacity(0.35), radius: 16, y: 6)
                    }
                    .buttonStyle(.plain)

                    Button {} label: {
                        HStack(spacing: 10) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Record & Review")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    Text("Microphone · Camera · On-device only")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
            for i in 0..<dnaHeights.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                    withAnimation(
                        .easeInOut(duration: 1.0 + Double(i % 4) * 0.3)
                        .repeatForever(autoreverses: true)
                    ) {
                        dnaHeights[i] = CGFloat.random(in: 8...(i % 3 == 0 ? 40 : 28))
                    }
                }
            }
        }
    }
}

// MARK: - Feature Card
struct IdleFeatureCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}

typealias FeatureCard = IdleFeatureCard
