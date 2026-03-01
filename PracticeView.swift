// PracticeView.swift
// Cadence — Apple Native Redesign

import SwiftUI

// MARK: - Live Coach Tip
enum LiveCoachTip {
    case fillers(count: Int)
    case cognitiveLoad
    case tooFast(wpm: Int)
    case tooSlow(wpm: Int)
    case eyeContact

    var icon: String {
        switch self {
        case .fillers:       return "exclamationmark.bubble.fill"
        case .cognitiveLoad: return "brain.head.profile"
        case .tooFast:       return "hare.fill"
        case .tooSlow:       return "tortoise.fill"
        case .eyeContact:    return "eye.slash.fill"
        }
    }
    var color: Color {
        switch self {
        case .fillers:           return Color.cadenceWarn
        case .cognitiveLoad:     return Color.cadenceBad
        case .tooFast, .tooSlow: return Color.cadenceNeutral
        case .eyeContact:        return Color.cyan
        }
    }
    var message: String {
        switch self {
        case .fillers:          return "Replace fillers with a deliberate 1-second pause"
        case .cognitiveLoad:    return "Breathe — let your thoughts form first, then speak"
        case .tooFast(let w):   return "Slow down — at \(w) WPM your audience can't keep up"
        case .tooSlow:          return "Bring more energy — aim for 130–150 WPM"
        case .eyeContact:       return "Look up — eye contact builds trust immediately"
        }
    }
}

