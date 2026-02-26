//
//  ReadPracticeView.swift
//  Cadence
//
//  Created by Dhiraj on 26/02/26.
//
// ReadPracticeView.swift
// Cadence — SSC Edition
// ★ FLAGSHIP INNOVATION: Read & Analyze
//
// User picks a paragraph → reads aloud → each word lights up in real time
// as the speech engine recognizes it. Post-read: accuracy %, WPM, stumble map.
// This is the "aha moment" — a reading coach that follows every word.

import SwiftUI
import Speech
import AVFoundation

// ─────────────────────────────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────────────────────────────

enum WordState {
    case pending        // Not yet reached — dimmed white
    case active         // Current expected word — pulsing highlight
    case correct        // Said correctly — mint green
    case stumbled       // Said but hesitated on — orange
    case skipped        // Not said — red (post-session only)
}

struct ReadWord: Identifiable {
    let id = UUID()
    let text: String                // Original word
    var state: WordState = .pending
    var recognizedAs: String? = nil // What the mic heard
}

struct ReadingPrompt: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let categoryIcon: String
    let categoryColor: Color
    let text: String
    let difficulty: Int             // 1–3

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
            title: "Artificial Intelligence Today",
            category: "Technology",
            categoryIcon: "cpu.fill",
            categoryColor: .mint,
            text: "Modern artificial intelligence systems learn from vast collections of data rather than following rigid rules written by programmers. They find patterns no human would notice across millions of examples and use those patterns to make predictions. This approach has transformed fields from medicine to language translation, yet the systems still have no genuine understanding of what they process.",
            difficulty: 3
        ),
    ]
}

