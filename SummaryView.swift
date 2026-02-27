// SummaryView.swift
// Cadence — Session Complete
// Speech Signature replaced with clear DNA bar chart

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var session: SessionManager
    @State private var animatedWPM    = 0
    @State private var animatedFillers = 0
    @State private var animatedEye    = 0
    @State private var animatedRhythm = 0.0
    @State private var animatedScore  = 0.0
    @State private var appeared       = false

    private var hasRealSpeech: Bool {
        session.finalWPM > 0 && session.duration >= 8
    }

    private var overallScore: Int {
        guard hasRealSpeech else { return 0 }
        var score = 50
        if session.finalWPM >= 120 && session.finalWPM <= 160 { score += 20 }
        else if (session.finalWPM >= 100 && session.finalWPM < 120) ||
                (session.finalWPM > 160 && session.finalWPM <= 180) { score += 10 }
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
                    "We couldn't measure your session. Speak clearly and ensure mic permission is granted.")
        }
        if breaks >= 3 {
            return ("brain.head.profile", .red, "High Cognitive Load",
                    "You lost flow \(breaks) times. Pause silently instead of filling. Silence sounds confident.")
        }
        if session.finalFillers > 8 {
            return ("exclamationmark.bubble.fill", .orange, "Filler Word Habit",
                    "You used \(session.finalFillers) filler words. Replace each with a deliberate 1-second pause — sounds 10× more confident.")
        }
        if session.finalWPM > 175 {
            return ("hare.fill", .yellow, "Speaking Too Fast",
                    "At \(session.finalWPM) WPM your audience struggles to keep up. Aim for 130–155 WPM.")
        }
        if session.finalWPM < 100 && session.finalWPM > 0 {
            return ("tortoise.fill", .yellow, "Pace Too Slow",
                    "At \(session.finalWPM) WPM you risk losing the room. Target 130–150 WPM.")
        }
        if overallScore >= 80 {
            return ("star.fill", .mint, "Outstanding Session",
                    "Strong pacing, minimal fillers, great eye contact. Keep building this habit.")
        }
        return ("chart.line.uptrend.xyaxis", .cyan, "Good Progress",
                "Rhythm stability at \(Int(session.finalRhythmStability))%. Every session builds the muscle.")
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.14, blue: 0.12),
                         Color(red: 0.02, green: 0.06, blue: 0.06),
                         Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── HEADER ───────────────────────────────
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Session Complete")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                            Text(subtitleText)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color(white: 0.44))
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.mint.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.mint)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 54)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                    // ── SCORE + INSIGHT CARD ──────────────────
                    HStack(spacing: 16) {
                        // Score ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 10)
                                .frame(width: 100, height: 100)
                            Circle()
                                .trim(from: 0, to: CGFloat(animatedScore / 100))
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 1.4, dampingFraction: 0.75).delay(0.3), value: animatedScore)
                            VStack(spacing: 1) {
                                Text("\(Int(animatedScore))")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor)
                                    .contentTransition(.numericText())
                                Text("Score")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(Color(white: 0.38))
                            }
                        }

                        // Insight text
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Image(systemName: coachInsight.symbol)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(coachInsight.color)
                                    .symbolRenderingMode(.hierarchical)
                                Text(coachInsight.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(coachInsight.body)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color(white: 0.55))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(scoreColor.opacity(0.18), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                    // ── SPEECH FLOW DNA ───────────────────────
                    if hasRealSpeech {
                        SpeechDNACard(events: session.finalFlowEvents, duration: session.duration)
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                    }

                    // ── METRICS ───────────────────────────────
                    if hasRealSpeech {
                        VStack(spacing: 0) {
                            SummaryMetricRow(
                                symbol: "speedometer", color: pacingColor,
                                label: "Pacing",
                                value: animatedWPM == 0 ? "—" : "\(animatedWPM) WPM",
                                badge: pacingBadge
                            )
                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)
                            SummaryMetricRow(
                                symbol: "exclamationmark.bubble.fill", color: fillerColor,
                                label: "Filler Words",
                                value: "\(animatedFillers)",
                                badge: fillerBadge
                            )
                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)
                            SummaryMetricRow(
                                symbol: "eye.fill", color: eyeColor,
                                label: "Eye Contact",
                                value: "\(animatedEye)%",
                                badge: eyeBadge
                            )
                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)
                            SummaryMetricRow(
                                symbol: "waveform.path", color: rhythmColor,
                                label: "Rhythm",
                                value: String(format: "%.0f%%", animatedRhythm),
                                badge: rhythmBadge
                            )
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)
                    }

                    // ── TRANSCRIPT ────────────────────────────
                    if !session.finalTranscript.isEmpty &&
                       session.finalTranscript != "No speech was detected during this session." {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 11)).foregroundStyle(Color(white: 0.36))
                                Text("Transcript")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.36))
                            }
                            Text(session.finalTranscript)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color(white: 0.60))
                                .lineSpacing(4)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
                    }

                    // ── PRACTICE AGAIN ────────────────────────
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            session.resetSession()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Practice Again")
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
                        .shadow(color: Color.mint.opacity(0.28), radius: 14, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.65), value: appeared)
                }
            }
        }
        .onAppear {
            appeared = true
            guard hasRealSpeech else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
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

    // MARK: - Labels
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
        case 120...160: return .mint
        case 100..<120, 160..<180: return .yellow
        case 0: return .secondary
        default: return .orange
        }
    }
    private var fillerBadge: String {
        switch session.finalFillers {
        case 0: return "Flawless"; case 1...3: return "Great"
        case 4...7: return "Noticeable"; default: return "Needs work"
        }
    }
    private var fillerColor: Color {
        switch session.finalFillers {
        case 0...3: return .mint; case 4...7: return .yellow; default: return .red
        }
    }
    private var eyeBadge: String {
        switch session.eyeContactPercentage {
        case 75...100: return "Excellent"; case 50..<75: return "Good"; default: return "Needs work"
        }
    }
    private var eyeColor: Color {
        switch session.eyeContactPercentage {
        case 75...100: return .mint; case 50..<75: return .yellow; default: return .orange
        }
    }
    private var rhythmBadge: String {
        switch session.finalRhythmStability {
        case 85...100: return "Consistent"; case 65..<85: return "Decent"
        case 40..<65: return "Uneven"; default: return "Choppy"
        }
    }
    private var rhythmColor: Color {
        switch session.finalRhythmStability {
        case 75...100: return .mint; case 50..<75: return .yellow; default: return .orange
        }
    }
}

