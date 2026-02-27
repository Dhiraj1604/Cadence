// ReadPracticeView.swift
// Cadence — Read & Track
// The invention: every word you speak lights up in real time
// iOS 26 native · Clean · Purposeful

import SwiftUI
import Speech
import AVFoundation

// MARK: - Models

enum WordState { case pending, active, correct, stumbled, skipped }

struct ReadWord: Identifiable {
    let id = UUID()
    let text: String
    var state: WordState = .pending
    var recognizedAs: String? = nil
}

struct ReadingPrompt: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let icon: String
    let color: Color
    let text: String
    let difficulty: Int   // 1 easy · 2 medium · 3 hard

    var wordCount: Int {
        text.split(separator: " ").count
    }

    static let library: [ReadingPrompt] = [
        ReadingPrompt(title: "The Power of Habit", category: "Psychology",
            icon: "brain.head.profile", color: .purple,
            text: "Every habit starts with a simple loop. There is a cue that triggers a routine, and at the end of the routine there is a reward. Over time the brain begins to crave this reward more and more. Understanding this cycle is the first step to changing any habit that holds you back.",
            difficulty: 1),
        ReadingPrompt(title: "How Stars Are Born", category: "Science",
            icon: "sparkles", color: .yellow,
            text: "Stars are born inside enormous clouds of gas and dust called nebulae. Gravity slowly pulls the material inward until it collapses under its own weight. The core heats up to millions of degrees and nuclear fusion begins. The star pushes outward with light and energy, balancing the crush of gravity, and shines for billions of years.",
            difficulty: 2),
        ReadingPrompt(title: "The Art of Listening", category: "Communication",
            icon: "ear.fill", color: .cyan,
            text: "Most people listen to reply rather than to understand. Real listening means setting aside your own thoughts and giving full attention to the speaker. Notice their tone, their pauses, and the emotion behind the words. A single conversation where someone feels truly heard can change the entire relationship.",
            difficulty: 1),
        ReadingPrompt(title: "Why Sleep Matters", category: "Health",
            icon: "moon.zzz.fill", color: .indigo,
            text: "During sleep the brain replays the day, consolidating memories and clearing out waste products that build up during waking hours. A single night of poor sleep can reduce focus, slow reaction time, and elevate stress hormones. Adults who consistently sleep less than seven hours are at significantly higher risk of heart disease and depression.",
            difficulty: 2),
        ReadingPrompt(title: "The Courage to Begin", category: "Motivation",
            icon: "flame.fill", color: .orange,
            text: "The gap between where you are and where you want to be is bridged by a single act: beginning. Most people wait for the perfect moment, the perfect conditions, the perfect plan. But clarity does not come before action. It comes from action. Every expert was once a beginner who refused to stop.",
            difficulty: 1),
        ReadingPrompt(title: "Artificial Intelligence", category: "Technology",
            icon: "cpu.fill", color: .mint,
            text: "Modern artificial intelligence systems learn from vast collections of data rather than following rigid rules written by programmers. They find patterns no human would notice across millions of examples and use those patterns to make predictions. This approach has transformed fields from medicine to language translation, yet the systems still have no genuine understanding of what they process.",
            difficulty: 3),
    ]
}

// MARK: - Reading Engine

