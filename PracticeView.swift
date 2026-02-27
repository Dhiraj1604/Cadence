// PracticeView.swift
// Cadence — iOS 26 Native · Glass Sheet · SF Symbols

import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var coachEngine = SpeechCoachEngine()
    @StateObject private var cameraManager = CameraManager()

    @State private var liveTip: LiveCoachTip?
    @State private var tipVisible = false
    @State private var lastTipTime: TimeInterval = -30
    @State private var lastFillerCountForTip = 0
    @State private var showEndSheet = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.10, blue: 0.08), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── HEADER ────────────────────────────────────
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Practice Session")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            HStack(spacing: 4) {
                                Circle().fill(.red).frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.red)
                            }
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(.red.opacity(0.14))
                            .clipShape(Capsule())
                        }
                        Text(timeString(from: session.duration))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(LinearGradient(
                                colors: [.mint, Color(red: 0.2, green: 0.9, blue: 0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    CameraMirrorCard(cameraManager: cameraManager)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 14)

                // ── THREE METRIC CARDS ────────────────────────
                HStack(spacing: 10) {
                    LiveMetricCard(icon: "speedometer", label: "WPM",
                        value: coachEngine.wpm == 0 ? "—" : "\(coachEngine.wpm)",
                        status: wpmStatus, color: wpmColor)
                    LiveMetricCard(icon: "exclamationmark.bubble.fill", label: "Fillers",
                        value: "\(coachEngine.fillerWordCount)",
                        status: fillerStatus, color: fillerColor)
                    LiveMetricCard(icon: "waveform.path", label: "Rhythm",
                        value: String(format: "%.0f%%", coachEngine.rhythmStability),
                        status: rhythmStatus, color: rhythmColor)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // ── SPEECH FLOW DNA live strip ─────────────────
                LiveFlowStrip(events: coachEngine.flowEvents, duration: session.duration)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                // ── TRANSCRIPT ────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
                    Text(coachEngine.transcribedText.isEmpty
                            ? "Start speaking — I'm listening…"
                            : coachEngine.transcribedText)
                        .font(.system(size: 13))
                        .foregroundStyle(coachEngine.transcribedText.isEmpty
                            ? Color(white: 0.28) : Color(white: 0.68))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.2), value: coachEngine.transcribedText)
                }
                .frame(height: 62)
                .padding(.horizontal, 20)

                Spacer()

                // ── VISUALIZER ────────────────────────────────
                AdvancedVisualizerView(
                    amplitude: coachEngine.amplitude,
                    isSpeaking: coachEngine.isSpeaking,
                    wpm: coachEngine.wpm
                )

                Spacer()

                // ── LIVE COACH TIP ────────────────────────────
                if tipVisible, let tip = liveTip {
                    LiveCoachBanner(tip: tip)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // ── STOP BUTTON ───────────────────────────────
                Button { showEndSheet = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.88))
                            .frame(width: 68, height: 68)
                            .shadow(color: .red.opacity(0.40), radius: 16, y: 4)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        // ── iOS 26 Glass Sheet ────────────────────────────────
        .sheet(isPresented: $showEndSheet) {
            EndSessionSheet(
                duration: session.duration,
                onKeepGoing: { showEndSheet = false },
                onEndSession: {
                    showEndSheet = false
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
                }
            )
            .presentationDetents([.height(220)])
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(28)
            .environment(\.colorScheme, .dark)
        }
        .onAppear { coachEngine.requestPermissionsAndStart(); cameraManager.start() }
        .onDisappear { coachEngine.stop(); cameraManager.stop() }
        .onChange(of: coachEngine.fillerWordCount) { checkForLiveTip(fillers: $0) }
        .onChange(of: coachEngine.cognitiveLoadWarning) { if $0 { showTip(.cognitiveLoad) } }
        .onChange(of: coachEngine.wpm) { speed in
            if speed > 175 { checkWPMTip(wpm: speed) }
            if speed > 0 && speed < 100 { checkSlowTip(wpm: speed) }
        }
        .onChange(of: cameraManager.isMakingEyeContact) { if !$0 { checkEyeContactTip() } }
    }

    private var wpmStatus: String {
        switch coachEngine.wpm {
        case 120...160: return "Ideal"; case 100..<120: return "Slow"
        case 161..<180: return "Fast"; case 0: return "Waiting"
        default: return coachEngine.wpm > 180 ? "Too fast" : "Too slow"
        }
    }
    private var wpmColor: Color {
        switch coachEngine.wpm {
        case 120...160: return .mint; case 100..<120, 161..<180: return .yellow
        case 0: return Color(white: 0.35); default: return .orange
        }
    }
    private var fillerStatus: String {
        switch coachEngine.fillerWordCount {
        case 0: return "Flawless"; case 1...3: return "Good"
        case 4...7: return "Notice"; default: return "High"
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

    private func checkForLiveTip(fillers: Int) {
        guard session.duration - lastTipTime > 20 else { return }
        if fillers - lastFillerCountForTip >= 3 {
            showTip(.fillers(count: fillers)); lastFillerCountForTip = fillers
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
        lastTipTime = session.duration; liveTip = tip
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { tipVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.4)) { tipVisible = false }
        }
    }
    private func timeString(from t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - End Session Sheet (iOS 26 Glass)
struct EndSessionSheet: View {
    let duration: TimeInterval
    let onKeepGoing: () -> Void
    let onEndSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 18)

            Image(systemName: "stop.circle")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.red)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 8)

            Text("End Session?")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.primary)
            Text(sessionSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)

            HStack(spacing: 12) {
                Button(action: onKeepGoing) {
                    Label("Keep Going", systemImage: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.mint)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(.mint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.mint.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: onEndSession) {
                    Label("End Session", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(.red.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private var sessionSubtitle: String {
        let d = Int(duration)
        if d < 60 { return "You've been speaking for \(d)s" }
        return "You've been speaking for \(d/60)m \(d%60)s"
    }
}

// MARK: - LiveMetricCard
struct LiveMetricCard: View {
    let icon: String; let label: String
    let value: String; let status: String; let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color.opacity(0.8))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.40))
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(status)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(color.opacity(0.14), lineWidth: 1))
    }
}

