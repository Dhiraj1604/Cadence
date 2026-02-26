// Practise View

// Practise View — SSC Edition

import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var coachEngine = SpeechCoachEngine()
    @StateObject private var cameraManager = CameraManager()

    // Mid-session coaching tip state
    @State private var liveTip: LiveCoachTip? = nil
    @State private var tipVisible = false
    @State private var lastTipTime: TimeInterval = -30
    @State private var lastFillerCountForTip = 0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.05), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: ── Top Bar ────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Practice Session")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 8) {
                            MetricBadge(
                                icon: "speedometer",
                                text: wpmLabel,
                                color: wpmColor
                            )
                            MetricBadge(
                                icon: "exclamationmark.bubble",
                                text: "\(coachEngine.fillerWordCount)",
                                color: coachEngine.fillerWordCount > 5 ? .red : .orange
                            )
                            MetricBadge(
                                icon: cameraManager.isMakingEyeContact ? "eye.fill" : "eye.slash.fill",
                                text: cameraManager.isMakingEyeContact ? "Eye ✓" : "Look up",
                                color: cameraManager.isMakingEyeContact ? .mint : .red
                            )
                        }
                    }
                    Spacer()
                    // Timer
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(timeString(from: session.duration))
                            .font(.system(size: 24, design: .monospaced).bold())
                            .foregroundColor(.mint)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 16)

                // MARK: ── Attention Meter ─────────────────────────
                AttentionMeterView(
                    score: coachEngine.attentionScore,
                    cognitiveLoad: coachEngine.cognitiveLoadWarning
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

                // MARK: ── Live Flow Strip ─────────────────────────
                LiveFlowStrip(
                    events: coachEngine.flowEvents,
                    duration: session.duration
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                // Rhythm row
                HStack {
                    Image(systemName: "metronome.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                    Text("Rhythm Stability")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                    Text(String(format: "%.0f%%", coachEngine.rhythmStability))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(coachEngine.rhythmStability > 70 ? .mint : .orange)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

                // MARK: ── Live Transcript ─────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                    Text(coachEngine.transcribedText.isEmpty
                         ? "Start speaking — I'm listening..."
                         : coachEngine.transcribedText)
                        .font(.system(size: 14))
                        .foregroundColor(coachEngine.transcribedText.isEmpty
                                         ? Color(white: 0.35)
                                         : Color(white: 0.72))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.3), value: coachEngine.transcribedText)
                }
                .frame(height: 68)
                .padding(.horizontal, 24)

                Spacer()

                // MARK: ── Central Visualizer ──────────────────────
                AdvancedVisualizerView(
                    amplitude: coachEngine.amplitude,
                    isSpeaking: coachEngine.isSpeaking,
                    wpm: coachEngine.wpm
                )

                Spacer()

                // MARK: ── Mid-session Live Tip ───────────────────
                if tipVisible, let tip = liveTip {
                    LiveCoachBanner(tip: tip)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // MARK: ── Stop Button ─────────────────────────────
                Button {
                    coachEngine.stop()
                    cameraManager.stop()
                    session.endSession(
                        wpm: coachEngine.wpm,
                        fillers: coachEngine.fillerWordCount,
                        transcript: coachEngine.transcribedText,
                        eyeContactDuration: cameraManager.eyeContactDuration,
                        flowEvents: coachEngine.flowEvents,
                        rhythmStability: coachEngine.rhythmStability,
                        attentionScore: coachEngine.attentionScore
                    )
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: 76, height: 76)
                            .shadow(color: .red.opacity(0.5), radius: 20)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 50)
            }

            // Live tip trigger logic via onChange
        }
        .onAppear {
            coachEngine.requestPermissionsAndStart()
            cameraManager.start()
        }
        .onDisappear {
            coachEngine.stop()
            cameraManager.stop()
        }
        .onChange(of: coachEngine.fillerWordCount) { count in
            checkForLiveTip(fillers: count)
        }
        .onChange(of: coachEngine.cognitiveLoadWarning) { isOverloaded in
            if isOverloaded { showTip(.cognitiveLoad) }
        }
        .onChange(of: coachEngine.wpm) { speed in
            if speed > 175 { checkWPMTip(wpm: speed) }
            if speed > 0 && speed < 100 { checkSlowTip(wpm: speed) }
        }
        .onChange(of: cameraManager.isMakingEyeContact) { looking in
            if !looking { checkEyeContactTip() }
        }
    }

    // MARK: – Live tip logic
    private func checkForLiveTip(fillers: Int) {
        guard session.duration - lastTipTime > 20 else { return }
        let newFillers = fillers - lastFillerCountForTip
        if newFillers >= 3 {
            showTip(.fillers(count: fillers))
            lastFillerCountForTip = fillers
        }
    }

    private func checkWPMTip(wpm: Int) {
        guard session.duration - lastTipTime > 25 else { return }
        showTip(.tooFast(wpm: wpm))
    }

    private func checkSlowTip(wpm: Int) {
        guard session.duration - lastTipTime > 25 else { return }
        showTip(.tooSlow(wpm: wpm))
    }

    private func checkEyeContactTip() {
        guard session.duration - lastTipTime > 30, session.duration > 5 else { return }
        showTip(.eyeContact)
    }

    private func showTip(_ tip: LiveCoachTip) {
        guard !tipVisible else { return }
        lastTipTime = session.duration
        liveTip = tip
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            tipVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.4)) { tipVisible = false }
        }
    }

    private var wpmLabel: String {
        coachEngine.wpm == 0 ? "— WPM" : "\(coachEngine.wpm) WPM"
    }

    private var wpmColor: Color {
        switch coachEngine.wpm {
        case 120...160: return .mint
        case 100..<120, 160..<180: return .yellow
        case 0: return .gray
        default: return .orange
        }
    }

    private func timeString(from t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Live Coach Tip Model
enum LiveCoachTip {
    case fillers(count: Int)
    case cognitiveLoad
    case tooFast(wpm: Int)
    case tooSlow(wpm: Int)
    case eyeContact

    var icon: String {
        switch self {
        case .fillers: return "exclamationmark.bubble.fill"
        case .cognitiveLoad: return "brain.head.profile"
        case .tooFast: return "hare.fill"
        case .tooSlow: return "tortoise.fill"
        case .eyeContact: return "eye.slash.fill"
        }
    }

    var color: Color {
        switch self {
        case .fillers: return .orange
        case .cognitiveLoad: return .red
        case .tooFast: return .yellow
        case .tooSlow: return .yellow
        case .eyeContact: return .cyan
        }
    }

    var message: String {
        switch self {
        case .fillers(let n): return "Try replacing fillers with a 1‑second silence — it sounds more confident"
        case .cognitiveLoad: return "You're losing flow. Breathe, slow down, let thoughts form first"
        case .tooFast(let w): return "Slow down — at \(w) WPM your audience is falling behind"
        case .tooSlow(let w): return "Bring more energy — aim for 130–155 WPM for natural delivery"
        case .eyeContact: return "Look up from your notes — eye contact builds trust immediately"
        }
    }
}

// MARK: - Live Coach Banner
struct LiveCoachBanner: View {
    let tip: LiveCoachTip

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tip.color.opacity(0.2))
                    .frame(width: 38, height: 38)
                Image(systemName: tip.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tip.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("COACH")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(tip.color)
                    .tracking(1.5)
                Text(tip.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(tip.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tip.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Advanced Visualizer
struct AdvancedVisualizerView: View {
    let amplitude: CGFloat
    let isSpeaking: Bool
    let wpm: Int

    private var wpmRingColor: Color {
        switch wpm {
        case 120...160: return .mint
        case 100..<120, 160..<180: return .yellow
        case 0: return .gray.opacity(0.3)
        default: return .orange
        }
    }

    private var wpmProgress: Double {
        guard wpm > 0 else { return 0 }
        // 130-150 is ideal → maps to center of arc
        let clamped = min(max(Double(wpm), 60), 220)
        return (clamped - 60) / 160.0
    }

    var body: some View {
        ZStack {
            // Outer WPM ring
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
                .frame(width: 200, height: 200)

            Circle()
                .trim(from: 0, to: CGFloat(wpmProgress))
                .stroke(
                    wpmRingColor.opacity(0.7),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1, dampingFraction: 0.8), value: wpmProgress)

            // Pulse rings
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.12) : Color.gray.opacity(0.06))
                .frame(width: 160 + amplitude * 80, height: 160 + amplitude * 80)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: amplitude)

            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.22) : Color.gray.opacity(0.1))
                .frame(width: 128 + amplitude * 55, height: 128 + amplitude * 55)
                .animation(.spring(response: 0.2, dampingFraction: 0.55), value: amplitude)

            Circle()
                .fill(isSpeaking ? Color.mint : Color(white: 0.2))
                .frame(width: 100 + amplitude * 30, height: 100 + amplitude * 30)
                .shadow(color: isSpeaking ? .mint.opacity(0.6) : .clear, radius: 18)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.7), value: amplitude)

            VStack(spacing: 4) {
                Text(isSpeaking ? "Listening" : "Paused")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSpeaking ? .black : Color(white: 0.5))
                if wpm > 0 {
                    Text("\(wpm) WPM")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSpeaking ? .black.opacity(0.6) : Color(white: 0.35))
                }
            }
        }
    }
}

