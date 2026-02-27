// IdleView.swift
// Cadence — Speech Flow DNA on top, 4 cards below

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
                colors: [Color.mint.opacity(0.09), .clear],
                center: UnitPoint(x: 0.5, y: 0.05),
                startRadius: 0, endRadius: 220
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── ORB + TITLE ─────────────────────────────────
                VStack(spacing: 6) {
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.mint.opacity(0.07 - Double(i) * 0.02), lineWidth: 1)
                                .frame(width: CGFloat(62 + i * 18))
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
                                AngularGradient(colors: [Color.mint.opacity(0.9), .clear], center: .center),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .frame(width: 60)
                            .rotationEffect(.degrees(orbRotation))
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.mint.opacity(0.15), .clear],
                                center: .center, startRadius: 0, endRadius: 24
                            ))
                            .frame(width: 48)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 17, weight: .ultraLight))
                            .foregroundStyle(LinearGradient(
                                colors: [.white, .mint], startPoint: .top, endPoint: .bottom
                            ))
                    }
                    .frame(height: 60)

                    VStack(spacing: 3) {
                        Text("Cadence")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        Text("See the shape of your speech")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(white: 0.46))
                    }
                }
                .padding(.top, 52)
                .padding(.bottom, 14)

                // ── SPEECH FLOW DNA — top ───────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(white: 0.38))
                        Text("Speech Flow DNA")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.38))
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(.mint)
                    }

                    // Animated bars
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<dnaColors.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(dnaColors[i].gradient)
                                .frame(maxWidth: .infinity)
                                .frame(height: dnaHeights[i])
                        }
                    }
                    .frame(height: 40)

                    // Legend
                    HStack(spacing: 14) {
                        ForEach([
                            ("Confident", Color.mint),
                            ("Filler",    Color.orange),
                            ("Pause",     Color.yellow),
                            ("Lost Flow", Color.red)
                        ], id: \.0) { label, color in
                            HStack(spacing: 4) {
                                Circle().fill(color).frame(width: 5, height: 5)
                                Text(label)
                                    .font(.system(size: 9.5, weight: .regular))
                                    .foregroundStyle(Color(white: 0.42))
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // ── LIVE TELEMETRY HEADER ───────────────────────
                HStack {
                    Text("LIVE TELEMETRY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(white: 0.38))
                        .tracking(1.2)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color.mint).frame(width: 5, height: 5)
                        Text("On-device")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.mint)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.mint.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.mint.opacity(0.22), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // ── 2×2 FEATURE CARDS — below DNA ──────────────
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    IdleFeatureCard(symbol: "speedometer",                 title: "Pacing",      subtitle: "Words / min",   color: .mint)
                    IdleFeatureCard(symbol: "waveform.path",               title: "Rhythm",      subtitle: "Flow & pauses", color: .purple)
                    IdleFeatureCard(symbol: "exclamationmark.bubble.fill", title: "Fillers",     subtitle: "Um, uh, like",  color: .orange)
                    IdleFeatureCard(symbol: "eye.fill",                    title: "Eye Contact", subtitle: "Look up cues",  color: .cyan)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 10)

                // ── CTA BUTTONS ─────────────────────────────────
                VStack(spacing: 8) {
                    Button { session.startSession() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Start Live Practice")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient(
                            colors: [Color(red: 0.2, green: 1.0, blue: 0.8), .mint],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: Color.mint.opacity(0.30), radius: 14, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button {} label: {
                        HStack(spacing: 8) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Record & Review")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color(white: 0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Text("Microphone · Camera · On-device only")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(white: 0.26))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
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
                        dnaHeights[i] = CGFloat.random(in: 6...(i % 3 == 0 ? 36 : 26))
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
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(white: 0.42))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

typealias FeatureCard = IdleFeatureCard

// MARK: - Session Row
struct SessionRow: View {
    let record: SessionRecord
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(record.scoreColor.opacity(0.2), lineWidth: 2).frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: CGFloat(record.performanceScore) / 100)
                    .stroke(record.scoreColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text("\(record.performanceScore)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(record.scoreColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(record.dateString).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                HStack(spacing: 10) {
                    Label("\(record.wpm) WPM", systemImage: "speedometer").font(.system(size: 12)).foregroundStyle(.secondary)
                    Label("\(record.fillers) fillers", systemImage: "exclamationmark.bubble").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Text(record.durationString).font(.system(size: 13)).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().padding(.leading, 74)
    }
}
