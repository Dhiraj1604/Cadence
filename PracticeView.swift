// Practise View

// PracticeView.swift
// Cadence — SSC Edition

import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var coachEngine = SpeechCoachEngine()
    @StateObject private var cameraManager = CameraManager()

    @State private var liveTip: LiveCoachTip? = nil
    @State private var tipVisible = false
    @State private var lastTipTime: TimeInterval = -30
    @State private var lastFillerCountForTip = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.06), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── HEADER ────────────────────────────────────
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text("Practice Session")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("● LIVE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.red)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.18))
                                .cornerRadius(6)
                        }
                        Text(timeString(from: session.duration))
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.mint, Color(red: 0.2, green: 0.9, blue: 0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    CameraMirrorCard(cameraManager: cameraManager)
                }
                .padding(.horizontal, 20)
                .padding(.top, 54)
                .padding(.bottom, 16)

                // ── THREE BIG METRIC CARDS ────────────────────
                HStack(spacing: 10) {
                    LiveMetricCard(
                        icon: "speedometer",
                        label: "WPM",
                        value: coachEngine.wpm == 0 ? "—" : "\(coachEngine.wpm)",
                        status: wpmStatus,
                        color: wpmColor
                    )
                    LiveMetricCard(
                        icon: "exclamationmark.bubble.fill",
                        label: "Fillers",
                        value: "\(coachEngine.fillerWordCount)",
                        status: fillerStatus,
                        color: fillerColor
                    )
                    LiveMetricCard(
                        icon: "waveform.path",
                        label: "Rhythm",
                        value: String(format: "%.0f%%", coachEngine.rhythmStability),
                        status: rhythmStatus,
                        color: rhythmColor
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // ── WORD WATCH ────────────────────────────────
                WordWatchView(
                    entries: coachEngine.topRepeatedWords,
                    cogLoad: coachEngine.cognitiveLoadWarning
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // ── SPEECH FLOW STRIP ─────────────────────────
                LiveFlowStrip(
                    events: coachEngine.flowEvents,
                    duration: session.duration
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // ── TRANSCRIPT ────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                    Text(
                        coachEngine.transcribedText.isEmpty
                            ? "Start speaking — I'm listening…"
                            : coachEngine.transcribedText
                    )
                    .font(.system(size: 14))
                    .foregroundColor(
                        coachEngine.transcribedText.isEmpty
                            ? Color(white: 0.32) : Color(white: 0.72)
                    )
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: coachEngine.transcribedText)
                }
                .frame(height: 64)
                .padding(.horizontal, 20)

                Spacer()

                // ── VISUALIZER ────────────────────────────────
                AdvancedVisualizerView(
                    amplitude: coachEngine.amplitude,
                    isSpeaking: coachEngine.isSpeaking,
                    wpm: coachEngine.wpm
                )

                Spacer()

                // ── LIVE TIP ──────────────────────────────────
                if tipVisible, let tip = liveTip {
                    LiveCoachBanner(tip: tip)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // ── STOP BUTTON ───────────────────────────────
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
                        attentionScore: 100.0
                    )
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.92))
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.red.opacity(0.45), radius: 18, y: 4)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 50)
            }
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
        .onChange(of: coachEngine.cognitiveLoadWarning) { overloaded in
            if overloaded { showTip(.cognitiveLoad) }
        }
        .onChange(of: coachEngine.wpm) { speed in
            if speed > 175 { checkWPMTip(wpm: speed) }
            if speed > 0 && speed < 100 { checkSlowTip(wpm: speed) }
        }
        .onChange(of: cameraManager.isMakingEyeContact) { looking in
            if !looking { checkEyeContactTip() }
        }
    }

    // MARK: – Computed status

    private var wpmStatus: String {
        switch coachEngine.wpm {
        case 120...160: return "Ideal"
        case 100..<120: return "Slow"
        case 161..<180: return "Fast"
        case 0:         return "Waiting"
        default:        return coachEngine.wpm > 180 ? "Too fast" : "Too slow"
        }
    }
    private var wpmColor: Color {
        switch coachEngine.wpm {
        case 120...160: return .mint
        case 100..<120, 161..<180: return .yellow
        case 0: return Color(white: 0.38)
        default: return .orange
        }
    }
    private var fillerStatus: String {
        switch coachEngine.fillerWordCount {
        case 0:      return "Flawless"
        case 1...3:  return "Good"
        case 4...7:  return "Notice"
        default:     return "High"
        }
    }
    private var fillerColor: Color {
        coachEngine.fillerWordCount == 0 ? .mint
            : coachEngine.fillerWordCount < 5 ? .orange : .red
    }
    private var rhythmStatus: String {
        coachEngine.rhythmStability > 75 ? "Consistent"
            : coachEngine.rhythmStability > 50 ? "Decent" : "Choppy"
    }
    private var rhythmColor: Color {
        coachEngine.rhythmStability > 75 ? .mint
            : coachEngine.rhythmStability > 50 ? .yellow : .orange
    }

    // MARK: – Live tips

    private func checkForLiveTip(fillers: Int) {
        guard session.duration - lastTipTime > 20 else { return }
        if fillers - lastFillerCountForTip >= 3 {
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
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { tipVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.4)) { tipVisible = false }
        }
    }
    private func timeString(from t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - LiveMetricCard

struct LiveMetricCard: View {
    let icon: String
    let label: String
    let value: String
    let status: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color.opacity(0.8))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.42))
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(status)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - WordWatchView

