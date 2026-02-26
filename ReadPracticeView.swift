// ReadPracticeView.swift
// Cadence — iOS 26 Native Redesign
// ★ FLAGSHIP: Read & Analyze — word-by-word live tracking
// FIX: ReadWordFlowView replaced manual UIFont-based layout engine with
//      a proper SwiftUI Layout protocol implementation (FlowLayout).
//      The old approach broke with Dynamic Type and non-default font sizes.

import SwiftUI
import Speech
import AVFoundation

// ─────────────────────────────────────────────────────────────
// MARK: - FlowLayout (replaces manual GeometryReader word wrap)
// ─────────────────────────────────────────────────────────────

/// A SwiftUI Layout that wraps children into rows, like CSS flex-wrap.
/// Works correctly with Dynamic Type, VoiceOver, and all font sizes.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowResult(in: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: frame.minX + bounds.minX, y: frame.minY + bounds.minY),
                proposal: .unspecified
            )
        }
    }

    private func flowResult(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: y + lineHeight), frames)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────────────────────────────

enum WordState {
    case pending
    case active
    case correct
    case stumbled
    case skipped
}

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
    let categoryIcon: String
    let categoryColor: Color
    let text: String
    let difficulty: Int

    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    static let library: [ReadingPrompt] = [
        ReadingPrompt(
            title: "The Power of Habit",
            category: "Psychology",
            categoryIcon: "brain.head.profile",
            categoryColor: .purple,
            text: "Every habit starts with a simple loop. There is a cue that triggers a routine, and at the end of the routine there is a reward. Over time the brain begins to crave this reward more and more. Understanding this cycle is the first step to changing any habit that holds you back.",
            difficulty: 1
        ),
        ReadingPrompt(
            title: "How Stars Are Born",
            category: "Science",
            categoryIcon: "sparkles",
            categoryColor: .yellow,
            text: "Stars are born inside enormous clouds of gas and dust called nebulae. Gravity slowly pulls the material inward until it collapses under its own weight. The core heats up to millions of degrees and nuclear fusion begins. The star pushes outward with light and energy, balancing the crush of gravity, and shines for billions of years.",
            difficulty: 2
        ),
        ReadingPrompt(
            title: "The Art of Listening",
            category: "Communication",
            categoryIcon: "ear.fill",
            categoryColor: .cyan,
            text: "Most people listen to reply rather than to understand. Real listening means setting aside your own thoughts and giving full attention to the speaker. Notice their tone, their pauses, and the emotion behind the words. A single conversation where someone feels truly heard can change the entire relationship.",
            difficulty: 1
        ),
        ReadingPrompt(
            title: "Climate and the Ocean",
            category: "Environment",
            categoryIcon: "drop.fill",
            categoryColor: .blue,
            text: "The ocean absorbs roughly a quarter of all the carbon dioxide we release into the atmosphere. As carbon levels rise, seawater becomes more acidic. This process, called ocean acidification, threatens the shells and skeletons of countless marine creatures. Protecting the ocean means protecting the very systems that keep our climate stable.",
            difficulty: 2
        ),
        ReadingPrompt(
            title: "Why Sleep Matters",
            category: "Health",
            categoryIcon: "moon.zzz.fill",
            categoryColor: .indigo,
            text: "During sleep the brain replays the day, consolidating memories and clearing out waste products that build up during waking hours. A single night of poor sleep can reduce focus, slow reaction time, and elevate stress hormones. Adults who consistently sleep less than seven hours are at significantly higher risk of heart disease and depression.",
            difficulty: 2
        ),
        ReadingPrompt(
            title: "The Speed of Light",
            category: "Physics",
            categoryIcon: "bolt.fill",
            categoryColor: .orange,
            text: "Nothing in the universe can travel faster than light in a vacuum. Light covers three hundred thousand kilometres every single second. At this speed it takes only about eight minutes to travel from the sun to the Earth. Yet the nearest star beyond our sun is so far away that its light takes over four years to reach us.",
            difficulty: 1
        ),
        ReadingPrompt(
            title: "The Courage to Begin",
            category: "Motivation",
            categoryIcon: "flame.fill",
            categoryColor: .red,
            text: "The gap between where you are and where you want to be is bridged by a single act: beginning. Most people wait for the perfect moment, the perfect conditions, the perfect plan. But clarity does not come before action. It comes from action. Every expert was once a beginner who refused to stop.",
            difficulty: 1
        ),
        ReadingPrompt(
            title: "Artificial Intelligence",
            category: "Technology",
            categoryIcon: "cpu.fill",
            categoryColor: .mint,
            text: "Modern artificial intelligence systems learn from vast collections of data rather than following rigid rules written by programmers. They find patterns no human would notice across millions of examples and use those patterns to make predictions. This approach has transformed fields from medicine to language translation, yet the systems still have no genuine understanding of what they process.",
            difficulty: 3
        ),
    ]
}