// MARK: - Speech Flow DNA Card (replaces sine wave)
struct SpeechDNACard: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    // Categorise events into buckets for the bar chart
    struct Bucket {
        var strong   = 0
        var filler   = 0
        var pause    = 0
        var flowBreak = 0
        var isEmpty: Bool { strong + filler + pause + flowBreak == 0 }
    }

    var buckets: [Bucket] {
        let count = 24
        var result = Array(repeating: Bucket(), count: count)
        guard duration > 0 else { return result }
        for event in events {
            let idx = min(Int(event.timestamp / duration * Double(count)), count - 1)
            switch event.type {
            case .strongMoment: result[idx].strong    += 1
            case .filler:       result[idx].filler    += 1
            case .hesitation:   result[idx].pause     += 1
            case .flowBreak:    result[idx].flowBreak += 1
            }
        }
        return result
    }

    private var strongCount: Int { events.filter { if case .strongMoment = $0.type { return true }; return false }.count }
    private var fillerCount: Int { events.filter { if case .filler      = $0.type { return true }; return false }.count }
    private var pauseCount:  Int { events.filter { if case .hesitation  = $0.type { return true }; return false }.count }
    private var breakCount:  Int { events.filter { if case .flowBreak   = $0.type { return true }; return false }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.mint)
                    Text("Speech Flow DNA")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("your session, bar by bar")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(white: 0.32))
            }

            if events.isEmpty {
                Text("No events recorded in this session.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.35))
                    .padding(.vertical, 8)
            } else {
                // Bar chart — each column = one time slice
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(buckets.enumerated()), id: \.0) { _, bucket in
                        DNABarColumn(bucket: bucket)
                    }
                }
                .frame(height: 60)
                .padding(.vertical, 2)

                // Time axis
                HStack {
                    Text("0:00")
                        .font(.system(size: 9)).foregroundStyle(Color(white: 0.28))
                    Spacer()
                    Text(timeLabel(duration / 2))
                        .font(.system(size: 9)).foregroundStyle(Color(white: 0.28))
                    Spacer()
                    Text(timeLabel(duration))
                        .font(.system(size: 9)).foregroundStyle(Color(white: 0.28))
                }

                // Summary counts row
                HStack(spacing: 0) {
                    DNAStat(count: strongCount,  label: "Confident", color: .mint)
                    Spacer()
                    DNAStat(count: fillerCount,  label: "Fillers",   color: .orange)
                    Spacer()
                    DNAStat(count: pauseCount,   label: "Pauses",    color: .yellow)
                    Spacer()
                    DNAStat(count: breakCount,   label: "Lost Flow", color: .red)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.mint.opacity(0.12), lineWidth: 1))
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// Single stacked bar column
struct DNABarColumn: View {
    let bucket: SpeechDNACard.Bucket

    // dominant colour for the bar
    private var color: Color {
        if bucket.flowBreak > 0 { return .red }
        if bucket.filler > 0    { return .orange }
        if bucket.pause > 0     { return .yellow }
        if bucket.strong > 0    { return .mint }
        return Color.white.opacity(0.08)   // empty slot
    }
    private var height: CGFloat {
        if bucket.isEmpty { return 8 }
        let total = bucket.strong + bucket.filler + bucket.pause + bucket.flowBreak
        return CGFloat(10 + total * 10).clamped(to: 12...56)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.gradient)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

// Comparable extension for clamped
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

// Summary stat pill
struct DNAStat: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(Color(white: 0.40))
            }
        }
    }
}

// MARK: - Summary Metric Row
struct SummaryMetricRow: View {
    let symbol: String
    let color: Color
    let label: String
    let value: String
    let badge: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// Keep old names referenced by other files
typealias MetricListRow = SummaryMetricRow

// MARK: - SpeechDNATimeline (kept for backward compat in InsightsView)
struct SpeechDNATimeline: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    private var strongCount: Int { events.filter { if case .strongMoment = $0.type { return true }; return false }.count }
    private var fillerCount: Int { events.filter { if case .filler       = $0.type { return true }; return false }.count }
    private var hesitCount:  Int { events.filter { if case .hesitation   = $0.type { return true }; return false }.count }
    private var breakCount:  Int { events.filter { if case .flowBreak    = $0.type { return true }; return false }.count }

    var body: some View {
        SpeechDNACard(events: events, duration: duration)
    }
}

struct DNAEventCount: View {
    let color: Color; let count: Int; let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(count) \(label)").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}
