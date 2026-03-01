// IdleView.swift
// Cadence — Dark Green Mint Home Screen

import SwiftUI

struct IdleView: View {
    @EnvironmentObject var session: SessionManager
    @State private var dnaAppeared = false
    @State private var showRecordVideo = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.cadenceBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── HEADER ──────────────────────────────────────────
                    headerSection
                        .padding(.top, 56)
                        .padding(.horizontal, 24)
                        .staggerIn(appeared, delay: 0.0)

                    // ── SPEECH FLOW DNA CARD ─────────────────────────────
                    dnaCard
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .staggerIn(appeared, delay: 0.2)

                    // ── PRIMARY CTA ──────────────────────────────────────
                    Button {
                        session.startSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Start Live Practice")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LinearGradient.cadencePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.mint.opacity(0.35), radius: 16, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .staggerIn(appeared, delay: 0.3)

                    // ── SECONDARY CTA ────────────────────────────────────
                    Button {
                        showRecordVideo = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Record & Review")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.mint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.mint.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.mint.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .staggerIn(appeared, delay: 0.35)

                    // ── PRIVACY FOOTER ───────────────────────────────────
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.mint.opacity(0.4))
                        Text("Microphone · Camera · On-device only")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .staggerIn(appeared, delay: 0.4)
                }
            }
        }
        .sheet(isPresented: $showRecordVideo) {
            RecordVideoView()
        }
        .onAppear {
            // Reset first so animation always plays fresh when returning to home
            appeared = false
            dnaAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                dnaAppeared = true
            }
        }
        .onDisappear {
            // Reset so animation is ready to play again on next appear
            appeared = false
            dnaAppeared = false
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            // The ZStack needs a fixed frame large enough to show the rings
            // at their peak expansion WITHOUT overflowing into the "Cadence" text.
            // Rings scale from 84pt → 84*1.75 = 147pt, so 160pt frame is safe.
            ZStack {
                PulseRing(baseSize: 84, delay: 0.0)
                PulseRing(baseSize: 84, delay: 0.9)

                // Core filled orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.mint.opacity(0.30), Color.mint.opacity(0.07)],
                            center: .center, startRadius: 4, endRadius: 44
                        )
                    )
                    .frame(width: 84, height: 84)

                // "waveform" available from iOS 13+
                Image(systemName: "waveform")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(LinearGradient.cadencePrimary)
            }
            .frame(width: 160, height: 160) // contains rings so they never overlap text below

            VStack(spacing: 6) {
                Text("Cadence")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.white)

                Text("See the shape of your speech")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - DNA Preview Card
    private var dnaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.mint)
                    Text("Speech Flow DNA")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("EXAMPLE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.mint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.mint.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("Generated after each session — unique to you")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.38))

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(dnaBarColor(for: index))
                        // Bars animate in once on appear, then stay perfectly still
                        .frame(height: dnaAppeared ? dnaBarHeight(for: index) : 3)
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.7)
                                .delay(Double(index) * 0.035),
                            value: dnaAppeared
                        )
                }
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                dnaLegend(color: Color.mint,   label: "Confident")
                dnaLegend(color: Color.orange, label: "Filler")
                dnaLegend(color: Color.yellow, label: "Pause")
                dnaLegend(color: Color.red,    label: "Lost Flow")
            }
        }
        .padding(18)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.mint.opacity(0.12), lineWidth: 1)
        )
    }

    private func dnaLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func dnaBarHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [38, 56, 42, 28, 18, 14, 10, 33, 48, 42, 18, 14, 28, 42, 42, 28, 18, 14, 38, 56, 30, 22, 44, 36]
        return heights[index % heights.count]
    }

    private func dnaBarColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color.mint, Color.mint, Color.mint, Color.orange, Color.orange, Color.yellow,
            Color.mint, Color.mint, Color.mint, Color.red,    Color.red,    Color.mint,
            Color.mint, Color.mint, Color.mint, Color.orange, Color.mint,   Color.mint,
            Color.mint, Color.mint, Color.mint, Color.yellow, Color.mint,   Color.mint
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Pulse Ring
// Each ring owns its own @State — they animate independently.
// Scale 1.0 → 1.75 keeps rings visually close to the orb (feels like circling).
// autoreverses: false = expand + fade → snap back instantly → repeat (sonar ping).
struct PulseRing: View {
    let baseSize: CGFloat
    let delay: Double

    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(Color.mint.opacity(animating ? 0 : 0.50), lineWidth: 1.5)
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(animating ? 1.75 : 1.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        .easeOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
                    ) {
                        animating = true
                    }
                }
            }
    }
}
