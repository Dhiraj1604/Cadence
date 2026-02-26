// SummaryView.swift
// Cadence — iOS 26 Native
// FIXED:
//   • .preferredColorScheme(.dark) — no more gray/white List background
//   • Speech Signature is the visual hero at the top
//   • Score ring smaller and secondary
//   • Consistent dark aesthetic matches PracticeView

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var session: SessionManager
    @State private var animatedWPM     = 0
    @State private var animatedFillers = 0
    @State private var animatedEye     = 0
    @State private var animatedRhythm  = 0.0
    @State private var animatedScore   = 0.0

    private var hasRealSpeech: Bool {
        session.finalWPM > 0 && session.duration >= 8
    }

    private var overallScore: Int {
        guard hasRealSpeech else { return 0 }
        var score = 50
        if session.finalWPM >= 120 && session.finalWPM <= 160 { score += 20 }
        else if (session.finalWPM >= 100 && session.finalWPM < 120)
             || (session.finalWPM > 160 && session.finalWPM <= 180) { score += 10 }
        if session.finalFillers == 0 { score += 15 }
        else if session.finalFillers <= 3 { score += 10 }
        else if session.finalFillers <= 7 { score += 4 }
        score += Int(Double(session.eyeContactPercentage) / 100.0 * 15)
        return min(100, score)
    }

    private var scoreColor: Color {
        switch overallScore {
        case 80...100: return .mint
        case 60..<80:  return .yellow
        default:       return .orange
        }
    }

    private var coachInsight: (symbol: String, color: Color, title: String, body: String) {
        let breaks = session.finalFlowEvents.filter {
            if case .flowBreak = $0.type { return true }; return false
        }.count
        if !hasRealSpeech {
            return ("mic.slash.fill", .secondary, "No Speech Detected",
                    "Speak clearly into the device and ensure microphone permission is granted.")
        }
        if breaks >= 3 {
            return ("brain.head.profile", .red, "High Cognitive Load",
                    "You lost flow \(breaks) times. Use a silent pause instead of filler — it sounds more confident.")
        }
        if session.finalFillers > 8 {
            return ("exclamationmark.bubble.fill", .orange, "Filler Word Habit",
                    "\(session.finalFillers) fillers detected. Replace each one with a deliberate 1-second pause.")
        }
        if session.finalWPM > 175 {
            return ("hare.fill", .yellow, "Speaking Too Fast",
                    "At \(session.finalWPM) WPM your audience struggles. Aim for 130–155 WPM.")
        }
        if session.finalWPM < 100 && session.finalWPM > 0 {
            return ("tortoise.fill", .yellow, "Pace Too Slow",
                    "At \(session.finalWPM) WPM you risk losing the room. Target 130–150 WPM.")
        }
        if overallScore >= 80 {
            return ("star.fill", .mint, "Outstanding Session",
                    "Strong pacing, minimal fillers, great eye contact. You're building real confidence.")
        }
        return ("chart.line.uptrend.xyaxis", .cyan, "Good Progress",
                "Rhythm at \(Int(session.finalRhythmStability))%. Every session builds the muscle.")
    }

    private var signatureData: SpeechSignatureData {
        SpeechSignatureData(
            wpm: session.finalWPM,
            fillerCount: session.finalFillers,
            rhythmStability: session.finalRhythmStability,
            eyeContactPercent: session.eyeContactPercentage,
            flowEvents: session.finalFlowEvents,
            duration: session.duration,
            overallScore: overallScore
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark aurora background — consistent with home screen
                ZStack {
                    Color(red: 0.02, green: 0.04, blue: 0.05).ignoresSafeArea()
                    // Subtle teal top bloom
                    RadialGradient(
                        colors: [Color(red: 0.04, green: 0.35, blue: 0.26).opacity(0.55), .clear],
                        center: UnitPoint(x: 0.5, y: 0.0),
                        startRadius: 0, endRadius: 380
                    )
                    .ignoresSafeArea()
                    // Bottom-right purple
                    RadialGradient(
                        colors: [Color(red: 0.28, green: 0.10, blue: 0.52).opacity(0.30), .clear],
                        center: UnitPoint(x: 0.9, y: 1.0),
                        startRadius: 0, endRadius: 300
                    )
                    .ignoresSafeArea()
                    // Vignette
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.55)],
                        center: .center, startRadius: 100, endRadius: 500
                    )
                    .ignoresSafeArea()
                }
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── SPEECH SIGNATURE ─────────────────────
                        if hasRealSpeech {
                            SpeechSignatureView(data: signatureData)
                                .padding(.horizontal, 16)
                        }

                        // ── SCORE RING ────────────────────────────
                        HStack(spacing: 20) {
                            // Score ring
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 10)
                                    .frame(width: 110, height: 110)
                                Circle()
                                    .trim(from: 0, to: CGFloat(animatedScore / 100))
                                    .stroke(
                                        scoreColor,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 110, height: 110)
                                    .rotationEffect(.degrees(-90))
                                    .animation(
                                        .spring(response: 1.5, dampingFraction: 0.75).delay(0.3),
                                        value: animatedScore
                                    )
                                VStack(spacing: 3) {
                                    Text("\(Int(animatedScore))")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(scoreColor)
                                        .contentTransition(.numericText())
                                    Text("Score")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Session score \(Int(animatedScore)) out of 100")

                            // Stats alongside ring
                            VStack(alignment: .leading, spacing: 8) {
                                Text(subtitleText)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(white: 0.55))
                                    .lineSpacing(3)

                                Text(coachInsight.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(coachInsight.color)

                                Text(coachInsight.body)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(white: 0.48))
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(scoreColor.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                        // ── METRICS ───────────────────────────────
                        if hasRealSpeech {
                            VStack(spacing: 1) {
                                DarkMetricRow(symbol: "speedometer",
                                              label: "Pacing",
                                              value: animatedWPM == 0 ? "—" : "\(animatedWPM) WPM",
                                              badge: pacingBadge, color: pacingColor,
                                              isFirst: true, isLast: false)
                                DarkMetricRow(symbol: "exclamationmark.bubble.fill",
                                              label: "Filler Words",
                                              value: "\(animatedFillers)",
                                              badge: fillerBadge, color: fillerColor,
                                              isFirst: false, isLast: false)
                                DarkMetricRow(symbol: "eye.fill",
                                              label: "Eye Contact",
                                              value: "\(animatedEye)%",
                                              badge: eyeBadge, color: eyeColor,
                                              isFirst: false, isLast: false)
                                DarkMetricRow(symbol: "waveform.path",
                                              label: "Rhythm",
                                              value: String(format: "%.0f%%", animatedRhythm),
                                              badge: rhythmBadge, color: rhythmColor,
                                              isFirst: false, isLast: true)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)

                            // ── SPEECH FLOW DNA ────────────────────
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(white: 0.4))
                                    Text("Speech Flow DNA")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.4))
                                }
                                SpeechDNATimeline(
                                    events: session.finalFlowEvents,
                                    duration: session.duration
                                )
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                        }

                        // ── TRANSCRIPT ─────────────────────────────
                        if !session.finalTranscript.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(white: 0.4))
                                    Text("Transcript")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.4))
                                }
                                Text(session.finalTranscript)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(white: 0.68))
                                    .lineSpacing(4)
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                        }

                        // ── PRACTICE AGAIN ─────────────────────────
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                session.resetSession()
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Practice Again")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.18, green: 0.97, blue: 0.76), Color(red: 0.08, green: 0.78, blue: 0.62)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.mint.opacity(0.25), radius: 12, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 36)
                        .accessibilityLabel("Practice Again")
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.02, green: 0.04, blue: 0.05).opacity(0.9), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            session.resetSession()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.mint)
                    }
                    .accessibilityLabel("Done — return to home")
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard hasRealSpeech else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 1.1)) {
                    animatedWPM     = session.finalWPM
                    animatedFillers = session.finalFillers
                    animatedEye     = session.eyeContactPercentage
                    animatedRhythm  = session.finalRhythmStability
                    animatedScore   = Double(overallScore)
                }
            }
        }
    }

    // MARK: - Subtitle
    private var subtitleText: String {
        guard hasRealSpeech else { return "No speech detected" }
        let d = Int(session.duration)
        let dur = d < 60 ? "\(d)s" : "\(d/60)m \(d%60)s"
        return "\(dur) · \(session.finalWPM) WPM · \(session.finalFillers) fillers"
    }

    private var pacingBadge: String {
        switch session.finalWPM {
        case 120...160: return "Ideal"
        case 100..<120: return "Slightly slow"
        case 160..<180: return "Slightly fast"
        case 0:         return "No speech"
        default:        return session.finalWPM > 180 ? "Too fast" : "Too slow"
        }
    }
    private var pacingColor: Color {
        switch session.finalWPM {
        case 120...160:            return .mint
        case 100..<120, 160..<180: return .yellow
        case 0:                    return .secondary
        default:                   return .orange
        }
    }
    private var fillerBadge: String {
        switch session.finalFillers {
        case 0:     return "Flawless"
        case 1...3: return "Great"
        case 4...7: return "Noticeable"
        default:    return "Needs work"
        }
    }
    private var fillerColor: Color {
        switch session.finalFillers {
        case 0...3: return .mint
        case 4...7: return .yellow
        default:    return .red
        }
    }
    private var eyeBadge: String {
        switch session.eyeContactPercentage {
        case 75...100: return "Excellent"
        case 50..<75:  return "Good"
        default:       return "Needs work"
        }
    }
    private var eyeColor: Color {
        switch session.eyeContactPercentage {
        case 75...100: return .mint
        case 50..<75:  return .yellow
        default:       return .orange
        }
    }
    private var rhythmBadge: String {
        switch session.finalRhythmStability {
        case 85...100: return "Consistent"
        case 65..<85:  return "Decent"
        case 40..<65:  return "Uneven"
        default:       return "Choppy"
        }
    }
    private var rhythmColor: Color {
        switch session.finalRhythmStability {
        case 75...100: return .mint
        case 50..<75:  return .yellow
        default:       return .orange
        }
    }
}