// MARK: - Live Flow Strip
struct LiveFlowStrip: View {
    let events: [FlowEvent]; let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.34))
                Text("Speech Flow DNA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.34))
                Spacer()
                Text("\(events.count) events")
                    .font(.system(size: 10)).foregroundStyle(Color(white: 0.24))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.04)).frame(height: 28)
                    ForEach(events.suffix(60)) { event in
                        let x = duration > 1
                            ? geo.size.width * CGFloat(event.timestamp / duration) : CGFloat(0)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.color)
                            .frame(width: 4, height: 20)
                            .offset(x: min(max(x - 2, 0), geo.size.width - 4), y: 4)
                            .transition(.opacity.animation(.easeIn(duration: 0.25)))
                    }
                }
            }
            .frame(height: 28)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Visualizer
struct AdvancedVisualizerView: View {
    let amplitude: CGFloat; let isSpeaking: Bool; let wpm: Int

    private var ringColor: Color {
        switch wpm {
        case 120...160: return .mint; case 100..<120, 161..<180: return .yellow
        case 0: return Color.white.opacity(0.15); default: return .orange
        }
    }
    private var progress: Double {
        guard wpm > 0 else { return 0 }
        return (min(max(Double(wpm), 60), 220) - 60) / 160.0
    }
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.05), lineWidth: 2).frame(width: 180, height: 180)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(ringColor.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 180, height: 180).rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.1, dampingFraction: 0.8), value: progress)
            Circle().fill(isSpeaking ? Color.mint.opacity(0.10) : Color(white: 0.05))
                .frame(width: 148 + amplitude * 70, height: 148 + amplitude * 70)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: amplitude)
            Circle().fill(isSpeaking ? Color.mint.opacity(0.20) : Color(white: 0.08))
                .frame(width: 118 + amplitude * 46, height: 118 + amplitude * 46)
                .animation(.spring(response: 0.2, dampingFraction: 0.55), value: amplitude)
            Circle().fill(isSpeaking ? Color.mint : Color(white: 0.18))
                .frame(width: 92 + amplitude * 26, height: 92 + amplitude * 26)
                .shadow(color: isSpeaking ? Color.mint.opacity(0.50) : .clear, radius: 14)
                .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.7), value: amplitude)
            VStack(spacing: 3) {
                Text(isSpeaking ? "Listening" : "Paused")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSpeaking ? .black : Color(white: 0.42))
                if wpm > 0 {
                    Text("\(wpm) WPM").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSpeaking ? Color.black.opacity(0.55) : Color(white: 0.32))
                }
            }
        }
    }
}

// MARK: - Live Coach Tip
enum LiveCoachTip {
    case fillers(count: Int), cognitiveLoad, tooFast(wpm: Int), tooSlow(wpm: Int), eyeContact
    var icon: String {
        switch self {
        case .fillers: return "exclamationmark.bubble.fill"
        case .cognitiveLoad: return "brain.head.profile"
        case .tooFast: return "hare.fill"; case .tooSlow: return "tortoise.fill"
        case .eyeContact: return "eye.slash.fill"
        }
    }
    var color: Color {
        switch self {
        case .fillers: return .orange; case .cognitiveLoad: return .red
        case .tooFast, .tooSlow: return .yellow; case .eyeContact: return .cyan
        }
    }
    var message: String {
        switch self {
        case .fillers: return "Replace fillers with a deliberate 1-second pause"
        case .cognitiveLoad: return "Breathe — let your thoughts form first, then speak"
        case .tooFast(let w): return "Slow down — at \(w) WPM your audience can't keep up"
        case .tooSlow: return "Bring more energy — aim for 130–155 WPM"
        case .eyeContact: return "Look up — eye contact builds trust immediately"
        }
    }
}

struct LiveCoachBanner: View {
    let tip: LiveCoachTip
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tip.color).symbolRenderingMode(.hierarchical).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("COACH").font(.system(size: 9, weight: .black))
                    .foregroundStyle(tip.color).tracking(1.5)
                Text(tip.message).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(tip.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(tip.color.opacity(0.25), lineWidth: 1))
    }
}

// Compatibility stubs (engine still references these)
struct WordWatchView: View {
    let entries: [WordFrequencyEntry]; let cogLoad: Bool
    var body: some View { EmptyView() }
}
struct WordRepeatChip: View {
    let entry: WordFrequencyEntry
    var body: some View { EmptyView() }
}
