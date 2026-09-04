// IdleView.swift
// Cadence — iOS 26 Native Home Screen

import SwiftUI

struct IdleView: View {
    @EnvironmentObject var session: SessionManager
    @State private var dnaAppeared = false
    @State private var showRecordVideo = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── HERO ORBS + TITLE ────────────────────────────────
                    heroHeader
                        .staggerIn(appeared, delay: 0.05)

                    // ── SPEECH FLOW DNA CARD ─────────────────────────────
                    dnaCard
                        .staggerIn(appeared, delay: 0.15)

                    // ── PRIMARY CTA ──────────────────────────────────────
                    Button {
                        session.startSession()
                    } label: {
                        Label("Start Live Practice", systemImage: "mic.fill")
                    }
                    .buttonStyle(CadencePrimaryButtonStyle())
                    .staggerIn(appeared, delay: 0.22)

                    // ── SECONDARY CTA ────────────────────────────────────
                    Button {
                        showRecordVideo = true
                    } label: {
                        Label("Record & Review", systemImage: "video.fill")
                    }
                    .buttonStyle(CadenceSecondaryButtonStyle())
                    .staggerIn(appeared, delay: 0.28)

                    // ── PRIVACY NOTE ─────────────────────────────────────
                    Label("All processing is on-device. Nothing leaves your phone.", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 32)
                        .staggerIn(appeared, delay: 0.35)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Cadence")
            .navigationBarTitleDisplayMode(.large)
            .sensoryFeedback(.impact, trigger: session.state)
        }
        .sheet(isPresented: $showRecordVideo) {
            RecordVideoView()
        }
        .onAppear {
            appeared = false
            dnaAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dnaAppeared = true
            }
        }
        .onDisappear {
            appeared = false
            dnaAppeared = false
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                PulseRing(baseSize: 84, delay: 0.0)
                PulseRing(baseSize: 84, delay: 0.9)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.mint.opacity(0.25), Color.mint.opacity(0.0)],
                            center: .center, startRadius: 4, endRadius: 44
                        )
                    )
                    .frame(width: 84, height: 84)

                Image(systemName: "waveform")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(LinearGradient.cadencePrimary)
            }
            .frame(width: 160, height: 160)

            VStack(spacing: 4) {
                Text("See the shape of your speech")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - DNA Preview Card
    private var dnaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Speech Flow DNA", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("EXAMPLE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.mint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.mint.opacity(0.12), in: Capsule())
            }

            Text("Generated after each session — unique to you")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(dnaBarColor(for: index))
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
                dnaLegend(color: .mint,   label: "Confident")
                dnaLegend(color: .orange, label: "Filler")
                dnaLegend(color: .yellow, label: "Pause")
                dnaLegend(color: .red,    label: "Lost Flow")
            }
        }
        .padding(16)
        .cadenceCard()
    }

    private func dnaLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func dnaBarHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [38, 56, 42, 28, 18, 14, 10, 33, 48, 42, 18, 14, 28, 42, 42, 28, 18, 14, 38, 56, 30, 22, 44, 36]
        return heights[index % heights.count]
    }

    private func dnaBarColor(for index: Int) -> Color {
        let colors: [Color] = [
            .mint, .mint, .mint, .orange, .orange, .yellow,
            .mint, .mint, .mint, .red,    .red,    .mint,
            .mint, .mint, .mint, .orange, .mint,   .mint,
            .mint, .mint, .mint, .yellow, .mint,   .mint
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Pulse Ring
struct PulseRing: View {
    let baseSize: CGFloat
    let delay: Double

    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(Color.mint.opacity(animating ? 0 : 0.45), lineWidth: 1.5)
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(animating ? 1.75 : 1.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                        animating = true
                    }
                }
            }
    }
}
