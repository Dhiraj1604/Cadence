// IdleView.swift
// Cadence — Practice Tab (Home Screen)
//
// Design rules:
//  • Full dark — matches the app's visual language
//  • NO NavigationStack — that was causing the white bar
//  • ONE primary action: "Let's Start" button at the bottom
//  • ONE secondary mode card: Record & Review
//  • "Live Practice" card REMOVED — it was a duplicate of Let's Start
//  • Session history strip shows only when sessions exist

import SwiftUI

struct IdleView: View {
    @EnvironmentObject var session: SessionManager

    @State private var orbRotation: Double  = 0
    @State private var pulse                = false
    @State private var appeared             = false
    @State private var dnaHeights: [CGFloat] = Array(repeating: 18, count: 20)
    @State private var showRecord           = false
    @State private var startHaptic          = false

    private let dnaColors: [Color] = [
        .mint, .orange, .mint, .mint, .yellow, .mint,
        .red,  .mint,   .mint, .orange, .mint,  .mint,
        .mint, .yellow, .mint, .orange, .mint,  .mint,
        .mint, .mint
    ]

    var body: some View {
        ZStack {

            // ── Full dark background ──────────────────────────
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.09, blue: 0.08),
                    Color(red: 0.02, green: 0.05, blue: 0.05),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.mint.opacity(0.09), .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    Spacer().frame(height: 48)

                    // ── ORB ──────────────────────────────────
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.mint.opacity(0.07 - Double(i) * 0.02), lineWidth: 1)
                                .frame(width: CGFloat(86 + i * 28))
                                .scaleEffect(pulse ? 1.0 : 0.87)
                                .animation(
                                    .easeInOut(duration: 2.7)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.45),
                                    value: pulse
                                )
                        }
                        Circle()
                            .trim(from: 0, to: 0.22)
                            .stroke(
                                AngularGradient(
                                    colors: [Color.mint.opacity(0.85), .clear],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .frame(width: 84)
                            .rotationEffect(.degrees(orbRotation))
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.mint.opacity(0.18), .clear],
                                    center: .center, startRadius: 0, endRadius: 38
                                )
                            )
                            .frame(width: 72)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 26, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .mint],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    .frame(height: 100)
                    .accessibilityHidden(true)

                    Spacer().frame(height: 16)

                    // ── TITLE ─────────────────────────────────
                    VStack(spacing: 6) {
                        Text("Cadence")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        Text("See the shape of your speech")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(white: 0.46))
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                    Spacer().frame(height: 28)

                    // ── SPEECH FLOW DNA ───────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Speech Flow DNA", systemImage: "waveform.path.ecg")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(white: 0.40))
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
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
                        .frame(height: 44)
                        .accessibilityHidden(true)

                        // Legend
                        HStack(spacing: 14) {
                            ForEach([
                                ("Confident", Color.mint),
                                ("Filler",    Color.orange),
                                ("Pause",     Color.yellow),
                                ("Lost Flow", Color.red)
                            ], id: \.0) { name, color in
                                HStack(spacing: 4) {
                                    Circle().fill(color).frame(width: 6, height: 6)
                                    Text(name)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(Color(white: 0.38))
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Speech DNA legend: Confident, Filler, Pause, Lost Flow")
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 22)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                    Spacer().frame(height: 16)

                    // ── RECORD & REVIEW CARD ──────────────────
                    // This is the ONLY secondary mode card.
                    // "Live Practice" card is gone — Let's Start does that job.
                    Button {
                        showRecord = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(Color.purple.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.purple)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Record & Review")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Record yourself, get a full speech transcript and pacing analysis")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color(white: 0.42))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(white: 0.28))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.purple.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                    .accessibilityLabel("Record and Review: Record yourself to get speech analysis")
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

                    // ── SESSION HISTORY ───────────────────────
                    if !session.sessionHistory.isEmpty {
                        Spacer().frame(height: 16)
                        RecentSessionsRow(history: session.sessionHistory)
                            .padding(.horizontal, 22)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
                    }

                    // Bottom spacer for the sticky button
                    Spacer().frame(height: 100)
                }
            }

            // ── LET'S START — sticky at bottom ───────────────
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    // Fade out the scroll content behind the button
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)

                    Button {
                        startHaptic.toggle()
                        session.startSession()
                    } label: {
                        Label("Let's Start", systemImage: "mic.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.mint, Color(red: 0.18, green: 0.90, blue: 0.76)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 17))
                            .shadow(color: Color.mint.opacity(0.38), radius: 20, y: 4)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .medium), trigger: startHaptic)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
                    .accessibilityLabel("Start live practice session")

                    Color.black.frame(height: 0) // absorbs safe area
                }
                .background(.black.opacity(0.85))
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordVideoView()
        }
        .onAppear {
            pulse    = true
            appeared = true
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
            // Staggered DNA bar animations
            for i in 0..<dnaHeights.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(i)) {
                    withAnimation(
                        .easeInOut(duration: 1.0 + Double.random(in: 0...1.0))
                        .repeatForever(autoreverses: true)
                    ) {
                        dnaHeights[i] = CGFloat.random(in: 8...(i % 3 == 0 ? 42 : 30))
                    }
                }
            }
        }
    }
}

// MARK: - Recent Sessions Row
struct RecentSessionsRow: View {
    let history: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.38))
                Spacer()
                if history.count > 1 {
                    let avg = history.reduce(0) { $0 + $1.wpm } / history.count
                    Text("Avg \(avg) WPM")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.mint)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(history.prefix(6)) { record in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .stroke(record.scoreColor.opacity(0.22), lineWidth: 2)
                                    .frame(width: 42, height: 42)
                                Circle()
                                    .trim(from: 0, to: CGFloat(record.performanceScore) / 100)
                                    .stroke(
                                        record.scoreColor,
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                    )
                                    .frame(width: 42, height: 42)
                                    .rotationEffect(.degrees(-90))
                                Text("\(record.performanceScore)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(record.scoreColor)
                            }
                            Text(record.durationString)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(white: 0.34))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Session score \(record.performanceScore), \(record.durationString)")
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