@MainActor
class ReadingEngine: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var words: [ReadWord] = []
    @Published var currentIndex: Int = 0
    @Published var liveTranscript: String = ""
    @Published var countdown: Int = 3
    @Published var elapsedTime: TimeInterval = 0
    @Published var fillerCount: Int = 0
    @Published var accuracy: Double = 0
    @Published var wpm: Int = 0

    enum Phase: Equatable { case idle, countdown, reading, finished }

    private var prompt: ReadingPrompt?
    private var sourceWords: [String] = []
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var startDate: Date?
    private var timerTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private let fillerWords: Set<String> = ["um","uh","like","so","basically"]

    func load(_ prompt: ReadingPrompt) {
        self.prompt = prompt
        sourceWords = prompt.text
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        words = prompt.text
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            .map { ReadWord(text: $0) }
        currentIndex = 0; liveTranscript = ""
        elapsedTime = 0; fillerCount = 0; accuracy = 0; wpm = 0
        phase = .idle
    }

    func startCountdown() {
        phase = .countdown; countdown = 3
        countdownTask?.cancel()
        countdownTask = Task {
            for i in stride(from: 3, through: 1, by: -1) {
                countdown = i
                try? await Task.sleep(nanoseconds: 900_000_000)
                if Task.isCancelled { return }
            }
            await startReading()
        }
    }

    func stopEarly() { finishSession() }

    private func startReading() async {
        phase = .reading; startDate = Date(); elapsedTime = 0
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                elapsedTime = Date().timeIntervalSince(startDate ?? Date())
            }
        }
        await requestAndStartSpeech()
    }

    private func requestAndStartSpeech() async {
        let status = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized else { return }
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result { self.processRecognition(result.bestTranscription.formattedString) }
                if error != nil || (result?.isFinal ?? false) {
                    if self.phase == .reading { self.finishSession() }
                }
            }
        }
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }
        audioEngine.prepare()
        try? audioEngine.start()
    }

    private func processRecognition(_ fullText: String) {
        liveTranscript = fullText
        let spoken = fullText.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        fillerCount = spoken.filter { fillerWords.contains($0) }.count

        let alreadyMatched = words.filter { $0.state == .correct || $0.state == .stumbled }.count
        guard spoken.count > alreadyMatched else { return }
        let newSpoken = Array(spoken.suffix(spoken.count - alreadyMatched))
        var sourceIdx = alreadyMatched

        for spokenWord in newSpoken {
            guard sourceIdx < sourceWords.count else { break }
            if normalize(spokenWord) == normalize(sourceWords[sourceIdx]) {
                words[sourceIdx].state = .correct
                words[sourceIdx].recognizedAs = spokenWord
                sourceIdx += 1
            } else {
                var matched = false
                for lookahead in 1...2 {
                    let ahead = sourceIdx + lookahead
                    guard ahead < sourceWords.count else { break }
                    if normalize(spokenWord) == normalize(sourceWords[ahead]) {
                        for skipped in sourceIdx..<ahead {
                            if words[skipped].state == .pending { words[skipped].state = .stumbled }
                        }
                        words[ahead].state = .correct
                        words[ahead].recognizedAs = spokenWord
                        sourceIdx = ahead + 1
                        matched = true; break
                    }
                }
                if !matched {
                    words[sourceIdx].state = .stumbled
                    words[sourceIdx].recognizedAs = spokenWord
                    sourceIdx += 1
                }
            }
        }
        currentIndex = sourceIdx
        if currentIndex < words.count {
            for i in currentIndex..<words.count {
                if words[i].state == .pending { words[i].state = .active; break }
            }
        }
        // Live accuracy
        let correct = words.filter { $0.state == .correct }.count
        let total = words.filter { $0.state != .pending }.count
        accuracy = total > 0 ? Double(correct) / Double(total) * 100 : 0
        // Live WPM
        if let start = startDate {
            let mins = Date().timeIntervalSince(start) / 60.0
            wpm = mins > 0 ? Int(Double(correct) / mins) : 0
        }
        if sourceIdx >= sourceWords.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                if self?.phase == .reading { self?.finishSession() }
            }
        }
    }

    private func normalize(_ w: String) -> String {
        w.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
    }

    private func finishSession() {
        guard phase == .reading else { return }
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio(); recognitionTask?.cancel(); timerTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
        for i in 0..<words.count {
            if words[i].state == .pending || words[i].state == .active { words[i].state = .skipped }
        }
        let correct = words.filter { $0.state == .correct }.count
        accuracy = Double(correct) / Double(max(words.count, 1)) * 100
        if let start = startDate {
            let mins = Date().timeIntervalSince(start) / 60.0
            wpm = mins > 0 ? Int(Double(correct) / mins) : 0
        }
        phase = .finished
    }

    func reset() {
        timerTask?.cancel(); countdownTask?.cancel()
        if audioEngine.isRunning { audioEngine.inputNode.removeTap(onBus: 0); audioEngine.stop() }
        recognitionRequest?.endAudio(); recognitionTask?.cancel()
        if let p = prompt { load(p) } else { phase = .idle }
    }
}

