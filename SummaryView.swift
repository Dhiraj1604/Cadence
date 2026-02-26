// SummaryView.swift

// Summary View — Cadence SSC Edition
// Polished for Apple Swift Student Challenge Distinguished Winner

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var session: SessionManager
    @State private var headerVisible    = false
    @State private var coachingVisible  = false
    @State private var timelineVisible  = false
    @State private var metricsVisible   = false
    @State private var transcriptVisible = false
    @State private var buttonVisible    = false
    @State private var animatedWPM      = 0
    @State private var animatedFillers  = 0
    @State private var animatedEye      = 0
    @State private var animatedRhythm   = 0.0
    @State private var animatedAttention = 0.0

    // A session is "real" only if the user spoke for at least 8 words
    private var hasRealSpeech: Bool {
        session.finalWPM > 0 && session.duration >= 8
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // ── Header ───────────────────────────────────────
                VStack(spacing: 6) {
                    Text("Session Complete")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitleText)
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.4))
                }
                .padding(.top, 54)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : -14)
                .animation(.easeOut(duration: 0.6).delay(0.1), value: headerVisible)

                if !hasRealSpeech {
                    // ── No Speech State ──────────────────────────
                    NoSpeechCard()
                        .padding(.horizontal, 20)
                        .opacity(coachingVisible ? 1 : 0)
                        .offset(y: coachingVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.25), value: coachingVisible)
                } else {
                    // ── Coaching Insight ─────────────────────────
                    CoachingInsightView(
                        wpm: session.finalWPM,
                        fillers: session.finalFillers,
                        attention: session.finalAttentionScore,
                        rhythm: session.finalRhythmStability,
                        events: session.finalFlowEvents
                    )
                    .padding(.horizontal, 20)
                    .opacity(coachingVisible ? 1 : 0)
                    .offset(y: coachingVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.25), value: coachingVisible)

                    // ── Speech DNA Timeline ──────────────────────
                    SpeechTimelineView(
                        events: session.finalFlowEvents,
                        duration: session.duration
                    )
                    .padding(.horizontal, 20)
                    .opacity(timelineVisible ? 1 : 0)
                    .offset(y: timelineVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: timelineVisible)

                    // ── Metrics Grid ─────────────────────────────
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricCard(
                            icon: "speedometer",
                            title: "Pacing",
                            value: animatedWPM == 0 ? "—" : "\(animatedWPM)",
                            unit: "Words / Min",
                            badge: pacingBadge,
                            color: pacingColor
                        )
                        MetricCard(
                            icon: "exclamationmark.bubble",
                            title: "Fillers",
                            value: "\(animatedFillers)",
                            unit: "Total Used",
                            badge: fillerBadge,
                            color: fillerColor
                        )
                        MetricCard(
                            icon: "eye",
                            title: "Eye Contact",
                            value: "\(animatedEye)%",
                            unit: "Of Session",
                            badge: eyeBadge,
                            color: eyeColor
                        )
                        MetricCard(
                            icon: "waveform.path",
                            title: "Rhythm",
                            value: String(format: "%.0f%%", animatedRhythm),
                            unit: "Stability",
                            badge: rhythmBadge,
                            color: rhythmColor
                        )
                    }
                    .padding(.horizontal, 20)
                    .opacity(metricsVisible ? 1 : 0)
                    .offset(y: metricsVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.55), value: metricsVisible)

                    // ── Attention Bar ────────────────────────────
                    AttentionSummaryBar(score: animatedAttention)
                        .padding(.horizontal, 20)
                        .opacity(metricsVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.55), value: metricsVisible)
                }

                // ── Transcript ───────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.4))
                        Text("Your Transcript")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    ScrollView {
                        Text(session.finalTranscript)
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(5)
                    }
                    .frame(height: 100)
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .opacity(transcriptVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.7), value: transcriptVisible)

                // ── Practice Again ───────────────────────────────
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        session.resetSession()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Practice Again")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.mint, Color(red: 0.2, green: 0.85, blue: 0.68)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .mint.opacity(0.3), radius: 20, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 55)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 16)
                .animation(.easeOut(duration: 0.5).delay(0.85), value: buttonVisible)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.05), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear { triggerAnimations() }
    }

    private func triggerAnimations() {
        headerVisible    = true
        coachingVisible  = true
        timelineVisible  = true
        metricsVisible   = true
        transcriptVisible = true
        buttonVisible    = true

        guard hasRealSpeech else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 1.4)) {
                animatedWPM       = session.finalWPM
                animatedFillers   = session.finalFillers
                animatedEye       = session.eyeContactPercentage
                animatedRhythm    = session.finalRhythmStability
                animatedAttention = session.finalAttentionScore
            }
        }
    }

    // MARK: – Computed labels

    private var subtitleText: String {
        guard hasRealSpeech else { return "Session ended — no speech detected" }
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
        case 0: return Color(white: 0.4)
        default: return .orange
        }
    }

    private var fillerBadge: String {
        switch session.finalFillers {
        case 0:    return "Flawless"
        case 1...3: return "Great"
        case 4...7: return "Noticeable"
        default:   return "Needs work"
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
        case 25..<50:  return "Needs work"
        default:       return session.duration < 8 ? "Too short" : "Needs work"
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

// MARK: - No Speech Card
struct NoSpeechCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(Color(white: 0.4))

            VStack(spacing: 6) {
                Text("No speech detected")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text("Make sure microphone permission is granted and speak clearly into the device. Sessions need at least a few seconds of speech to generate analysis.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let badge: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.45))
                Spacer()
            }

            Text(value)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())

            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.35))

            Spacer(minLength: 0)

            // Badge
            Text(badge)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.15))
                .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Attention Summary Bar