struct ReadingAnalysis {
    let prompt: ReadingPrompt
    let words: [ReadWord]
    let duration: TimeInterval
    let wpm: Int
    let accuracy: Double
    let stumbledWords: [String]
    let skippedWords: [String]
    let fillerCount: Int

    var accuracyBadge: String {
        switch accuracy {
        case 95...100: return "Flawless"
        case 85..<95:  return "Strong"
        case 70..<85:  return "Decent"
        default:       return "Needs Work"
        }
    }

    var accuracyColor: Color {
        switch accuracy {
        case 85...100: return .mint
        case 65..<85:  return .yellow
        default:       return .orange
        }
    }

    var wpmBadge: String {
        switch wpm {
        case 120...180: return "Natural Pace"
        case 100..<120: return "Slightly Slow"
        case 180..<220: return "Slightly Fast"
        case 0:         return "No Speech"
        default:        return wpm > 220 ? "Too Fast" : "Too Slow"
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Reading Engine
// ─────────────────────────────────────────────────────────────

@MainActor
class ReadingEngine: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var words: [ReadWord] = []
    @Published var currentIndex: Int = 0
    @Published var liveTranscript: String = ""
    @Published var countdown: Int = 3
    @Published var elapsedTime: TimeInterval = 0
    @Published var fillerCount: Int = 0
    @Published var analysis: ReadingAnalysis? = nil

    enum Phase: Equatable {
        case idle, countdown, reading, finished
    }

    private var prompt: ReadingPrompt?
    private var sourceWords: [String] = []
    private var recognizedBuffer: [String] = []

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var startDate: Date?
    private var timerTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    private let fillerWords: Set<String> = ["um", "uh", "like", "so", "basically"]

    func load(_ prompt: ReadingPrompt) {
        self.prompt = prompt
        sourceWords = prompt.text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }

        words = prompt.text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { ReadWord(text: $0) }

        currentIndex = 0
        liveTranscript = ""
        elapsedTime = 0
        fillerCount = 0
        analysis = nil
        recognizedBuffer = []
        phase = .idle
    }

    func startCountdown() {
        phase = .countdown
        countdown = 3
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
        phase = .reading
        startDate = Date()
        elapsedTime = 0
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
        // FIX: Same on-device recognition fallback as SpeechCoachEngine
        request.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    self.processRecognition(result.bestTranscription.formattedString)
                }
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
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
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
                        matched = true
                        break
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

        if sourceIdx >= sourceWords.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                if self?.phase == .reading { self?.finishSession() }
            }
        }
    }

    private func normalize(_ word: String) -> String {
        word.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
    }

    private func finishSession() {
        guard phase == .reading, let prompt = prompt, let start = startDate else { return }
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        timerTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)

        for i in 0..<words.count {
            if words[i].state == .pending || words[i].state == .active { words[i].state = .skipped }
        }

        let duration = Date().timeIntervalSince(start)
        let totalWords = words.count
        let correctCount = words.filter { $0.state == .correct }.count
        let accuracy = Double(correctCount) / Double(max(totalWords, 1)) * 100.0
        let mins = duration / 60.0
        let wpm = mins > 0 ? Int(Double(correctCount) / mins) : 0
        let stumbled = words.filter { $0.state == .stumbled }.map { $0.text }
        let skipped = words.filter { $0.state == .skipped }.map { $0.text }

        analysis = ReadingAnalysis(
            prompt: prompt, words: words, duration: duration,
            wpm: wpm, accuracy: accuracy, stumbledWords: stumbled,
            skippedWords: skipped, fillerCount: fillerCount
        )
        phase = .finished
    }

    func reset() {
        timerTask?.cancel()
        countdownTask?.cancel()
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        analysis = nil
        phase = .idle
        if let p = prompt { load(p) }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Main View
// ─────────────────────────────────────────────────────────────

struct ReadPracticeView: View {
    @StateObject private var engine = ReadingEngine()
    @State private var selectedPrompt: ReadingPrompt? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.07), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            switch engine.phase {
            case .idle:
                ReadPromptSelectionView(
                    selectedPrompt: selectedPrompt,
                    onSelect: { p in
                        selectedPrompt = p
                        engine.load(p)
                    },
                    onStart: { engine.startCountdown() }
                )
                .transition(.opacity)

            case .countdown:
                ReadCountdownView(count: engine.countdown)
                    .transition(.scale.combined(with: .opacity))

            case .reading:
                ReadingSessionView(engine: engine)
                    .transition(.opacity)

            case .finished:
                if let analysis = engine.analysis {
                    ReadingResultsView(analysis: analysis) { engine.reset() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: engine.phase)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Prompt Selection
// ─────────────────────────────────────────────────────────────

struct ReadPromptSelectionView: View {
    let selectedPrompt: ReadingPrompt?
    let onSelect: (ReadingPrompt) -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.cyan.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.cyan)
                            .symbolRenderingMode(.hierarchical)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Read & Analyze")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Read aloud — watch every word light up")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(white: 0.48))
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    ForEach(Array(howItWorks.enumerated()), id: \.0) { i, step in
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(step.color.opacity(0.18))
                                    .frame(width: 24, height: 24)
                                Text("\(i + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(step.color)
                            }
                            Text(step.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(white: 0.55))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(step.color.opacity(0.07))
                        .clipShape(Capsule())

                        if i < howItWorks.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(white: 0.22))
                        }
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.08))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    Text("Choose a Passage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    ForEach(ReadingPrompt.library) { prompt in
                        ReadPromptCard(
                            prompt: prompt,
                            isSelected: selectedPrompt?.id == prompt.id,
                            onTap: { onSelect(prompt) }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 36)

                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: selectedPrompt == nil ? "text.cursor" : "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(selectedPrompt == nil ? "Choose a passage above" : "Start Reading")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(selectedPrompt == nil ? Color(white: 0.4) : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        selectedPrompt == nil
                            ? AnyShapeStyle(Color.white.opacity(0.08))
                            : AnyShapeStyle(LinearGradient(
                                colors: [.cyan, Color(red: 0.1, green: 0.82, blue: 0.88)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(
                        color: selectedPrompt != nil ? Color.cyan.opacity(0.38) : .clear,
                        radius: 18, y: 6
                    )
                }
                .disabled(selectedPrompt == nil)
                .animation(.easeInOut(duration: 0.22), value: selectedPrompt?.id)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(.black.opacity(0.92))
                .accessibilityLabel(selectedPrompt == nil ? "Choose a passage first" : "Start reading \(selectedPrompt?.title ?? "")")
            }
        }
    }

    private let howItWorks = [
        (label: "Pick passage", color: Color.cyan),
        (label: "Read aloud",   color: Color.mint),
        (label: "See results",  color: Color.purple),
    ]
}