// MARK: - Dark Metric Row (replaces List-based MetricListRow)

struct DarkMetricRow: View {
    let symbol: String
    let label:  String
    let value:  String
    let badge:  String
    let color:  Color
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack {
            Label(label, systemImage: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value). \(badge)")
    }
}

// MARK: - Speech DNA Timeline (dark version)

struct SpeechDNATimeline: View {
    let events:   [FlowEvent]
    let duration: TimeInterval

    private var strongCount: Int { events.filter { if case .strongMoment = $0.type { return true }; return false }.count }
    private var fillerCount: Int { events.filter { if case .filler      = $0.type { return true }; return false }.count }
    private var hesitCount:  Int { events.filter { if case .hesitation  = $0.type { return true }; return false }.count }
    private var breakCount:  Int { events.filter { if case .flowBreak   = $0.type { return true }; return false }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if events.isEmpty {
                Text("No flow events recorded")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 44)
                        ForEach(events) { ev in
                            let x = duration > 1 ? geo.size.width * CGFloat(ev.timestamp / duration) : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ev.color)
                                .frame(width: 3.5, height: 30)
                                .offset(x: min(max(x - 1.75, 0), geo.size.width - 4),
                                        y: (44 - 30) / 2)
                        }
                    }
                }
                .frame(height: 44)

                HStack {
                    Text("0:00").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Spacer()
                    Text(timeLabel(duration)).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                HStack(spacing: 14) {
                    DNAEventCount(color: .mint,   count: strongCount, label: "Strong")
                    DNAEventCount(color: .orange, count: fillerCount, label: "Fillers")
                    DNAEventCount(color: .yellow, count: hesitCount,  label: "Pauses")
                    DNAEventCount(color: .red,    count: breakCount,  label: "Breaks")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(strongCount) strong, \(fillerCount) fillers, \(hesitCount) pauses, \(breakCount) breaks")
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t)/60, Int(t)%60)
    }
}

struct DNAEventCount: View {
    let color: Color; let count: Int; let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Metric Row (kept for InsightsView compatibility)
struct MetricListRow: View {
    let symbol: String
    let label:  String
    let value:  String
    let badge:  String
    let color:  Color

    var body: some View {
        HStack {
            Label(label, systemImage: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value). \(badge)")
    }
}