// MARK: - Coach Banner
struct NativeCoachBanner: View {
    let tip: LiveCoachTip
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.title3)
                .foregroundStyle(tip.color)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Coach")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(tip.color)
                    .textCase(.uppercase)
                Text(tip.message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tip.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - End Session Sheet
struct EndSessionSheet: View {
    let duration: TimeInterval
    let onKeepGoing: () -> Void
    let onEndSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.separator))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(LinearGradient.cadencePrimary)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 10)

            Text("Conclude Session")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(sessionSubtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.bottom, 24)

            HStack(spacing: 12) {
                Button(action: onKeepGoing) {
                    Text("Keep Going")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(Color.cadenceAccent)

                Button(action: onEndSession) {
                    Text("End Session")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cadenceAccent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var sessionSubtitle: String {
        let d = Int(duration)
        return d < 60 ? "Captured \(d) seconds of speech" : "Captured \(d/60)m \(d%60)s of speech"
    }
}

// MARK: - Native Mirror Card (no HUD inside — shown below separately)
struct NativeMirrorCard: View {
    @ObservedObject var cameraManager: CameraManager
    let isSpeaking: Bool

    /// Border is always live:
    /// Looking at camera      → green (eye contact maintained)
    /// Not looking at camera  → red (needs correction)
    /// Camera not supported   → subtle grey
    private var borderColor: Color {
        guard cameraManager.faceDetected else { return Color.white.opacity(0.15) }
        return cameraManager.isMakingEyeContact ? Color.cadenceGood : Color.cadenceBad
    }

    private var borderWidth: CGFloat {
        cameraManager.faceDetected ? 2.5 : 1.0
    }

    var body: some View {
        Group {
            if cameraManager.isARSupported, let sv = cameraManager.sceneView {
                CameraPreviewView(sceneView: sv)
                    .scaleEffect(x: -1, y: 1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cadenceCard)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "person.fill.viewfinder")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundStyle(Color.white.opacity(0.25))
                            Text("Front camera unavailable")
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: borderColor.opacity(0.22), radius: 12, y: 4)
        .animation(.easeInOut(duration: 0.3), value: cameraManager.isMakingEyeContact)
    }
}

// MARK: - Eye Contact HUD Row
// Shows "—" until a face is detected for the first time.
// Once a face is found, shows live green/red eye contact state.
struct EyeContactHUDRow: View {
    @ObservedObject var cameraManager: CameraManager
    let isSpeaking: Bool

    var body: some View {
        HStack(spacing: 10) {
            if !cameraManager.faceDetected {
                // No face yet — neutral waiting state
                Label("—  Eye Contact", systemImage: "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
            } else if cameraManager.isMakingEyeContact {
                Label("Eye Contact ✓", systemImage: "eye.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cadenceGood)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.cadenceGood.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.cadenceGood.opacity(0.25), lineWidth: 1))
            } else {
                Label("Look at camera", systemImage: "eye.slash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cadenceBad)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.cadenceBad.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.cadenceBad.opacity(0.30), lineWidth: 1))
            }

            Spacer()

            if cameraManager.eyeContactDuration >= 1 {
                Label(
                    String(format: "%.0fs focused", cameraManager.eyeContactDuration),
                    systemImage: "timer"
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.cadenceGood)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.cadenceGood.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .frame(minHeight: 34)
        .animation(.easeInOut(duration: 0.25), value: cameraManager.faceDetected)
        .animation(.easeInOut(duration: 0.25), value: cameraManager.isMakingEyeContact)
    }
}

// MARK: - Live Flow Strip
// Each slot covers a FIXED 2-second window of real time.
// A slot is ONLY coloured if real speech events were recorded in it.
// Elapsed-but-silent slots stay dark grey — honest, no false mint bars.
struct NativeFlowStrip: View {
    let events: [FlowEvent]
    let duration: TimeInterval
    let isSpeaking: Bool

    private let slotSeconds: Double = 2.0
    private let maxSlots    = 40

    private var elapsedSlots: Int {
        min(maxSlots, max(0, Int(duration / slotSeconds)))
    }

    private func slotColor(index: Int) -> Color? {
        guard index < elapsedSlots else { return nil } // future slot — no fill

        let slotStart = slotSeconds * Double(index)
        let slotEnd   = slotStart + slotSeconds
        let slice     = events.filter { $0.timestamp >= slotStart && $0.timestamp < slotEnd }

        // Priority order: worst event wins the colour
        if slice.contains(where: { if case .flowBreak  = $0.type { return true }; return false }) { return .red    }
        if slice.contains(where: { if case .filler     = $0.type { return true }; return false }) { return .orange }
        if slice.contains(where: { if case .hesitation = $0.type { return true }; return false }) { return .yellow }
        if slice.contains(where: { if case .strongMoment = $0.type { return true }; return false }) { return .mint }

        // No explicit event recorded in this slot.
        // Live current slot + speaking → show mint so strip feels alive in real time.
        let isCurrentSlot = index == elapsedSlots - 1
        if isCurrentSlot && isSpeaking { return .mint }

        // Past elapsed slot with zero events = the speaker was talking cleanly
        // (no filler, no hesitation, no flow break) → show mint to represent good speech.
        // Only stay dark if there are ZERO speech events anywhere near this window,
        // which means the user was silent during this slot.
        let sessionHasSpeech = !events.isEmpty
        if sessionHasSpeech {
            // Check if any events exist in a wider ±1 slot window
            let window = slotSeconds * 2
            let nearby = events.filter { $0.timestamp >= slotStart - window && $0.timestamp < slotEnd + window }
            if !nearby.isEmpty { return .mint }
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Speech Flow DNA", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer()
                let issues = events.filter {
                    switch $0.type { case .strongMoment: return false; default: return true }
                }.count
                let hasAnySpeech = !events.isEmpty
                if issues > 0 {
                    Text("\(issues) issue\(issues == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(Color.cadenceWarn.opacity(0.75))
                } else if hasAnySpeech {
                    Text("Clean so far")
                        .font(.caption2).foregroundStyle(Color.cadenceGood.opacity(0.75))
                }
            }

            GeometryReader { geo in
                let slotW = geo.size.width / CGFloat(maxSlots)
                HStack(spacing: 2) {
                    ForEach(0..<maxSlots, id: \.self) { i in
                        let color = slotColor(index: i)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color ?? Color.white.opacity(0.05))
                            .frame(width: max(1, slotW - 2), height: color != nil ? 22 : 8)
                            .animation(.easeOut(duration: 0.25), value: elapsedSlots)
                    }
                }
                .frame(height: 24, alignment: .center)
            }
            .frame(height: 24)

            HStack(spacing: 14) {
                legendDot(.mint,   "Speaking")
                legendDot(.orange, "Filler")
                legendDot(.yellow, "Pause")
                legendDot(.red,    "Lost flow")
            }
        }
        .padding(12)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.35))
        }
    }
}

// MARK: - Live Waveform Bars
struct LiveWaveformBars: View {
    let samples: [CGFloat]
    let isSpeaking: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(samples.enumerated()), id: \.0) { _, sample in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        isSpeaking
                            ? Color.cadenceAccent.opacity(0.4 + sample * 0.6)
                            : Color.white.opacity(0.06)
                    )
                    // When not speaking: flat 4pt bars — no movement at all
                    .frame(width: 5, height: isSpeaking ? max(4, sample * 48 + 4) : 4)
                    .animation(
                        isSpeaking
                            ? .interactiveSpring(response: 0.16, dampingFraction: 0.65)
                            : .easeOut(duration: 0.3),
                        value: sample
                    )
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Practice View
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
        ZStack(alignment: .bottom) {
            Color.cadenceBG.ignoresSafeArea()

            // Scrollable content — does NOT include End Session button
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    practiceHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 56)
                        .padding(.bottom, 12)

                    NativeMirrorCard(cameraManager: cameraManager, isSpeaking: coachEngine.isSpeaking)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)

                    EyeContactHUDRow(cameraManager: cameraManager, isSpeaking: coachEngine.isSpeaking)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    HStack(spacing: 10) {
                        MetricTile(
                            icon: "speedometer",
                            label: "Words/Min",
                            value: coachEngine.rollingWPM == 0 ? "—" : "\(coachEngine.rollingWPM)",
                            badge: wpmStatus,
                            color: wpmColor
                        )
                        MetricTile(
                            icon: "exclamationmark.bubble.fill",
                            label: "Fillers",
                            value: "\(coachEngine.fillerWordCount)",
                            badge: fillerStatus,
                            color: fillerColor
                        )
                        MetricTile(
                            icon: "waveform.path",
                            label: "Rhythm",
                            value: coachEngine.rhythmStability < 0
                                ? "—"
                                : String(format: "%.0f%%", coachEngine.rhythmStability),
                            badge: rhythmStatus,
                            color: rhythmColor
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    NativeFlowStrip(events: coachEngine.flowEvents, duration: session.duration, isSpeaking: coachEngine.isSpeaking)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    transcriptRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    // ── REPEATED WORDS (shown when overuse detected) ──
                    if !coachEngine.topRepeatedWords.isEmpty {
                        WordWatchView(
                            entries: coachEngine.topRepeatedWords,
                            cogLoad: coachEngine.cognitiveLoadWarning
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8),
                                   value: coachEngine.topRepeatedWords.count)
                    }

                    LiveWaveformBars(
                        samples: coachEngine.waveformSamples,
                        isSpeaking: coachEngine.isSpeaking
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 2)

                    // Bottom padding so content doesn't hide under fixed button
                    Color.clear.frame(height: 110)
                }
            }

            // Fixed bottom area — never moves, always visible
            VStack(spacing: 0) {
                if tipVisible, let tip = liveTip {
                    NativeCoachBanner(tip: tip)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                Button { showEndSheet = true } label: {
                    Label("End Session", systemImage: "stop.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.cadencePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.mint.opacity(0.25), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .background(
                LinearGradient(
                    colors: [Color.cadenceBG.opacity(0), Color.cadenceBG],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: tipVisible)
        }
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
                        rhythmStability: max(0, coachEngine.rhythmStability),
                        attentionScore: 100.0,
                        spontaneityScore: coachEngine.spontaneityScore,
                        detectedFillerWords: coachEngine.detectedFillerWords
                    )
                }
            )
            .presentationDetents([.height(280)])
            .presentationCornerRadius(28)
        }
        .onAppear {
            coachEngine.requestPermissionsAndStart()
            cameraManager.start()
        }
        .onDisappear {
            coachEngine.stop()
            cameraManager.stop()
        }
        .onChange(of: coachEngine.fillerWordCount) { _, v in checkForLiveTip(fillers: v) }
        .onChange(of: coachEngine.cognitiveLoadWarning) { _, v in if v { showTip(.cognitiveLoad) } }
        .onChange(of: coachEngine.rollingWPM) { _, s in
            if s > 175 { checkWPMTip(wpm: s) }
            if s > 0 && s < 100 { checkSlowTip(wpm: s) }
        }
        .onChange(of: cameraManager.isMakingEyeContact) { _, v in if !v { checkEyeContactTip() } }
    }

    // MARK: - Header
    private var practiceHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Practice Session")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Label("LIVE", systemImage: "record.circle")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.red)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(timeString(from: session.duration))
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(LinearGradient.cadencePrimary)
                    .contentTransition(.numericText())
            }
            Spacer()
            if coachEngine.wpm > 0 && coachEngine.spontaneityScore > 0 {
                VStack(spacing: 1) {
                    Text("STYLE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.white.opacity(0.25))
                    Text(spontaneityLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(spontaneityColor)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(spontaneityColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    // MARK: - Transcript row
    // Shows a live-updating transcript. Always auto-scrolls to show the latest text.
    private var transcriptRow: some View {
        let text = coachEngine.transcribedText
        let isEmpty = text.isEmpty
        let wordCount = text.split(separator: " ").count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.45))
                Text("Live transcript")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.25))
                Spacer()
                if !isEmpty {
                    Text("\(wordCount) words")
                        .font(.caption2)
                        .foregroundStyle(Color.mint.opacity(0.5))
                }
            }

            if isEmpty {
                Text("Start speaking — I'm listening…")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("transcriptEnd")
                    }
                    .frame(maxHeight: 90)
                    .onChange(of: text) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("transcriptEnd", anchor: .bottom)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("transcriptEnd", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(minHeight: 80)
    }

    // MARK: - Computed helpers
    private var wpmStatus: String {
        switch coachEngine.rollingWPM {
        case 130...150: return "Ideal"
        case 120..<130, 151...160: return "Good"
        case 100..<120: return "Slow"
        case 161..<180: return "Fast"
        case 0: return "Waiting"
        default: return coachEngine.rollingWPM > 180 ? "Too fast" : "Too slow"
        }
    }
    private var wpmColor: Color {
        switch coachEngine.rollingWPM {
        case 120...160: return Color.cadenceGood
        case 100..<120, 161..<180: return Color.cadenceNeutral
        case 0: return Color(.secondaryLabel)
        default: return Color.cadenceWarn
        }
    }
    private var fillerStatus: String {
        switch coachEngine.fillerWordCount {
        case 0: return "Flawless"
        case 1...3: return "Good"
        case 4...7: return "Notice"
        default: return "High"
        }
    }
    private var fillerColor: Color {
        coachEngine.fillerWordCount == 0 ? Color.cadenceGood
            : coachEngine.fillerWordCount < 5 ? Color.cadenceWarn : Color.cadenceBad
    }
    private var rhythmStatus: String {
        guard coachEngine.rhythmStability >= 0 else { return "Waiting" }
        switch coachEngine.rhythmStability {
        case 85...100: return "Consistent"
        case 70..<85:  return "Steady"
        case 55..<70:  return "Decent"
        case 40..<55:  return "Uneven"
        default:       return "Choppy"
        }
    }
    private var rhythmColor: Color {
        guard coachEngine.rhythmStability >= 0 else { return Color(.secondaryLabel) }
        switch coachEngine.rhythmStability {
        case 70...100: return Color.cadenceGood
        case 50..<70:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }
    private var spontaneityLabel: String {
        switch coachEngine.spontaneityScore {
        case 70...100: return "Natural"
        case 40..<70: return "Mixed"
        default: return "Scripted"
        }
    }
    private var spontaneityColor: Color {
        switch coachEngine.spontaneityScore {
        case 70...100: return Color.cadenceGood
        case 40..<70: return Color.cadenceNeutral
        default: return Color.cadenceWarn
        }
    }

    // MARK: - Tip logic
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

// MARK: - Word Watch View (repeated word chips — shown when engine detects overuse)
struct WordWatchView: View {
    let entries: [WordFrequencyEntry]
    let cogLoad: Bool

    var body: some View {
        if entries.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: cogLoad ? "brain.head.profile" : "repeat.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(cogLoad ? Color.cadenceBad : Color.cadenceWarn)
                        .symbolRenderingMode(.hierarchical)
                    Text(cogLoad ? "High repetition detected" : "Repeated words")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                HStack(spacing: 6) {
                    ForEach(entries.prefix(5)) { entry in
                        WordRepeatChip(entry: entry)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.cadenceCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct WordRepeatChip: View {
    let entry: WordFrequencyEntry
    var body: some View {
        HStack(spacing: 4) {
            Text(entry.word)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cadenceWarn)
            Text("×\(entry.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.cadenceWarn.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.cadenceWarn.opacity(0.25), lineWidth: 1))
    }
}