// MARK: - Audience Attention Meter
struct AttentionMeterView: View {
    let score: Double
    let cognitiveLoad: Bool

    private var color: Color {
        switch score {
        case 75...100: return .mint
        case 50..<75:  return .yellow
        case 25..<50:  return .orange
        default:       return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Audience Attention")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                if cognitiveLoad {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("Lost Flow")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.red)
                } else {
                    Text(String(format: "%.0f%%", score))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 10)

                    // Segmented look
                    HStack(spacing: 2) {
                        ForEach(0..<20, id: \.self) { i in
                            let segFilled = Double(i) / 20.0 < score / 100.0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(segFilled ? color : Color.white.opacity(0.04))
                                .frame(width: (geo.size.width - 38) / 20, height: 10)
                        }
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: score)
                }
            }
            .frame(height: 10)

            // Score labels
            HStack {
                Text("Distracted")
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.3))
                Spacer()
                Text("Engaged")
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.3))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(cognitiveLoad ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Live Flow Strip
struct LiveFlowStrip: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Text("Speech Flow")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("\(events.count) events")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.28))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 32)

                    ForEach(events.suffix(50)) { event in
                        let x = duration > 1
                            ? geo.size.width * CGFloat(event.timestamp / duration)
                            : 0
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.color)
                                .frame(width: 4, height: 24)
                        }
                        .offset(x: min(max(x - 2, 0), geo.size.width - 4))
                        .transition(.opacity.animation(.easeIn(duration: 0.3)))
                    }
                }
            }
            .frame(height: 32)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Metric Badge
struct MetricBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.18))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}