// ─────────────────────────────────────────────────────────────
// MARK: - Prompt Card
// ─────────────────────────────────────────────────────────────

struct ReadPromptCard: View {
    let prompt: ReadingPrompt
    let isSelected: Bool
    let onTap: () -> Void

    private var difficultyLabel: String {
        ["Easy", "Medium", "Advanced"][prompt.difficulty - 1]
    }
    private var difficultyColor: Color {
        [Color.mint, Color.yellow, Color.orange][prompt.difficulty - 1]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(prompt.categoryColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: prompt.categoryIcon)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(prompt.categoryColor)
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(prompt.category)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(prompt.categoryColor.opacity(0.8))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(difficultyLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(difficultyColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(difficultyColor.opacity(0.14))
                            .clipShape(Capsule())

                        HStack(spacing: 3) {
                            Image(systemName: "text.word.spacing")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(white: 0.32))
                            Text("\(prompt.wordCount)w")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color(white: 0.32))
                        }
                    }
                }
                .padding(14)

                Divider()
                    .background(Color.white.opacity(isSelected ? 0.12 : 0.06))
                    .padding(.horizontal, 14)

                Text(String(prompt.text.prefix(110)) + "…")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(white: isSelected ? 0.7 : 0.5))
                    .lineSpacing(4)
                    .lineLimit(3)
                    .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? prompt.categoryColor.opacity(0.10) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? prompt.categoryColor.opacity(0.5) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.18), value: isSelected)
        .accessibilityLabel("\(prompt.title). \(prompt.category). \(difficultyLabel). \(prompt.wordCount) words.")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Countdown View
