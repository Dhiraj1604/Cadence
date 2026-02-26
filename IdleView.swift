// IdleView.swift
// Cadence — v3
// FIXED:
//   1. Hero (orb + title) is OUTSIDE ScrollView — never drifts when scrolling
//   2. Aurora blobs are vivid: opacity 0.40–0.55, blur reduced, vignette lightened
//   3. Two equal CTAs locked at bottom, no floating
//   4. Compact layout — nothing breaks when scrolling extra content

import SwiftUI

struct IdleView: View {
    @EnvironmentObject var session: SessionManager

    @State private var orbPulse     = false
    @State private var orbRotation: Double = 0
    @State private var innerGlow: Double  = 0.10
    @State private var appeared     = false
    @State private var showRecord   = false
    @State private var startHaptic  = false
    @State private var recordHaptic = false

    var body: some View {
        ZStack {
            // ── Animated aurora background ──────────────
            AuroraBackground()
                .ignoresSafeArea()

            // ── Full layout: pinned hero + scrollable body + pinned CTA ──
            VStack(spacing: 0) {

                // ── HERO — pinned, never scrolls ─────────
                VStack(spacing: 18) {
                    Spacer().frame(height: 4)

                    CadenceOrb(
                        pulse: orbPulse,
                        rotation: orbRotation,
                        glow: innerGlow
                    )
                    .frame(width: 108, height: 108)
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text("Cadence")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(-0.5)
                        Text("See the shape of your speech")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(white: 0.50))
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.93)
                .animation(.spring(response: 0.75, dampingFraction: 0.8).delay(0.05), value: appeared)

                Spacer().frame(height: 28)

                // ── SCROLLABLE BODY ──────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {

                        WhatYouMeasureStrip()
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.22), value: appeared)

                        if !session.sessionHistory.isEmpty {
                            RecentSessionsRow(history: session.sessionHistory)
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 14)
                                .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.34), value: appeared)
                        }

                        // Breathing room above CTA
                        Spacer().frame(height: 8)
                    }
                }

                // ── DUAL CTA — pinned at bottom ──────────
                DualCTABar(
                    startHaptic: $startHaptic,
                    recordHaptic: $recordHaptic,
                    onStart: {
                        startHaptic.toggle()
                        session.startSession()
                    },
                    onRecord: {
                        recordHaptic.toggle()
                        showRecord = true
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.44), value: appeared)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showRecord) {
            RecordVideoView()
        }
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                orbPulse = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true).delay(1.0)) {
                innerGlow = 0.22
            }
        }
    }
}

// MARK: - Aurora Background (VIVID version)

struct AuroraBackground: View {
    @State private var t: Double = 0
    private let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Deep near-black base
            Color(red: 0.018, green: 0.032, blue: 0.038)

            // ── BLOB 1: Vivid teal — top left ────────────
            AuroraBlob(
                color: Color(red: 0.00, green: 0.85, blue: 0.65),
                opacity: 0.50,
                radius: 280,
                blurScale: 0.38,
                x: 0.08 + 0.22 * sin(t * 0.28),
                y: 0.10 + 0.16 * sin(t * 0.18)
            )

            // ── BLOB 2: Bright cyan — top right ──────────
            AuroraBlob(
                color: Color(red: 0.00, green: 0.65, blue: 0.95),
                opacity: 0.44,
                radius: 260,
                blurScale: 0.38,
                x: 0.88 + 0.14 * sin(t * 0.22 + 1.1),
                y: 0.16 + 0.18 * sin(t * 0.26 + 0.6)
            )

            // ── BLOB 3: Purple/violet — left mid ─────────
            AuroraBlob(
                color: Color(red: 0.50, green: 0.15, blue: 0.90),
                opacity: 0.38,
                radius: 240,
                blurScale: 0.42,
                x: 0.12 + 0.18 * sin(t * 0.16 + 2.0),
                y: 0.55 + 0.20 * sin(t * 0.20 + 0.3)
            )

            // ── BLOB 4: Mint hero — center ────────────────
            AuroraBlob(
                color: Color(red: 0.25, green: 1.00, blue: 0.75),
                opacity: 0.30,
                radius: 220,
                blurScale: 0.40,
                x: 0.50 + 0.14 * sin(t * 0.30 + 1.7),
                y: 0.32 + 0.14 * sin(t * 0.23 + 3.0)
            )

            // ── BLOB 5: Deep emerald — bottom right ───────
            AuroraBlob(
                color: Color(red: 0.00, green: 0.72, blue: 0.52),
                opacity: 0.48,
                radius: 300,
                blurScale: 0.36,
                x: 0.82 + 0.16 * sin(t * 0.19 + 0.8),
                y: 0.82 + 0.16 * sin(t * 0.24 + 2.3)
            )

            // ── BLOB 6: Indigo — bottom left ──────────────
            AuroraBlob(
                color: Color(red: 0.30, green: 0.05, blue: 0.70),
                opacity: 0.35,
                radius: 230,
                blurScale: 0.44,
                x: 0.18 + 0.16 * sin(t * 0.18 + 3.4),
                y: 0.88 + 0.10 * sin(t * 0.27 + 1.0)
            )