// Analysis result returned after a reading session
struct ReadingAnalysis {
    let prompt: ReadingPrompt
    let words: [ReadWord]
    let duration: TimeInterval
    let wpm: Int
    let accuracy: Double              // 0–100
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
        case idle
        case countdown
        case reading
        case finished
    }

    private var prompt: ReadingPrompt?
    private var sourceWords: [String] = []      // lowercased, stripped
    private var recognizedBuffer: [String] = [] // running list of all recognized words

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var startDate: Date?
    private var timerTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    private let fillerWords: Set<String> = ["um", "uh", "like", "so", "basically"]

    // ── Public API ────────────────────────────────────────────

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

    func stopEarly() {
        finishSession()
    }

    // ── Private: Recording ────────────────────────────────────

    private func startReading() async {
        phase = .reading
        startDate = Date()
        elapsedTime = 0

        // Timer
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)   // 0.2s tick for smooth counter
                elapsedTime = Date().timeIntervalSince(startDate ?? Date())
            }
        }

        // Speech
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
                if let result = result {
                    self.processRecognition(result.bestTranscription.formattedString)
                }
                if error != nil || (result?.isFinal ?? false) {
                    // Auto-stop when speech engine finalizes
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

    // ── Core Algorithm: Real-time word matching ───────────────
    //
    // As speech recognition returns partial text we:
    // 1. Split into words, strip punctuation
    // 2. Greedily advance through sourceWords matching recognized words
    // 3. Mark matched words as .correct; if a word doesn't match,
    //    mark it .stumbled and still advance (we don't freeze on misreads)
    //
    // The "active" badge follows currentIndex so the user can see
    // exactly where the engine thinks they are.

    private func processRecognition(_ fullText: String) {
        liveTranscript = fullText

        let spoken = fullText
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        fillerCount = spoken.filter { fillerWords.contains($0) }.count

        // How many source words have already been confidently matched?
        let alreadyMatched = words.filter { $0.state == .correct || $0.state == .stumbled }.count

        // We only process NEW spoken words past what we've already handled
        guard spoken.count > alreadyMatched else { return }
        let newSpoken = Array(spoken.suffix(spoken.count - alreadyMatched))

        var sourceIdx = alreadyMatched   // where to look in sourceWords

        for spokenWord in newSpoken {
            guard sourceIdx < sourceWords.count else { break }

            // Try exact match first
            if normalize(spokenWord) == normalize(sourceWords[sourceIdx]) {
                words[sourceIdx].state = .correct
                words[sourceIdx].recognizedAs = spokenWord
                sourceIdx += 1
            } else {
                // Look ahead up to 2 words to handle minor recognition mismatches
                var matched = false
                for lookahead in 1...2 {
                    let ahead = sourceIdx + lookahead
                    guard ahead < sourceWords.count else { break }
                    if normalize(spokenWord) == normalize(sourceWords[ahead]) {
                        // Mark skipped words as stumbled
                        for skipped in sourceIdx..<ahead {
                            if words[skipped].state == .pending {
                                words[skipped].state = .stumbled
                            }
                        }
                        words[ahead].state = .correct
                        words[ahead].recognizedAs = spokenWord
                        sourceIdx = ahead + 1
                        matched = true
                        break
                    }
                }
                if !matched {
                    // Word not found nearby — mark current as stumbled and move on
                    words[sourceIdx].state = .stumbled
                    words[sourceIdx].recognizedAs = spokenWord
                    sourceIdx += 1
                }
            }
        }

        currentIndex = sourceIdx
        // Mark next pending word as active
        if currentIndex < words.count {
            for i in currentIndex..<words.count {
                if words[i].state == .pending { words[i].state = .active; break }
            }
        }

        // Auto-finish when all words are accounted for
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

        // Stop audio
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        timerTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)

        // Mark any remaining pending words as skipped
        for i in 0..<words.count {
            if words[i].state == .pending || words[i].state == .active {
                words[i].state = .skipped
            }
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
            prompt: prompt,
            words: words,
            duration: duration,
            wpm: wpm,
            accuracy: accuracy,
            stumbledWords: stumbled,
            skippedWords: skipped,
            fillerCount: fillerCount
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
    @State private var showPromptPicker = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.07), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            switch engine.phase {
            case .idle:
                PromptSelectionView(
                    selectedPrompt: selectedPrompt,
                    onSelect: { p in
                        selectedPrompt = p
                        engine.load(p)
                    },
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
                if let analysis = engine.analysis {
                    ReadingResultsView(analysis: analysis) {
                        engine.reset()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: engine.phase)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Prompt Selection Screen
// ─────────────────────────────────────────────────────────────

struct PromptSelectionView: View {
    let selectedPrompt: ReadingPrompt?
    let onSelect: (ReadingPrompt) -> Void
    let onStart: () -> Void

    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {

            // ── Hero Header ──────────────────────────────────
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read & Analyze")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Read aloud. Watch every word light up.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.45))
                    }
                    Spacer()
                }

                // How it works — 3 micro-steps
                HStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.0) { i, step in
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(step.color.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Text("\(i+1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(step.color)
                            }
                            Text(step.text)
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.5))
                        }
                        if i < steps.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundColor(Color(white: 0.2))
                                .padding(.horizontal, 8)
                        }
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.07))

            // ── Prompt Cards ─────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    Text("CHOOSE YOUR PASSAGE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Color(white: 0.32))
                        .tracking(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)

                    ForEach(ReadingPrompt.library) { prompt in
                        PromptCard(
                            prompt: prompt,
                            isSelected: selectedPrompt?.id == prompt.id,
                            onTap: { onSelect(prompt) }
                        )
                    }

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 20)
            }
        }
        .overlay(alignment: .bottom) {
            // ── Start Button ─────────────────────────────────
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 30)

                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text(selectedPrompt == nil ? "Pick a passage above" : "Start Reading")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(selectedPrompt == nil ? Color(white: 0.4) : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        selectedPrompt == nil
                            ? AnyShapeStyle(Color.white.opacity(0.08))
                            : AnyShapeStyle(LinearGradient(
                                colors: [.cyan, Color(red: 0.1, green: 0.8, blue: 0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    )
                    .cornerRadius(16)
                    .shadow(color: selectedPrompt != nil ? Color.cyan.opacity(0.35) : .clear, radius: 18, y: 6)
                }
                .disabled(selectedPrompt == nil)
                .animation(.easeInOut(duration: 0.25), value: selectedPrompt?.id)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .background(Color.black.opacity(0.95))
            }
        }
    }

    private let steps = [
        (text: "Pick passage", color: Color.cyan),
        (text: "Read aloud", color: Color.mint),
        (text: "See analysis", color: Color.purple),
    ]
}

// ─────────────────────────────────────────────────────────────
// MARK: - Prompt Card
// ─────────────────────────────────────────────────────────────

struct PromptCard: View {
    let prompt: ReadingPrompt
    let isSelected: Bool
    let onTap: () -> Void