// ─────────────────────────────────────────────────────────────

struct ReadCountdownView: View {
    let count: Int
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("\(count)")
                .font(.system(size: 110, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .mint], startPoint: .top, endPoint: .bottom)
                )
                .scaleEffect(scale)
                .opacity(opacity)
            Text("Get ready to read…")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(white: 0.5))
        }
        .accessibilityLabel("Starting in \(count)")
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0; opacity = 1.0
            }
        }
        .onChange(of: count) { _, _ in
            scale = 0.4; opacity = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                scale = 1.0; opacity = 1.0
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Live Reading Session
// ─────────────────────────────────────────────────────────────

struct ReadingSessionView: View {
    @ObservedObject var engine: ReadingEngine

    private var progress: Double {
        let done = engine.words.filter { $0.state == .correct || $0.state == .stumbled }.count
        return Double(done) / Double(max(engine.words.count, 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reading")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(String(format: "%.0f%% complete", progress * 100))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                HStack(spacing: 12) {
                    Text(timeStr(engine.elapsedTime))
                        .font(.system(size: 18, design: .monospaced).bold())
                        .foregroundStyle(.cyan)
                    Button { engine.stopEarly() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(white: 0.35))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Stop reading")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 52)
            .padding(.bottom, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .accessibilityLabel(String(format: "Reading progress: %.0f percent", progress * 100))

            // FIX: replaced fragile manual GeometryReader layout with FlowLayout
            ScrollView(showsIndicators: false) {
                ReadWordFlowView(words: engine.words)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 7, height: 7)
                Text(engine.liveTranscript.isEmpty ? "Listening for your voice…" : engine.liveTranscript)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(white: 0.55))
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.2), value: engine.liveTranscript)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
            .accessibilityLabel("Transcript: \(engine.liveTranscript.isEmpty ? "waiting" : engine.liveTranscript)")
        }
    }

    private func timeStr(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Word Flow (FIX: uses FlowLayout instead of manual layout)
// ─────────────────────────────────────────────────────────────

struct ReadWordFlowView: View {
    let words: [ReadWord]

    var body: some View {
        // FIX: FlowLayout is a proper SwiftUI Layout that:
        //  1. Respects Dynamic Type (asks views for their natural size via sizeThatFits)
        //  2. Doesn't rely on UIFont metrics which can diverge from SwiftUI rendering
        //  3. Works correctly at all accessibility text sizes
        FlowLayout(spacing: 6) {
            ForEach(words) { word in
                ReadWordChip(word: word)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Passage words: \(words.map { $0.text }.joined(separator: " "))")
    }
}

struct ReadWordChip: View {
    let word: ReadWord
    @State private var pulse = false

    private var bg: Color {
        switch word.state {
        case .pending:  return Color.white.opacity(0.06)
        case .active:   return Color.cyan.opacity(0.22)
        case .correct:  return Color.mint.opacity(0.18)
        case .stumbled: return Color.orange.opacity(0.18)
        case .skipped:  return Color.red.opacity(0.14)
        }
    }
    private var fg: Color {
        switch word.state {
        case .pending:  return Color(white: 0.44)
        case .active:   return .cyan
        case .correct:  return .mint
        case .stumbled: return .orange
        case .skipped:  return .red.opacity(0.7)
        }
    }
    private var border: Color {
        switch word.state {
        case .active:   return .cyan.opacity(0.7)
        case .correct:  return .mint.opacity(0.4)
        case .stumbled: return .orange.opacity(0.4)
        case .skipped:  return .red.opacity(0.3)
        default:        return .clear
        }
    }

    var body: some View {
        Text(word.text)
            .font(.system(size: 17, weight: word.state == .active ? .bold : .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(border, lineWidth: 1.5)
            )
            .scaleEffect(word.state == .active && pulse ? 1.06 : 1.0)
            .onAppear {
                if word.state == .active {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: word.state)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Results View
// ─────────────────────────────────────────────────────────────

struct ReadingResultsView: View {
    let analysis: ReadingAnalysis
    let onDone: () -> Void

    @State private var animAccuracy: Double = 0
    @State private var animWPM: Int = 0
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Reading Complete")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    Text(analysis.prompt.title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(analysis.prompt.categoryColor.opacity(0.8))
                }
                .padding(.top, 52)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: CGFloat(animAccuracy / 100.0))
                        .stroke(
                            AngularGradient(
                                colors: [analysis.accuracyColor.opacity(0.5), analysis.accuracyColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.4, dampingFraction: 0.75).delay(0.4), value: animAccuracy)

                    VStack(spacing: 3) {
                        Text(String(format: "%.0f%%", animAccuracy))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(analysis.accuracyColor)
                            .contentTransition(.numericText())
                        Text("Accuracy")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(white: 0.38))
                        Text(analysis.accuracyBadge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(analysis.accuracyColor)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Accuracy \(Int(animAccuracy)) percent. \(analysis.accuracyBadge)")
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                HStack(spacing: 12) {
                    ReadResultStatCard(
                        icon: "speedometer",
                        title: "WPM",
                        value: "\(animWPM)",
                        badge: analysis.wpmBadge,
                        color: analysis.wpm >= 120 && analysis.wpm <= 180 ? .mint : .yellow
                    )
                    ReadResultStatCard(
                        icon: "exclamationmark.bubble",
                        title: "Fillers",
                        value: "\(analysis.fillerCount)",
                        badge: analysis.fillerCount == 0 ? "Flawless" : analysis.fillerCount < 4 ? "Good" : "Noticeable",
                        color: analysis.fillerCount == 0 ? .mint : analysis.fillerCount < 4 ? .yellow : .orange
                    )
                    ReadResultStatCard(
                        icon: "checkmark.circle",
                        title: "Correct",
                        value: "\(analysis.words.filter { $0.state == .correct }.count)",
                        badge: "of \(analysis.words.count) words",
                        color: .cyan
                    )
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)

                ReadWordMapView(words: analysis.words)
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)

                if !analysis.stumbledWords.isEmpty {
                    ReadWordListCard(
                        title: "Stumbled On",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        words: analysis.stumbledWords,
                        tip: "Try saying these words alone, slowly."
                    )
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: appeared)
                }

                HStack(spacing: 12) {
                    Button(action: onDone) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Try Again")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button(action: onDone) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                            Text("New Passage")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.cyan, Color(red: 0.1, green: 0.82, blue: 0.88)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .cyan.opacity(0.35), radius: 14, y: 5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.75), value: appeared)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.07), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { animAccuracy = analysis.accuracy }
                withAnimation(.easeOut(duration: 1.2)) { animWPM = analysis.wpm }
            }
        }
    }
}

// MARK: - Result Sub-components

struct ReadResultStatCard: View {
    let icon: String
    let title: String
    let value: String
    let badge: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color.opacity(0.8))
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color(white: 0.35))
            Text(badge)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.14))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value). \(badge)")
    }
}