// MARK: - Main View

struct ReadPracticeView: View {
    @StateObject private var engine = ReadingEngine()
    @State private var selectedPrompt: ReadingPrompt?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.10, blue: 0.10), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            switch engine.phase {
            case .idle:
                PromptSelectionView(
                    selected: selectedPrompt,
                    onSelect: { p in selectedPrompt = p; engine.load(p) },
                    onStart: { engine.startCountdown() }
                )
                .transition(.opacity)

            case .countdown:
                CountdownView(count: engine.countdown)
                    .transition(.scale.combined(with: .opacity))

            case .reading:
                ReadingSessionView(engine: engine)
                    .transition(.opacity)

            case .finished:
                ReadingResultsView(engine: engine, onReset: { engine.reset() })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.phase)
    }
}

// MARK: - Prompt Selection

struct PromptSelectionView: View {
    let selected: ReadingPrompt?
    let onSelect: (ReadingPrompt) -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.cyan)
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Read & Track")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Every word lights up as you speak")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.46))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.07))
            }

            // Passage list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("Choose a Passage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.36))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    LazyVStack(spacing: 8) {
                        ForEach(ReadingPrompt.library) { prompt in
                            PromptRow(
                                prompt: prompt,
                                isSelected: selected?.id == prompt.id,
                                onTap: { onSelect(prompt) }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    Spacer(minLength: 110)
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 32)
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: selected == nil ? "text.cursor" : "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(selected == nil ? "Choose a passage above" : "Start Reading")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(selected == nil ? Color(white: 0.35) : .black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        selected == nil
                            ? AnyShapeStyle(Color.white.opacity(0.07))
                            : AnyShapeStyle(LinearGradient(
                                colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing
                            ))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: selected != nil ? Color.cyan.opacity(0.32) : .clear, radius: 14, y: 5)
                }
                .disabled(selected == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .background(.black.opacity(0.95))
            }
            .animation(.easeInOut(duration: 0.2), value: selected?.id)
        }
    }
}

// MARK: - Prompt Row
struct PromptRow: View {
    let prompt: ReadingPrompt
    let isSelected: Bool
    let onTap: () -> Void

    private var diffLabel: String { ["Easy","Medium","Advanced"][prompt.difficulty - 1] }
    private var diffColor: Color { [Color.mint, Color.yellow, Color.orange][prompt.difficulty - 1] }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(prompt.color.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: prompt.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(prompt.color)
                        .symbolRenderingMode(.hierarchical)
                }
                // Title + category
                VStack(alignment: .leading, spacing: 3) {
                    Text(prompt.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(prompt.category)
                        .font(.system(size: 12))
                        .foregroundStyle(prompt.color.opacity(0.75))
                }
                Spacer()
                // Right side
                VStack(alignment: .trailing, spacing: 4) {
                    Text(diffLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(diffColor)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(diffColor.opacity(0.13))
                        .clipShape(Capsule())
                    Text("\(prompt.wordCount)w")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.30))
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? prompt.color : Color(white: 0.22))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(isSelected ? prompt.color.opacity(0.09) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? prompt.color.opacity(0.40) : Color.white.opacity(0.07),
                    lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Countdown
struct CountdownView: View {
    let count: Int
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("\(count)")
                .font(.system(size: 100, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.cyan, .mint], startPoint: .top, endPoint: .bottom))
                .scaleEffect(scale).opacity(opacity)
            Text("Get ready…")
                .font(.system(size: 15)).foregroundStyle(Color(white: 0.45))
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { scale = 1; opacity = 1 }
        }
        .onChange(of: count) { _ in
            scale = 0.4; opacity = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { scale = 1; opacity = 1 }
        }
    }
}

// MARK: - Live Reading Session
struct ReadingSessionView: View {
    @ObservedObject var engine: ReadingEngine