    private var difficultyText: String {
        ["Easy", "Medium", "Advanced"][prompt.difficulty - 1]
    }
    private var difficultyColor: Color {
        [Color.mint, Color.yellow, Color.orange][prompt.difficulty - 1]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    // Category icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(prompt.categoryColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: prompt.categoryIcon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(prompt.categoryColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text(prompt.category)
                            .font(.system(size: 11))
                            .foregroundColor(prompt.categoryColor.opacity(0.75))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(difficultyText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(difficultyColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(difficultyColor.opacity(0.15))
                            .cornerRadius(6)
                        Text("\(prompt.wordCount)w")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.3))
                    }
                }

                // Preview — first ~80 chars
                Text(prompt.text.prefix(90) + "…")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.42))
                    .lineSpacing(3)
                    .lineLimit(2)
            }
            .padding(14)
            .background(
                isSelected
                    ? prompt.categoryColor.opacity(0.1)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? prompt.categoryColor.opacity(0.5) : Color.white.opacity(0.07),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Countdown View
// ─────────────────────────────────────────────────────────────

struct CountdownView: View {
    let count: Int
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("\(count)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .mint], startPoint: .top, endPoint: .bottom)
                )
                .scaleEffect(scale)
                .opacity(opacity)
            Text("Get ready to read…")
                .font(.system(size: 16))
                .foregroundColor(Color(white: 0.5))
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0; opacity = 1.0
            }
        }
        .onChange(of: count) { _ in
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
    @State private var showStopConfirm = false

    // Progress 0→1
    private var progress: Double {
        let done = engine.words.filter { $0.state == .correct || $0.state == .stumbled }.count
        return Double(done) / Double(max(engine.words.count, 1))
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Top bar ──────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reading")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(format: "%.0f%% complete", progress * 100))
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                }
                Spacer()
                HStack(spacing: 12) {
                    // Timer
                    Text(timeStr(engine.elapsedTime))
                        .font(.system(size: 18, design: .monospaced).bold())
                        .foregroundColor(.cyan)
                    // Stop
                    Button {
                        engine.stopEarly()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(white: 0.35))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 52)
            .padding(.bottom, 10)

            // ── Progress bar ─────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // ── Word Flow — the heart of the feature ─────────
            ScrollView(showsIndicators: false) {
                WordFlowView(words: engine.words)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            Spacer()

            // ── Live mic transcript ──────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                        .opacity(0.7)
                    Text("LIVE TRANSCRIPT")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color(white: 0.35))
                        .tracking(1.5)
                }
                Text(engine.liveTranscript.isEmpty ? "Listening…" : engine.liveTranscript)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.55))
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.2), value: engine.liveTranscript)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }

    private func timeStr(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t)/60, Int(t)%60)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Word Flow — real-time highlighted text
// ─────────────────────────────────────────────────────────────

struct WordFlowView: View {
    let words: [ReadWord]

    var body: some View {
        // Wrap words naturally like text using a flow layout
        GeometryReader { geo in
            self.buildFlow(in: geo.size.width)
        }
        .frame(minHeight: 200)
    }

    // Manual flow layout — arrange word chips in rows
    private func buildFlow(in totalWidth: CGFloat) -> some View {
        var rows: [[ReadWord]] = [[]]
        var currentRowWidth: CGFloat = 0
        let spacing: CGFloat = 6
        let font = UIFont.systemFont(ofSize: 18, weight: .medium)

        for word in words {
            let wordWidth = (word.text as NSString)
                .size(withAttributes: [.font: font]).width + 20  // 10px padding each side
            if currentRowWidth + wordWidth + spacing > totalWidth && !rows.last!.isEmpty {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append(word)
            currentRowWidth += wordWidth + spacing
        }

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.0) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { word in
                        WordChip(word: word)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WordChip: View {
    let word: ReadWord

    private var bg: Color {
        switch word.state {
        case .pending:   return Color.white.opacity(0.06)
        case .active:    return Color.cyan.opacity(0.2)
        case .correct:   return Color.mint.opacity(0.18)
        case .stumbled:  return Color.orange.opacity(0.18)
        case .skipped:   return Color.red.opacity(0.15)
        }
    }

    private var fg: Color {
        switch word.state {
        case .pending:   return Color(white: 0.45)
        case .active:    return Color.cyan
        case .correct:   return Color.mint
        case .stumbled:  return Color.orange
        case .skipped:   return Color.red.opacity(0.7)
        }
    }

    private var borderColor: Color {
        switch word.state {
        case .active:   return Color.cyan.opacity(0.7)
        case .correct:  return Color.mint.opacity(0.4)
        case .stumbled: return Color.orange.opacity(0.4)
        case .skipped:  return Color.red.opacity(0.35)
        default:        return Color.clear
        }
    }

    @State private var pulse = false

    var body: some View {
        Text(word.text)
            .font(.system(size: 18, weight: word.state == .active ? .bold : .medium))
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1.5)
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

                // ── Header ───────────────────────────────────
                VStack(spacing: 6) {
                    Text("Reading Complete")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(analysis.prompt.title)
                        .font(.system(size: 13))
                        .foregroundColor(analysis.prompt.categoryColor.opacity(0.8))
                }
                .padding(.top, 52)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                // ── Accuracy Ring ─────────────────────────────
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: 10)
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
                            .foregroundColor(analysis.accuracyColor)
                            .contentTransition(.numericText())
                        Text("Accuracy")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.38))
                        Text(analysis.accuracyBadge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(analysis.accuracyColor)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

                // ── Stat cards ────────────────────────────────
                HStack(spacing: 12) {
                    ResultStatCard(
                        icon: "speedometer",
                        title: "WPM",
                        value: "\(animWPM)",
                        badge: analysis.wpmBadge,
                        color: analysis.wpm >= 120 && analysis.wpm <= 180 ? .mint : .yellow
                    )
                    ResultStatCard(
                        icon: "exclamationmark.bubble",
                        title: "Fillers",
                        value: "\(analysis.fillerCount)",
                        badge: analysis.fillerCount == 0 ? "Flawless" : analysis.fillerCount < 4 ? "Good" : "Noticeable",
                        color: analysis.fillerCount == 0 ? .mint : analysis.fillerCount < 4 ? .yellow : .orange
                    )
                    ResultStatCard(
                        icon: "checkmark.circle",
                        title: "Correct",
                        value: "\(analysis.words.filter { $0.state == .correct }.count)",
                        badge: "of \(analysis.words.count) words",
                        color: .cyan
                    )
                }
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)