struct ReadWordMapView: View {
    let words: [ReadWord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reading Map")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Every word, colour-coded")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(white: 0.32))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 20), spacing: 3) {
                ForEach(words) { w in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(dotColor(w.state))
                        .frame(height: 10)
                }
            }

            HStack(spacing: 12) {
                ReadMapLegend(color: .mint,             label: "Correct")
                ReadMapLegend(color: .orange,           label: "Stumbled")
                ReadMapLegend(color: .red.opacity(0.7), label: "Skipped")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading map: \(words.filter { $0.state == .correct }.count) correct, \(words.filter { $0.state == .stumbled }.count) stumbled, \(words.filter { $0.state == .skipped }.count) skipped")
    }

    private func dotColor(_ state: WordState) -> Color {
        switch state {
        case .correct:  return .mint
        case .stumbled: return .orange
        case .skipped:  return .red.opacity(0.7)
        default:        return Color(white: 0.18)
        }
    }
}

struct ReadMapLegend: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 10, weight: .regular)).foregroundStyle(Color(white: 0.4))
        }
    }
}

struct ReadWordListCard: View {
    let title: String
    let icon: String
    let color: Color
    let words: [String]
    let tip: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            let columns = [GridItem(.adaptive(minimum: 70))]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(words.prefix(20), id: \.self) { word in
                    Text(word)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(tip)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(white: 0.42))
                .lineSpacing(3)
        }
        .padding(14)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(words.prefix(20).joined(separator: ", ")). \(tip)")
    }
}