struct WordWatchView: View {
    let entries: [WordFrequencyEntry]
    let cogLoad: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: cogLoad ? "exclamationmark.triangle.fill" : "repeat.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(cogLoad ? .red : Color(white: 0.38))
                Text(cogLoad ? "Slow down — cognitive overload" : "Word Watch")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(cogLoad ? .red.opacity(0.9) : Color(white: 0.40))
                Spacer()
                if !entries.isEmpty {
                    Text("avoid repeating")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.28))
                }
            }
            if entries.isEmpty {
                Text("No repeated words yet")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.30))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entries) { entry in
                            WordRepeatChip(entry: entry)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(cogLoad ? Color.red.opacity(0.07) : Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cogLoad ? Color.red.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: cogLoad)
    }
}

struct WordRepeatChip: View {
    let entry: WordFrequencyEntry
    private var color: Color {
        entry.count >= 6 ? .red : entry.count >= 4 ? .orange : .yellow
    }
    var body: some View {
        HStack(spacing: 4) {
            Text(entry.word)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text("×\(entry.count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .cornerRadius(20)
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - LiveFlowStrip

struct LiveFlowStrip: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.38))
                Text("Speech Flow")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.38))
                Spacer()
                Text("\(events.count) events")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.26))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 30)
                    ForEach(events.suffix(50)) { event in
                        let x: CGFloat = duration > 1
                            ? geo.size.width * CGFloat(event.timestamp / duration)
                            : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.color)
                            .frame(width: 4, height: 22)
                            .offset(
                                x: min(max(x - 2, 0), geo.size.width - 4),
                                y: (30 - 22) / 2
                            )
                            .transition(.opacity.animation(.easeIn(duration: 0.3)))
                    }
                }
            }
            .frame(height: 30)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - AdvancedVisualizerView

struct AdvancedVisualizerView: View {
    let amplitude: CGFloat
    let isSpeaking: Bool
    let wpm: Int

    private var ringColor: Color {
        switch wpm {
        case 120...160: return .mint
        case 100..<120, 161..<180: return .yellow
        case 0: return Color.white.opacity(0.15)
        default: return .orange
        }
    }
    private var progress: Double {
        guard wpm > 0 else { return 0 }
        return (min(max(Double(wpm), 60), 220) - 60) / 160.0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
                .frame(width: 190, height: 190)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(ringColor.opacity(0.75),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.1, dampingFraction: 0.8), value: progress)

            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.10) : Color(white: 0.05))
                .frame(width: 155 + amplitude * 75, height: 155 + amplitude * 75)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: amplitude)
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.20) : Color(white: 0.08))
                .frame(width: 124 + amplitude * 50, height: 124 + amplitude * 50)
                .animation(.spring(response: 0.2, dampingFraction: 0.55), value: amplitude)
            Circle()
                .fill(isSpeaking ? Color.mint : Color(white: 0.18))
                .frame(width: 96 + amplitude * 28, height: 96 + amplitude * 28)
                .shadow(color: isSpeaking ? Color.mint.opacity(0.55) : .clear, radius: 16)
                .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.7), value: amplitude)

            VStack(spacing: 4) {
                Text(isSpeaking ? "Listening" : "Paused")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSpeaking ? .black : Color(white: 0.45))
                if wpm > 0 {
                    Text("\(wpm) WPM")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSpeaking ? Color.black.opacity(0.6) : Color(white: 0.35))
                }
            }
        }
    }
}

// MARK: - LiveCoachTip

enum LiveCoachTip {
    case fillers(count: Int)
    case cognitiveLoad
    case tooFast(wpm: Int)
    case tooSlow(wpm: Int)
    case eyeContact

    var icon: String {
        switch self {
        case .fillers:      return "exclamationmark.bubble.fill"
        case .cognitiveLoad: return "brain.head.profile"
        case .tooFast:      return "hare.fill"
        case .tooSlow:      return "tortoise.fill"
        case .eyeContact:   return "eye.slash.fill"
        }
    }
    var color: Color {
        switch self {
        case .fillers:           return .orange
        case .cognitiveLoad:     return .red
        case .tooFast, .tooSlow: return .yellow
        case .eyeContact:        return .cyan
        }
    }
    var message: String {
        switch self {
        case .fillers:        return "Replace fillers with a 1‑second pause — sounds more confident"
        case .cognitiveLoad:  return "Breathe. Let your thoughts form first, then speak"
        case .tooFast(let w): return "Slow down — at \(w) WPM your audience can't keep up"
        case .tooSlow(let w): return "Bring more energy — aim for 130–155 WPM"
        case .eyeContact:     return "Look up — eye contact builds trust immediately"
        }
    }
}

struct LiveCoachBanner: View {
    let tip: LiveCoachTip
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tip.color.opacity(0.18))
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
                .fill(tip.color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tip.color.opacity(0.28), lineWidth: 1)
                )
        )
    }
}