            // ── Soft center glow boost ────────────────────
            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.35, blue: 0.28).opacity(0.40),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )

            // ── Vignette — LIGHT, just edges ─────────────
            // Old version had 0.72 opacity which killed everything
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.48)],
                center: .center,
                startRadius: 160,
                endRadius: 520
            )

            // ── Top text-legibility gradient ──────────────
            LinearGradient(
                colors: [Color.black.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.30)
            )

            // ── Film grain ────────────────────────────────
            Canvas { ctx, size in
                for row in stride(from: 0, to: Int(size.height), by: 2) {
                    for col in stride(from: 0, to: Int(size.width), by: 2) {
                        let hash = (row &* 2654435761) &+ (col &* 2246822519)
                        let norm = Double(hash & 0xFFFF) / 65535.0
                        if norm > 0.74 {
                            let alpha = (norm - 0.74) / 0.26 * 0.045
                            ctx.fill(
                                Path(CGRect(x: col, y: row, width: 1, height: 1)),
                                with: .color(.white.opacity(alpha))
                            )
                        }
                    }
                }
            }
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
        .onReceive(timer) { _ in
            t += 0.010
        }
    }
}

struct AuroraBlob: View {
    let color: Color
    let opacity: Double
    let radius: CGFloat
    let blurScale: CGFloat
    let x: Double
    let y: Double

    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(opacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .blur(radius: radius * blurScale)
                .position(
                    x: CGFloat(x) * geo.size.width,
                    y: CGFloat(y) * geo.size.height
                )
        }
    }
}

// MARK: - Orb

struct CadenceOrb: View {
    let pulse: Bool
    let rotation: Double
    let glow: Double

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.mint.opacity(0.06 - Double(i) * 0.014), lineWidth: 1)
                    .frame(width: CGFloat(84 + i * 22))
                    .scaleEffect(pulse ? 1.0 : 0.88)
                    .animation(
                        .easeInOut(duration: 3.8 + Double(i) * 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.7),
                        value: pulse
                    )
            }
            Circle()
                .trim(from: 0, to: 0.16)
                .stroke(
                    AngularGradient(colors: [Color.mint.opacity(0.9), .clear], center: .center),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: 76)
                .rotationEffect(.degrees(rotation))

            Circle()
                .trim(from: 0.54, to: 0.62)
                .stroke(Color.mint.opacity(0.22), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                .frame(width: 76)
                .rotationEffect(.degrees(rotation + 180))

            Circle()
                .fill(RadialGradient(
                    colors: [Color.mint.opacity(glow), .clear],
                    center: .center, startRadius: 0, endRadius: 32
                ))
                .frame(width: 60)

            Image(systemName: "waveform.and.mic")
                .font(.system(size: 21, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .mint.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                )
        }
    }
}

// MARK: - Metrics Grid

struct WhatYouMeasureStrip: View {
    private let metrics: [(icon: String, label: String, sub: String, color: Color)] = [
        ("speedometer",            "Pacing",      "Words/min",     .mint),
        ("exclamationmark.bubble", "Fillers",     "um, uh, like",  .orange),
        ("eye.fill",               "Eye Contact", "Look up cues",  .cyan),
        ("waveform.path",          "Rhythm",      "Flow & pauses", .purple),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WHAT CADENCE TRACKS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.38))
                    .tracking(1.0)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(.mint).frame(width: 5, height: 5)
                    Text("Real-time · On-device")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(white: 0.34))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(metrics, id: \.label) { m in
                    MetricFeatureCard(icon: m.icon, label: m.label, sub: m.sub, color: m.color)
                }
            }
        }
    }
}

struct MetricFeatureCard: View {
    let icon: String
    let label: String
    let sub: String
    let color: Color

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.40))
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(color.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

// MARK: - Dual CTA

struct DualCTABar: View {
    @Binding var startHaptic: Bool
    @Binding var recordHaptic: Bool
    let onStart: () -> Void
    let onRecord: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Fade from transparent to solid so content disappears cleanly
            LinearGradient(
                colors: [.clear, Color(red: 0.018, green: 0.032, blue: 0.038)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 28)

            VStack(spacing: 10) {
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill").font(.system(size: 15, weight: .semibold))
                        Text("Start Live Practice").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.20, green: 0.98, blue: 0.78), Color(red: 0.08, green: 0.76, blue: 0.60)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.mint.opacity(0.40), radius: 20, y: 6)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: startHaptic)
                .accessibilityLabel("Start live practice session")

                Button(action: onRecord) {
                    HStack(spacing: 10) {
                        Image(systemName: "video.fill").font(.system(size: 15, weight: .semibold))
                        Text("Record & Review").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.90))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.10))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: recordHaptic)
                .accessibilityLabel("Record yourself for full speech analysis")

                Text("Microphone · Camera · On-device only")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.28))
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(Color(red: 0.018, green: 0.032, blue: 0.038))
        }
    }
}

// MARK: - Recent Sessions

struct RecentSessionsRow: View {
    let history: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.38))
                    .tracking(1.0)
                Spacer()
                if history.count >= 2 {
                    let avg = history.prefix(5).reduce(0) { $0 + $1.wpm } / min(history.count, 5)
                    Text("Avg \(avg) WPM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.mint)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(history.prefix(8)) { record in
                        SessionHistoryPill(record: record)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

struct SessionHistoryPill: View {
    let record: SessionRecord
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(record.scoreColor.opacity(0.22), lineWidth: 2).frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: CGFloat(record.performanceScore) / 100)
                    .stroke(record.scoreColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text("\(record.performanceScore)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(record.scoreColor)
            }
            Text(record.durationString).font(.system(size: 10)).foregroundStyle(Color(white: 0.33))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score \(record.performanceScore), \(record.durationString)")
    }
}