struct AttentionSummaryBar: View {
    let score: Double
    private var color: Color {
        switch score {
        case 75...100: return .mint
        case 50..<75:  return .yellow
        case 25..<50:  return .orange
        default:       return .red
        }
    }
    private var label: String {
        switch score {
        case 85...100: return "Excellent retention"
        case 65..<85:  return "Good engagement"
        case 45..<65:  return "Room to improve"
        default:       return "Audience was losing interest"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.4))
                    Text("Audience Attention")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.4))
                }
                Spacer()
                Text(String(format: "%.0f%%", score))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(score / 100), height: 10)
                        .animation(.spring(response: 1.2, dampingFraction: 0.8), value: score)
                }
            }
            .frame(height: 10)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.8))
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
}

// MARK: - Speech DNA Timeline
struct SpeechTimelineView: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    private var strongCount:    Int { events.filter { if case .strongMoment = $0.type { return true }; return false }.count }
    private var fillerCount:    Int { events.filter { if case .filler = $0.type { return true }; return false }.count }
    private var hesitationCount: Int { events.filter { if case .hesitation = $0.type { return true }; return false }.count }
    private var flowBreakCount: Int { events.filter { if case .flowBreak = $0.type { return true }; return false }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Speech Flow DNA")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Every moment of your session, encoded visually")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.38))
            }

            if events.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 56)
                    Text("No events recorded")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.3))
                }
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 56)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.mint.opacity(0.07))
                            .frame(height: 56)
                        ForEach(events) { event in
                            let x = duration > 1
                                ? geo.size.width * CGFloat(event.timestamp / duration)
                                : 0
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(event.color)
                                .frame(width: 5, height: 40)
                                .offset(x: min(max(x - 2.5, 0), geo.size.width - 5))
                        }
                        // Time ticks
                        ForEach([0.25, 0.5, 0.75], id: \.self) { frac in
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1, height: 56)
                                .offset(x: geo.size.width * CGFloat(frac))
                        }
                    }
                }
                .frame(height: 56)
            }

            // Time labels
            HStack {
                Text("0:00").font(.system(size: 10)).foregroundColor(Color(white: 0.3))
                Spacer()
                Text(timeLabel(duration / 2)).font(.system(size: 10)).foregroundColor(Color(white: 0.3))
                Spacer()
                Text(timeLabel(duration)).font(.system(size: 10)).foregroundColor(Color(white: 0.3))
            }

            // Event counts
            HStack(spacing: 16) {
                EventCount(color: .mint,   count: strongCount,    label: "Strong")
                EventCount(color: .orange, count: fillerCount,    label: "Fillers")
                EventCount(color: .yellow, count: hesitationCount, label: "Pauses")
                EventCount(color: .red,    count: flowBreakCount, label: "Breaks")
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

struct EventCount: View {
    let color: Color; let count: Int; let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(count) \(label)")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.42))
        }
    }
}

// MARK: - Coaching Insight Card
struct CoachingInsightView: View {
    let wpm: Int
    let fillers: Int
    let attention: Double
    let rhythm: Double
    let events: [FlowEvent]

    private var insight: (icon: String, color: Color, title: String, message: String) {
        let flowBreaks = events.filter { if case .flowBreak = $0.type { return true }; return false }.count

        // Guard: no real speech
        if wpm == 0 {
            return ("mic.slash", Color(white: 0.4), "No Speech Detected",
                    "We couldn't measure your session. Try speaking louder and closer to the mic.")
        }
        if flowBreaks >= 3 {
            return ("brain.head.profile", .red, "High Cognitive Load Detected",
                    "You lost flow \(flowBreaks) times — your brain was searching for words. Pause silently instead of filling. Silence is powerful.")
        }
        if fillers > 8 {
            return ("exclamationmark.bubble.fill", .orange, "Filler Word Habit",
                    "You used \(fillers) filler words. Replace each one with a 1-second pause — it sounds 10× more confident.")
        }
        if wpm > 175 {
            return ("hare.fill", .yellow, "Speaking Too Fast",
                    "At \(wpm) WPM your audience can't keep up. Aim for 130–155 WPM and slow down on key points.")
        }
        if wpm < 100 {
            return ("tortoise.fill", .yellow, "Pace Is Too Slow",
                    "At \(wpm) WPM you risk losing the room. Target 130–150 WPM for natural, engaging delivery.")
        }
        if attention > 80 && fillers < 4 {
            return ("star.fill", .mint, "Outstanding Delivery",
                    "Audience attention above 80% with fewer than 4 fillers. That's top-tier speaking. Keep it up.")
        }
        return ("chart.line.uptrend.xyaxis", .teal, "Solid Session",
                "Rhythm stability: \(Int(rhythm))%. Every session builds the muscle. You're improving.")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(insight.color.opacity(0.18)).frame(width: 48, height: 48)
                Image(systemName: insight.icon)
                    .font(.system(size: 20))
                    .foregroundColor(insight.color)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("COACH INSIGHT")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(insight.color.opacity(0.8))
                    .tracking(1.8)
                Text(insight.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(insight.message)
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
        }
        .padding(18)
        .background(insight.color.opacity(0.09))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(insight.color.opacity(0.25), lineWidth: 1))
    }
}

// Legacy card kept for compatibility
struct SummaryCard: View {
    let title: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.subheadline).foregroundColor(.white.opacity(0.6))
            Text(value).font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(unit).font(.caption).foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(Color.white.opacity(0.07)).cornerRadius(14)
    }
}
