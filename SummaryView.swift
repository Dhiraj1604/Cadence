// SummaryView.swift
// Cadence — iOS 26 Native
// SF Pro + SF Symbols throughout, NavigationStack, List styling like Health app

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var session: SessionManager
    @State private var animatedWPM = 0
    @State private var animatedFillers = 0
    @State private var animatedEye = 0
    @State private var animatedRhythm = 0.0
    @State private var animatedScore = 0.0

    private var hasRealSpeech: Bool {
        session.finalWPM > 0 && session.duration >= 8
    }

    private var overallScore: Int {
        guard hasRealSpeech else { return 0 }
        var score = 50
        if session.finalWPM >= 120 && session.finalWPM <= 160 { score += 20 }
        else if (session.finalWPM >= 100 && session.finalWPM < 120) || (session.finalWPM > 160 && session.finalWPM <= 180) { score += 10 }
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
        let breaks = session.finalFlowEvents.filter { if case .flowBreak = $0.type { return true }; return false }.count
        if !hasRealSpeech {
            return ("mic.slash.fill", .secondary, "No Speech Detected",
                    "We couldn't measure your session. Speak clearly into the device and make sure microphone permission is granted.")
        }
        if breaks >= 3 {
            return ("brain.head.profile", .red, "High Cognitive Load",
                    "You lost flow \(breaks) times — your brain was searching for words. Pause silently instead of filling. Silence sounds confident.")
        }
        if session.finalFillers > 8 {
            return ("exclamationmark.bubble.fill", .orange, "Filler Word Habit",
                    "You used \(session.finalFillers) filler words. Replace each one with a deliberate 1-second pause — it sounds 10× more confident.")
        }
        if session.finalWPM > 175 {
            return ("hare.fill", .yellow, "Speaking Too Fast",
                    "At \(session.finalWPM) WPM your audience struggles to keep up. Aim for 130–155 WPM and slow down on key points.")
        }
        if session.finalWPM < 100 && session.finalWPM > 0 {
            return ("tortoise.fill", .yellow, "Pace Too Slow",
                    "At \(session.finalWPM) WPM you risk losing the room. Target 130–150 WPM for natural, engaging delivery.")
        }
        if overallScore >= 80 {
            return ("star.fill", .mint, "Outstanding Session",
                    "Strong pacing, minimal fillers, great eye contact. You're building real speaking confidence — keep this up.")
        }
        return ("chart.line.uptrend.xyaxis", .cyan, "Good Progress",
                "Rhythm stability at \(Int(session.finalRhythmStability))%. Every session builds the muscle. You're improving.")
    }

    var body: some View {
        NavigationStack {
            List {

                // ── SCORE RING ────────────────────────────────
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(Color(uiColor: .systemFill), lineWidth: 12)
                                    .frame(width: 150, height: 150)

                                Circle()
                                    .trim(from: 0, to: CGFloat(animatedScore / 100))
                                    .stroke(
                                        scoreColor,
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 1.5, dampingFraction: 0.75).delay(0.3), value: animatedScore)

                                VStack(spacing: 4) {
                                    Text("\(Int(animatedScore))")
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .foregroundStyle(scoreColor)
                                        .contentTransition(.numericText())
                                    Text("Score")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Duration subtitle
                            Text(subtitleText)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }

                // ── COACH INSIGHT ─────────────────────────────
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(coachInsight.color.opacity(0.15))
                                .frame(width: 46, height: 46)
                            Image(systemName: coachInsight.symbol)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(coachInsight.color)
                                .symbolRenderingMode(.hierarchical)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(coachInsight.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(coachInsight.body)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Label("Coach Insight", systemImage: "person.fill.checkmark")
                        .symbolRenderingMode(.hierarchical)
                }

                // ── METRICS ───────────────────────────────────
                if hasRealSpeech {
                    Section {
                        MetricListRow(
                            symbol: "speedometer",
                            label: "Pacing",
                            value: animatedWPM == 0 ? "—" : "\(animatedWPM) WPM",
                            badge: pacingBadge,
                            color: pacingColor
                        )
                        MetricListRow(
                            symbol: "exclamationmark.bubble.fill",
                            label: "Filler Words",
                            value: "\(animatedFillers)",
                            badge: fillerBadge,
                            color: fillerColor
                        )
                        MetricListRow(
                            symbol: "eye.fill",
                            label: "Eye Contact",
                            value: "\(animatedEye)%",
                            badge: eyeBadge,
                            color: eyeColor
                        )
                        MetricListRow(
                            symbol: "waveform.path",
                            label: "Rhythm",
                            value: String(format: "%.0f%%", animatedRhythm),
                            badge: rhythmBadge,
                            color: rhythmColor
                        )
                    } header: {
                        Label("Metrics", systemImage: "chart.bar.fill")
                            .symbolRenderingMode(.hierarchical)
                    }

                    // ── SPEECH DNA TIMELINE ───────────────────
                    Section {
                        SpeechDNATimeline(
                            events: session.finalFlowEvents,
                            duration: session.duration
                        )
                        .padding(.vertical, 8)
                    } header: {
                        Label("Speech Flow DNA", systemImage: "waveform.path.ecg")
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                // ── TRANSCRIPT ────────────────────────────────
                Section {
                    Text(session.finalTranscript)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                } header: {
                    Label("Transcript", systemImage: "text.quote")
                        .symbolRenderingMode(.hierarchical)
                }

                // ── PRACTICE AGAIN ────────────────────────────
                Section {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            session.resetSession()
                        }
                    } label: {
                        Label("Practice Again", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.mint, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            guard hasRealSpeech else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 1.2)) {
                    animatedWPM     = session.finalWPM
                    animatedFillers = session.finalFillers
                    animatedEye     = session.eyeContactPercentage
                    animatedRhythm  = session.finalRhythmStability
                    animatedScore   = Double(overallScore)
                }
            }
        }
    }

    // MARK: - Computed labels
    private var subtitleText: String {
        guard hasRealSpeech else { return "No speech detected" }
        let d = Int(session.duration)
        let dur = d < 60 ? "\(d)s" : "\(d/60)m \(d%60)s"
        return "\(dur) · \(session.finalWPM) WPM · \(session.finalFillers) fillers"
    }

    private var pacingBadge: String {
        switch session.finalWPM {
        case 120...160: return "Ideal"; case 100..<120: return "Slightly slow"
        case 160..<180: return "Slightly fast"; case 0: return "No speech"
        default: return session.finalWPM > 180 ? "Too fast" : "Too slow"
        }
    }
    private var pacingColor: Color {
        switch session.finalWPM {
        case 120...160: return .mint; case 100..<120, 160..<180: return .yellow
        case 0: return .secondary; default: return .orange
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

// MARK: - Metric List Row
struct MetricListRow: View {
    let symbol: String
    let label: String
    let value: String
    let badge: String
    let color: Color

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
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Speech DNA Timeline
struct SpeechDNATimeline: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    private var strongCount: Int    { events.filter { if case .strongMoment = $0.type { return true }; return false }.count }
    private var fillerCount: Int    { events.filter { if case .filler = $0.type { return true }; return false }.count }
    private var hesitCount: Int     { events.filter { if case .hesitation = $0.type { return true }; return false }.count }
    private var breakCount: Int     { events.filter { if case .flowBreak = $0.type { return true }; return false }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if events.isEmpty {
                Text("No flow events recorded")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(height: 48)

                        ForEach(events) { event in
                            let x = duration > 1 ? geo.size.width * CGFloat(event.timestamp / duration) : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.color)
                                .frame(width: 4, height: 34)
                                .offset(x: min(max(x - 2, 0), geo.size.width - 4),
                                        y: (48 - 34) / 2)
                        }
                    }
                }
                .frame(height: 48)

                // Time labels
                HStack {
                    Text("0:00").font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    Text(timeLabel(duration)).font(.system(size: 11)).foregroundStyle(.tertiary)
                }

                // Event counts
                HStack(spacing: 18) {
                    DNAEventCount(color: .mint,   count: strongCount, label: "Strong")
                    DNAEventCount(color: .orange, count: fillerCount, label: "Fillers")
                    DNAEventCount(color: .yellow, count: hesitCount,  label: "Pauses")
                    DNAEventCount(color: .red,    count: breakCount,  label: "Breaks")
                }
            }
        }
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t)/60, Int(t)%60)
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