    private var progress: Double {
        let done = engine.words.filter { $0.state == .correct || $0.state == .stumbled }.count
        return Double(done) / Double(max(engine.words.count, 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    Text(String(format: "%.0f%% complete · %@", progress * 100, timeStr(engine.elapsedTime)))
                        .font(.system(size: 12)).foregroundStyle(Color(white: 0.42))
                }
                Spacer()
                Button { engine.stopEarly() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color(white: 0.30))
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 20).padding(.top, 52).padding(.bottom, 12)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 3)
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 3).padding(.horizontal, 20).padding(.bottom, 16)

            // Live stats row
            HStack(spacing: 0) {
                MiniStatPill(icon: "checkmark.circle.fill", value: String(format: "%.0f%%", engine.accuracy), color: accuracyColor)
                Spacer()
                MiniStatPill(icon: "speedometer", value: engine.wpm > 0 ? "\(engine.wpm) WPM" : "—", color: .mint)
                Spacer()
                MiniStatPill(icon: "exclamationmark.bubble.fill", value: "\(engine.fillerCount) fillers", color: engine.fillerCount == 0 ? .mint : .orange)
            }
            .padding(.horizontal, 24).padding(.bottom, 14)

            // Word flow
            ScrollView(showsIndicators: false) {
                ReadWordFlowView(words: engine.words).padding(.horizontal, 20).padding(.bottom, 16)
            }

            Spacer()

            // Live transcript
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Text(engine.liveTranscript.isEmpty ? "Listening for your voice…" : engine.liveTranscript)
                    .font(.system(size: 12)).foregroundStyle(Color(white: 0.50)).lineLimit(2)
                    .animation(.easeInOut(duration: 0.2), value: engine.liveTranscript)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 20).padding(.bottom, 48)
        }
    }

    private var accuracyColor: Color {
        engine.accuracy >= 85 ? .mint : engine.accuracy >= 65 ? .yellow : .orange
    }
    private func timeStr(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

struct MiniStatPill: View {
    let icon: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.10)).clipShape(Capsule())
    }
}

// MARK: - Word Flow Layout
struct ReadWordFlowView: View {
    let words: [ReadWord]

    var body: some View {
        GeometryReader { geo in
            buildFlow(in: geo.size.width)
        }
        .frame(minHeight: 180)
    }