                // ── Word map ─────────────────────────────────
                ReadingWordMap(words: analysis.words)
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.55), value: appeared)

                // ── Stumbled words ────────────────────────────
                if !analysis.stumbledWords.isEmpty {
                    WordListCard(
                        title: "Stumbled On",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        words: analysis.stumbledWords,
                        tip: "These words tripped you up — try saying them alone slowly."
                    )
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.65), value: appeared)
                }

                if !analysis.skippedWords.isEmpty {
                    WordListCard(
                        title: "Skipped",
                        icon: "arrow.right.to.line",
                        color: .red,
                        words: analysis.skippedWords,
                        tip: "Skipped words may indicate rushing. Slow down at these spots."
                    )
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.7), value: appeared)
                }

                // ── Try again / New passage ───────────────────
                HStack(spacing: 12) {
                    Button(action: onDone) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Try Again")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.09))
                        .cornerRadius(14)
                    }

                    Button(action: onDone) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                            Text("New Passage")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.cyan, Color(red: 0.1, green: 0.82, blue: 0.85)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                        .shadow(color: .cyan.opacity(0.35), radius: 14, y: 5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: appeared)
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

// ─────────────────────────────────────────────────────────────
// MARK: - Result Sub-components
// ─────────────────────────────────────────────────────────────

struct ResultStatCard: View {
    let icon: String
    let title: String
    let value: String
    let badge: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color.opacity(0.8))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.35))
            Text(badge)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.14))
                .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}

// Mini visual map of the full reading — color-coded by word state
struct ReadingWordMap: View {
    let words: [ReadWord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reading Map")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Every word, colour-coded")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.32))
            }

            // Compact grid of word state dots
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 20), spacing: 3) {
                ForEach(words) { w in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(dotColor(w.state))
                        .frame(height: 10)
                }
            }

            // Legend
            HStack(spacing: 12) {
                MapLegend(color: .mint,            label: "Correct")
                MapLegend(color: .orange,          label: "Stumbled")
                MapLegend(color: .red.opacity(0.7), label: "Skipped")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
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

struct MapLegend: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 10)).foregroundColor(Color(white: 0.4))
        }
    }
}

struct WordListCard: View {
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
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Word chips
            FlowHStack(words: words, color: color)

            Text(tip)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.42))
                .lineSpacing(3)
        }
        .padding(14)
        .background(color.opacity(0.07))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// Simple flow layout for word chips
struct FlowHStack: View {
    let words: [String]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            self.flow(in: geo.size.width)
        }
        .frame(minHeight: 30)
    }

    private func flow(in width: CGFloat) -> some View {
        var rows: [[String]] = [[]]
        var currentW: CGFloat = 0
        let font = UIFont.systemFont(ofSize: 12, weight: .medium)
        for word in words {
            let w = (word as NSString).size(withAttributes: [.font: font]).width + 22
            if currentW + w + 6 > width && !rows.last!.isEmpty {
                rows.append([]); currentW = 0
            }
            rows[rows.count-1].append(word); currentW += w + 6
        }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.0) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { word in
                        Text(word)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}
