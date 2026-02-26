// IdleView.swift
// Cadence — Practice Tab
// iOS 26 native design language — inspired by Apple Health, Journal, Music
// SF Pro everywhere, SF Symbols, system colors, native components

import SwiftUI

struct IdleView: View {
    @EnvironmentObject var session: SessionManager
    @State private var orbRotation: Double = 0
    @State private var pulse = false
    @State private var appeared = false
    @State private var dnaHeights: [CGFloat] = Array(repeating: 18, count: 20)

    private let dnaColors: [Color] = [
        .mint, .orange, .mint, .mint, .yellow, .mint,
        .red, .mint, .mint, .orange, .mint, .mint,
        .mint, .yellow, .mint, .orange, .mint, .mint,
        .mint, .mint
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── HERO CARD ─────────────────────────────
                    // Dark glass card — sits at top like Health's summary card
                    ZStack {
                        // Background gradient
                        RoundedRectangle(cornerRadius: 26)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.06, green: 0.13, blue: 0.12),
                                        Color(red: 0.03, green: 0.07, blue: 0.07)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .strokeBorder(Color.mint.opacity(0.15), lineWidth: 1)
                            )

                        // Ambient glow
                        RadialGradient(
                            colors: [Color.mint.opacity(0.12), .clear],
                            center: UnitPoint(x: 0.5, y: 0.25),
                            startRadius: 0,
                            endRadius: 180
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 26))

                        VStack(spacing: 20) {
                            // ORB
                            ZStack {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .stroke(Color.mint.opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                                        .frame(width: CGFloat(90 + i * 28))
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
                                        AngularGradient(
                                            colors: [Color.mint.opacity(0.85), .clear],
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                                    )
                                    .frame(width: 88)
                                    .rotationEffect(.degrees(orbRotation))

                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.mint.opacity(0.18), .clear],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 38
                                        )
                                    )
                                    .frame(width: 76)

                                Image(systemName: "waveform.and.mic")
                                    .font(.system(size: 26, weight: .ultraLight))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, Color.mint],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .frame(height: 90)

                            // Title
                            VStack(spacing: 6) {
                                Text("Cadence")
                                    .font(.system(size: 36, weight: .bold, design: .default))
                                    .foregroundStyle(.white)

                                Text("See the shape of your speech")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundStyle(.secondary)
                                    .foregroundColor(Color(white: 0.55))
                            }

                            // CTA Button — full width, mint, SF Pro Semibold
                            Button {
                                session.startSession()
                            } label: {
                                Label("Let's Start", systemImage: "mic.fill")
                                    .font(.system(size: 17, weight: .semibold, design: .default))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(.mint)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // ── SPEECH FLOW DNA ───────────────────────
                    // Styled like a Health widget card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Speech Flow DNA", systemImage: "waveform.path.ecg")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.mint)
                        }

                        // Animated bar chart
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(0..<dnaColors.count, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(dnaColors[i].gradient)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: dnaHeights[i])
                            }
                        }
                        .frame(height: 48)
                        .padding(.vertical, 4)

                        // Legend — SF Symbols squares
                        HStack(spacing: 16) {
                            ForEach([
                                ("Confident", Color.mint),
                                ("Filler",    Color.orange),
                                ("Pause",     Color.yellow),
                                ("Lost Flow", Color.red)
                            ], id: \.0) { label, color in
                                HStack(spacing: 5) {
                                    Image(systemName: "square.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(color)
                                    Text(label)
                                        .font(.system(size: 11, weight: .regular, design: .default))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // ── WHAT YOU'LL GET — 2x2 grid ────────────
                    // Like Apple Health's category cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What Cadence tracks")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            FeatureCard(
                                symbol: "speedometer",
                                title: "Pacing",
                                subtitle: "Words per minute",
                                color: .mint
                            )
                            FeatureCard(
                                symbol: "exclamationmark.bubble.fill",
                                title: "Filler Words",
                                subtitle: "Um, uh, like, so",
                                color: .orange
                            )
                            FeatureCard(
                                symbol: "eye.fill",
                                title: "Eye Contact",
                                subtitle: "TrueDepth camera",
                                color: .cyan
                            )
                            FeatureCard(
                                symbol: "waveform.path",
                                title: "Rhythm",
                                subtitle: "Flow & consistency",
                                color: .purple
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 28)

                    // ── PRACTICE HISTORY ──────────────────────
                    if !session.sessionHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Sessions")
                                    .font(.system(size: 20, weight: .bold, design: .default))
                                    .foregroundStyle(.primary)
                                Spacer()
                                // Stats pill
                                HStack(spacing: 8) {
                                    Text("Avg \(session.averageWPM) WPM")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.mint)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule())
                            }
                            .padding(.horizontal, 20)

                            // Session list
                            LazyVStack(spacing: 1) {
                                ForEach(session.sessionHistory) { record in
                                    SessionRow(record: record)
                                }
                            }
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 28)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.bottom, 16)
            }
            .background(
                // System background — adapts to dark/light like native apps
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle("Cadence")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
        }
        .onAppear {
            pulse = true
            appeared = true
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
            // Animate DNA bars
            for i in 0..<dnaHeights.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(
                        .easeInOut(duration: 1.2 + Double(i) * 0.1)
                        .repeatForever(autoreverses: true)
                    ) {
                        dnaHeights[i] = CGFloat.random(in: 8...(i % 3 == 0 ? 44 : 32))
                    }
                }
            }
        }
    }
}

// MARK: - Feature Card (Health-style widget)
struct FeatureCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // SF Symbol in colored circle — like Health
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Session Row (like Health activity rows)
struct SessionRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 14) {
            // Score indicator
            ZStack {
                Circle()
                    .stroke(record.scoreColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 44, height: 44)
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
                Text(record.dateString)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    Label("\(record.wpm) WPM", systemImage: "speedometer")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Label("\(record.fillers) fillers", systemImage: "exclamationmark.bubble")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text(record.durationString)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        Divider()
            .padding(.leading, 74)
    }
}
