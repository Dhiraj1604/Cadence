// PracticeView.swift
// Cadence — iOS 26 Native · Liquid Glass

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
            // Deep ambient background
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

                // ── TRANSCRIPT (Liquid Glass) ─────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                    Text(coachEngine.transcribedText.isEmpty
                            ? "Start speaking — I'm listening…"
                            : coachEngine.transcribedText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(coachEngine.transcribedText.isEmpty
                            ? Color.white.opacity(0.4) : Color.white.opacity(0.9))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.2), value: coachEngine.transcribedText)
                }
                .frame(height: 68)
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
                            .fill(.ultraThinMaterial)
                            .frame(width: 76, height: 76)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                        Circle()
                            .fill(Color.red.opacity(0.88))
                            .frame(width: 64, height: 64)
                            .shadow(color: .red.opacity(0.40), radius: 16, y: 4)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        // ── iOS 26 Native End Session Sheet ───────────────────
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
            .presentationDetents([.height(260)])
            .presentationBackground(.ultraThinMaterial) // Liquid Glass
            .presentationCornerRadius(32) // Modern Apple hardware curve
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
        case 0: return Color.white.opacity(0.5); default: return .orange
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

// MARK: - End Session Sheet (iOS 26 Liquid Glass)
struct EndSessionSheet: View {
    let duration: TimeInterval
    let onKeepGoing: () -> Void
    let onEndSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 24)

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(LinearGradient(colors: [.mint, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 12)

            Text("Conclude Session")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(sessionSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.bottom, 28)

            HStack(spacing: 16) {
                Button(action: onKeepGoing) {
                    Text("Keep Going")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button(action: onEndSession) {
                    Text("End Session")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.red.opacity(0.3), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var sessionSubtitle: String {
        let d = Int(duration)
        if d < 60 { return "Captured \(d) seconds of speech" }
        return "Captured \(d/60)m \(d%60)s of speech"
    }
}

// MARK: - LiveMetricCard (Liquid Glass)
struct LiveMetricCard: View {
    let icon: String; let label: String
    let value: String; let status: String; let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(status)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
    }
}

// MARK: - Live Flow Strip
struct LiveFlowStrip: View {
    let events: [FlowEvent]; let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                Text("Speech Flow DNA")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text("\(events.count) events")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .frame(height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                    ForEach(events.suffix(60)) { event in
                        let x = duration > 1
                            ? geo.size.width * CGFloat(event.timestamp / duration) : CGFloat(0)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.color)
                            .frame(width: 4, height: 24)
                            .offset(x: min(max(x - 2, 0), geo.size.width - 4), y: 4)
                            .transition(.opacity.animation(.easeIn(duration: 0.25)))
                            .shadow(color: event.color.opacity(0.5), radius: 4)
                    }
                }
            }
            .frame(height: 32)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
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
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1.5).frame(width: 190, height: 190)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(ringColor.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 190, height: 190).rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.1, dampingFraction: 0.8), value: progress)
                .shadow(color: ringColor.opacity(0.4), radius: 8)
            
            Circle().fill(isSpeaking ? Color.mint.opacity(0.15) : Color.white.opacity(0.02))
                .frame(width: 156 + amplitude * 70, height: 156 + amplitude * 70)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: amplitude)
            
            Circle().fill(isSpeaking ? Color.mint.opacity(0.25) : Color.white.opacity(0.04))
                .frame(width: 124 + amplitude * 46, height: 124 + amplitude * 46)
                .animation(.spring(response: 0.2, dampingFraction: 0.55), value: amplitude)
            
            Circle().fill(isSpeaking ? Color.mint : Color.white.opacity(0.1))
                .frame(width: 96 + amplitude * 26, height: 96 + amplitude * 26)
                .shadow(color: isSpeaking ? Color.mint.opacity(0.60) : .clear, radius: 20)
                .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.7), value: amplitude)
            
            VStack(spacing: 4) {
                Text(isSpeaking ? "Listening" : "Paused")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSpeaking ? .black : Color.white.opacity(0.6))
                if wpm > 0 {
                    Text("\(wpm) WPM").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSpeaking ? Color.black.opacity(0.6) : Color.white.opacity(0.4))
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
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tip.color.opacity(0.2)).frame(width: 36, height: 36)
                Image(systemName: tip.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tip.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("COACH").font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(tip.color).tracking(1.5)
                Text(tip.message).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(tip.color.opacity(0.4), lineWidth: 1))
        .shadow(color: tip.color.opacity(0.15), radius: 12, y: 6)
    }
}

// Compatibility stubs
struct WordWatchView: View {
    let entries: [WordFrequencyEntry]; let cogLoad: Bool
    var body: some View { EmptyView() }
}
struct WordRepeatChip: View {
    let entry: WordFrequencyEntry
    var body: some View { EmptyView() }
}