    private func buildFlow(in totalWidth: CGFloat) -> some View {
        var rows: [[ReadWord]] = [[]]
        var rowWidth: CGFloat = 0
        let spacing: CGFloat = 6
        let font = UIFont.systemFont(ofSize: 16, weight: .medium)

        for word in words {
            let w = (word.text as NSString).size(withAttributes: [.font: font]).width + 20
            if rowWidth + w + spacing > totalWidth && !rows.last!.isEmpty {
                rows.append([]); rowWidth = 0
            }
            rows[rows.count - 1].append(word)
            rowWidth += w + spacing
        }

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.0) { _, row in
                HStack(spacing: 6) { ForEach(row) { ReadWordChip(word: $0) } }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReadWordChip: View {
    let word: ReadWord
    @State private var pulse = false

    private var bg: Color {
        switch word.state {
        case .pending:  return Color.white.opacity(0.05)
        case .active:   return Color.cyan.opacity(0.20)
        case .correct:  return Color.mint.opacity(0.16)
        case .stumbled: return Color.orange.opacity(0.16)
        case .skipped:  return Color.red.opacity(0.12)
        }
    }
    private var fg: Color {
        switch word.state {
        case .pending:  return Color(white: 0.38)
        case .active:   return .cyan
        case .correct:  return .mint
        case .stumbled: return .orange
        case .skipped:  return .red.opacity(0.65)
        }
    }
    private var border: Color {
        switch word.state {
        case .active:   return .cyan.opacity(0.65)
        case .correct:  return .mint.opacity(0.35)
        case .stumbled: return .orange.opacity(0.35)
        case .skipped:  return .red.opacity(0.25)
        default:        return .clear
        }
    }

    var body: some View {
        Text(word.text)
            .font(.system(size: 16, weight: word.state == .active ? .bold : .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(border, lineWidth: 1.5))
            .scaleEffect(word.state == .active && pulse ? 1.05 : 1.0)
            .onAppear {
                if word.state == .active {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: word.state)
    }
}

// MARK: - Results View
struct ReadingResultsView: View {
    @ObservedObject var engine: ReadingEngine
    let onReset: () -> Void
    @State private var appeared = false

    private var stumbled: [String] { engine.words.filter { $0.state == .stumbled }.map { $0.text } }
    private var accuracyColor: Color {
        engine.accuracy >= 85 ? .mint : engine.accuracy >= 65 ? .yellow : .orange
    }
    private var accuracyBadge: String {
        engine.accuracy >= 95 ? "Flawless" : engine.accuracy >= 85 ? "Strong"
            : engine.accuracy >= 70 ? "Decent" : "Needs Work"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // Title
                VStack(spacing: 5) {
                    Text("Reading Complete")
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                }
                .padding(.top, 52)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                // Big accuracy ring
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 10).frame(width: 130, height: 130)
                    Circle()
                        .trim(from: 0, to: CGFloat(engine.accuracy / 100))
                        .stroke(AngularGradient(colors: [accuracyColor.opacity(0.5), accuracyColor], center: .center),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 130, height: 130).rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.3, dampingFraction: 0.75).delay(0.3), value: engine.accuracy)
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", engine.accuracy))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(accuracyColor)
                        Text(accuracyBadge)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(accuracyColor)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                // Stats row
                HStack(spacing: 10) {
                    ReadStatCard(icon: "speedometer", title: "WPM",
                        value: "\(engine.wpm)", color: engine.wpm >= 120 && engine.wpm <= 180 ? .mint : .yellow)
                    ReadStatCard(icon: "exclamationmark.bubble.fill", title: "Fillers",
                        value: "\(engine.fillerCount)",
                        color: engine.fillerCount == 0 ? .mint : engine.fillerCount < 4 ? .yellow : .orange)
                    ReadStatCard(icon: "checkmark.circle.fill", title: "Correct",
                        value: "\(engine.words.filter { $0.state == .correct }.count)",
                        color: .cyan)
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

                // Word map
                ReadWordMapView(words: engine.words)
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)

                // Stumbled words
                if !stumbled.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12)).foregroundStyle(.orange).symbolRenderingMode(.hierarchical)
                            Text("Stumbled On").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        }
                        let cols = [GridItem(.adaptive(minimum: 70))]
                        LazyVGrid(columns: cols, alignment: .leading, spacing: 6) {
                            ForEach(stumbled.prefix(16), id: \.self) { word in
                                Text(word)
                                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.12)).clipShape(Capsule())
                            }
                        }
                        Text("Practise these words slowly until they flow.")
                            .font(.system(size: 11)).foregroundStyle(Color(white: 0.38))
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.18), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
                }

                // Actions
                HStack(spacing: 12) {
                    Button(action: onReset) {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(white: 0.75))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    Button(action: onReset) {
                        Label("New Passage", systemImage: "doc.text.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .cyan.opacity(0.30), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.bottom, 48)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.65), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }
}

struct ReadStatCard: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(title).font(.system(size: 10)).foregroundStyle(Color(white: 0.34))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

struct ReadWordMapView: View {
    let words: [ReadWord]
    private func dotColor(_ s: WordState) -> Color {
        switch s { case .correct: return .mint; case .stumbled: return .orange
        case .skipped: return .red.opacity(0.65); default: return Color(white: 0.16) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reading Map").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("every word, colour-coded").font(.system(size: 10)).foregroundStyle(Color(white: 0.30))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 20), spacing: 3) {
                ForEach(words) { RoundedRectangle(cornerRadius: 2).fill(dotColor($0.state)).frame(height: 9) }
            }
            HStack(spacing: 12) {
                ForEach([("Correct",.mint),("Stumbled",Color.orange),("Skipped",Color.red.opacity(0.65))], id: \.0) { l, c in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).fill(c).frame(width: 9, height: 9)
                        Text(l).font(.system(size: 10)).foregroundStyle(Color(white: 0.38))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// Compatibility aliases
typealias ReadingAnalysis = ReadingEngine
typealias ReadResultStatCard = ReadStatCard
