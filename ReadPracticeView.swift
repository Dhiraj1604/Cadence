// ReadPracticeView.swift
// Cadence — Read & Speak
//
// FIXES v3:
//   1. CTA "I'm Ready" button is PINNED to bottom — no scrolling needed to reach it.
//      The passage text scrolls inside a bounded ScrollView above.
//
//   2. Silence detection threshold raised significantly:
//      - Waits 8s before starting (not 4s) to let user get going
//      - Requires 6s of silence to auto-stop (not 3s)
//      - Amplitude threshold raised to 0.08 (not 0.12) — more sensitive to voice
//      - Also: `isFinal` auto-stop removed — it triggered too early when iOS
//        paused to send partial results. Now user must tap Done or be silent for 6s.
//
//   3. Results screen action buttons (Try Again / New Passage) are PINNED to bottom.

import SwiftUI
import Speech
import AVFoundation

// MARK: - Models

struct ReadingPrompt: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let icon: String
    let color: Color
    let text: String
    let difficulty: Int
    let tip: String

    var wordCount: Int { text.split(separator: " ").count }

    static let library: [ReadingPrompt] = [

        // ── EASY ──────────────────────────────────────────────────────
        ReadingPrompt(
            title: "The Courage to Begin",
            category: "Motivation",
            icon: "flame.fill",
            color: .orange,
            text: "The gap between where you are and where you want to be is crossed by a single act — beginning. Most people wait for the right moment, the right conditions, the right plan. But clarity never comes before action. It only comes from action. Start before you feel ready. Start before you feel confident. The confidence you are waiting for is built through doing, not through planning. Every person you admire was once a complete beginner who simply refused to quit.",
            difficulty: 1,
            tip: "Speak each sentence as if you are convincing someone. Let your voice carry conviction on 'begin', 'action' and 'refused'."
        ),

        ReadingPrompt(
            title: "The Art of Listening",
            category: "Communication",
            icon: "ear.fill",
            color: .cyan,
            text: "Most people listen to reply, not to understand. Real listening means setting aside your own thoughts and giving complete attention to the speaker. Notice their tone, their pauses, and the emotion behind the words. Ask questions that show you were paying attention, not questions that redirect the conversation back to yourself. A single conversation where someone feels truly heard can change the entire relationship. Listening is the rarest and most powerful gift you can give another person.",
            difficulty: 1,
            tip: "This passage has a conversational rhythm. Aim for 130–145 WPM. Slow down slightly on 'rarest and most powerful gift'."
        ),

        ReadingPrompt(
            title: "Why Sleep Matters",
            category: "Health",
            icon: "moon.zzz.fill",
            color: .indigo,
            text: "During sleep, the brain replays the events of the day, consolidating memories and clearing out waste products that accumulate during waking hours. A single night of poor sleep reduces focus, slows reaction time, and elevates stress hormones. Adults who consistently sleep fewer than seven hours per night face significantly higher risks of heart disease, depression, and weight gain. Sleep is not laziness. It is the most productive thing your body does every single day.",
            difficulty: 1,
            tip: "The final two short sentences are your punchline. Pause for half a second before 'Sleep is not laziness' to let it land."
        ),

        // ── MEDIUM ────────────────────────────────────────────────────
        ReadingPrompt(
            title: "The Power of Compounding",
            category: "Finance",
            icon: "chart.line.uptrend.xyaxis",
            color: .green,
            text: "Albert Einstein reportedly called compound interest the eighth wonder of the world. The principle is simple: returns generate their own returns, and over long periods, even modest growth becomes extraordinary. A thousand dollars invested at eight percent annually doubles roughly every nine years. Over forty years, that thousand becomes nearly twenty-two thousand — without adding a single extra dollar. The same principle applies to skills, habits, and knowledge. Small consistent improvements, compounded over years, produce results that look miraculous from the outside.",
            difficulty: 2,
            tip: "Numbers slow most speakers down. Practise 'eight percent annually' and 'twenty-two thousand' smoothly before the full passage."
        ),

        ReadingPrompt(
            title: "How the Internet Was Born",
            category: "Technology",
            icon: "network",
            color: Color(red: 0.2, green: 0.7, blue: 1.0),
            text: "In 1969, four computers at American universities were connected by a network called ARPANET. The researchers who built it were not thinking about email or social media. They wanted a communications system that could survive a nuclear strike by rerouting data around damaged nodes. That humble network of four machines eventually grew into a global infrastructure connecting five billion people. No committee planned it. No single company built it. It grew organically, shaped by millions of decisions made by engineers who simply wanted to solve the problem in front of them.",
            difficulty: 2,
            tip: "Historical passages work well at a storytelling pace — 125 to 140 WPM. Drop your pitch slightly on 'nuclear strike' for impact."
        ),

        ReadingPrompt(
            title: "Emotional Intelligence",
            category: "Psychology",
            icon: "brain.head.profile",
            color: .purple,
            text: "IQ predicts about twenty percent of career success. The remaining eighty percent is explained by emotional intelligence — the ability to recognise, understand and manage emotions in yourself and others. People with high emotional intelligence recover from setbacks faster, build stronger relationships, and make more thoughtful decisions under pressure. The good news is that unlike IQ, emotional intelligence is not fixed at birth. It can be learned, practised and deliberately improved at any age. Self-awareness is the foundation. Everything else is built on top of it.",
            difficulty: 2,
            tip: "The statistics set up the argument. Speak them clearly and confidently — they are your evidence."
        ),

        ReadingPrompt(
            title: "The Pale Blue Dot",
            category: "Science",
            icon: "globe.americas.fill",
            color: .blue,
            text: "From six billion kilometres away, Earth appears as a tiny point of pale blue light — a fraction of a pixel suspended in a sunbeam. That tiny speck is home. On it, every human who ever lived, every king and peasant, every inventor and explorer, every act of courage and cowardice, every civilisation that ever rose and fell. Our planet is a very small stage in a vast cosmic arena. The universe does not owe us significance. We must create it ourselves — through connection, through curiosity, through the choices we make each day.",
            difficulty: 2,
            tip: "This is poetic and reflective. Slow to 120–135 WPM. The final sentence deserves a deliberate, measured delivery."
        ),

        // ── ADVANCED ──────────────────────────────────────────────────
        ReadingPrompt(
            title: "Artificial General Intelligence",
            category: "Technology",
            icon: "cpu.fill",
            color: Color.cadenceAccent,
            text: "Modern artificial intelligence systems excel at narrow tasks — recognising faces, translating languages, predicting protein structures — but they have no genuine understanding of the world. They are sophisticated pattern matchers trained on human-generated data. Artificial General Intelligence, the ability to reason flexibly across domains the way humans do, remains an unsolved problem. Some researchers believe it is decades away. Others argue it may require entirely new paradigms beyond current deep learning architectures. What is certain is that the transition, whenever it comes, will be the most consequential technological event in human history.",
            difficulty: 3,
            tip: "Practise 'architectures', 'paradigms' and 'consequential' before recording. Aim for 130–150 WPM."
        ),

        ReadingPrompt(
            title: "The Case for Failure",
            category: "Business",
            icon: "arrow.up.forward.and.arrow.down.backward",
            color: .yellow,
            text: "Most successful companies were built on the ruins of earlier failures. Amazon lost hundreds of millions on its Fire Phone. Apple released the Newton, a product so ridiculed it inspired a decade of jokes. Google launched Buzz, Wave, and Glass — none survived. The pattern is not accidental. Companies that never fail are companies that never take risks. Risk avoidance optimises for short-term survival at the cost of long-term relevance. The organisations that endure are those that treat failure as a data point — expensive, occasionally humiliating, but always instructive.",
            difficulty: 3,
            tip: "The list of failed products works best with a slight upward inflection on each, then a drop when you pivot to the lesson."
        ),

        ReadingPrompt(
            title: "On Persuasion",
            category: "Communication",
            icon: "megaphone.fill",
            color: .red,
            text: "Aristotle identified three pillars of persuasion: ethos, the credibility of the speaker; pathos, the emotional connection to the audience; and logos, the logic of the argument. Most business communication relies almost entirely on logos — data, charts, bullet points. Yet research consistently shows that people make decisions emotionally and justify them rationally. A speaker who opens with a statistic competes for attention. A speaker who opens with a story commands it. The most effective communicators do not choose between logic and emotion. They understand that emotion is the vehicle and logic is the cargo.",
            difficulty: 3,
            tip: "Slow down on 'ethos', 'pathos' and 'logos'. The final metaphor deserves a full beat of silence before delivery."
        ),

        ReadingPrompt(
            title: "Cities and Innovation",
            category: "Urbanisation",
            icon: "building.2.fill",
            color: .teal,
            text: "For most of human history, the vast majority of people lived in small isolated communities. Knowledge was local. Innovation was slow. Then cities emerged, and everything accelerated. When people cluster together, ideas collide. A carpenter meets a metallurgist. A merchant funds an inventor. Proximity creates the conditions for combination — and combination is the engine of progress. Today, more than half the world's population lives in cities. The urban share is rising, and with it, the pace of discovery. The city is not just a place to live. It is humanity's most powerful invention for generating new ideas.",
            difficulty: 2,
            tip: "This passage builds in energy. Start calm and deliberate, and let your pace gradually increase toward the final sentence."
        ),

        ReadingPrompt(
            title: "The Feedback Loop",
            category: "Psychology",
            icon: "arrow.triangle.2.circlepath",
            color: .pink,
            text: "Progress in any skill follows the same hidden structure: attempt, observe, adjust, repeat. Most people attempt and move on without the observe step. Without honest observation, you cannot adjust, and without adjustment, repetition simply reinforces existing errors. Deliberate practice, as defined by researcher Anders Ericsson, is not the same as mere repetition. It requires immediate, specific feedback on performance and a willingness to sit in the discomfort of repeated failure just outside your current ability. The musicians, athletes, and professionals who reach the top are not more talented. They are more honest about their own weaknesses.",
            difficulty: 3,
            tip: "The phrase 'attempt, observe, adjust, repeat' is your anchor. Deliver it slowly — one word per beat — so it sticks."
        ),
    ]
}

// MARK: - Analysis Result

struct ReadingAnalysisResult {
    let wpm: Int
    let fillerCount: Int
    let fillerWords: [String]
    let accuracyPercent: Double
    let missedWords: [String]
    let rhythmStability: Double
    let duration: TimeInterval
    let transcript: String

    var wpmBadge: String {
        switch wpm {
        case 130...155: return "Ideal Pace"
        case 110..<130: return "Slightly Slow"
        case 155..<175: return "Slightly Fast"
        case 0:         return "No Speech"
        default:        return wpm > 175 ? "Too Fast" : "Too Slow"
        }
    }
    var wpmColor: Color {
        switch wpm {
        case 120...165: return Color.cadenceGood
        case 95..<120, 165..<185: return Color.cadenceNeutral
        case 0: return Color.white.opacity(0.3)
        default: return Color.cadenceWarn
        }
    }
    var accuracyBadge: String {
        switch accuracyPercent {
        case 95...100: return "Excellent"
        case 85..<95:  return "Strong"
        case 70..<85:  return "Decent"
        default:       return "Needs Work"
        }
    }
    var accuracyColor: Color {
        switch accuracyPercent {
        case 85...100: return Color.cadenceGood
        case 65..<85:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }
}

// MARK: - Reading Engine

@MainActor
class ReadingEngine: ObservableObject {

    enum Phase: Equatable {
        case browsing
        case preparing
        case countdown
        case recording
        case analyzing
        case results
    }

    @Published var phase: Phase = .browsing
    @Published var selectedPrompt: ReadingPrompt?
    @Published var countdown: Int = 3
    @Published var elapsedTime: TimeInterval = 0
    @Published var liveTranscript: String = ""
    @Published var isListening: Bool = false
    @Published var analysisResult: ReadingAnalysisResult?
    @Published var amplitude: CGFloat = 0.0

    private let speechRecognizer: SFSpeechRecognizer? = {
        // Prefer the device's current locale if SFSpeechRecognizer supports it.
        // This ensures Apple testers (en-US), international users (en-GB, en-AU,
        // en-IN, etc.) all get the best possible transcription accuracy.
        // Falls back through a chain of English locales → en-US as last resort.
        let preferred = [
            Locale.current,
            Locale(identifier: "en-\(Locale.current.region?.identifier ?? "US")"),
            Locale(identifier: "en-GB"),
            Locale(identifier: "en-AU"),
            Locale(identifier: "en-IN"),
            Locale(identifier: "en-US")
        ]
        for locale in preferred {
            if let recognizer = SFSpeechRecognizer(locale: locale),
               recognizer.isAvailable {
                return recognizer
            }
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var startDate: Date?
    private var timerTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var silenceCheckTask: Task<Void, Never>?
    private var segmentTimestamps: [TimeInterval] = []

    // Silence detection state — written from main thread only
    private var lastVoiceActivityTime: Date = Date()

    // Tier 1: Always fillers — every occurrence counts
    private let hardFillerWords: Set<String> = [
        "um", "uh", "er", "hmm", "uhh", "umm", "erm"
    ]

    // Tier 2: Context-dependent — only flagged when rate exceeds threshold per minute
    private let contextFillerThresholds: [String: Double] = [
        "like":      1.5,
        "so":        2.0,
        "right":     1.5,
        "okay":      1.5,
        "ok":        1.5,
        "actually":  1.0,
        "basically": 1.0,
        "literally": 0.8,
        "anyway":    1.0,
        "honestly":  1.0,
        "seriously": 0.8
    ]

    // MARK: - Public

    func selectPrompt(_ prompt: ReadingPrompt) {
        selectedPrompt = prompt
        phase = .preparing
    }

    func startCountdown() {
        guard selectedPrompt != nil else { return }
        phase = .countdown
        countdown = 3
        countdownTask?.cancel()
        countdownTask = Task {
            for i in stride(from: 3, through: 1, by: -1) {
                if Task.isCancelled { return }
                await MainActor.run { self.countdown = i }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            if !Task.isCancelled {
                await MainActor.run { self.beginRecording() }
            }
        }
    }

    func stopRecording() {
        finishRecording()
    }

    func reset() {
        stopAll()
        liveTranscript = ""; elapsedTime = 0; amplitude = 0
        analysisResult = nil; isListening = false; segmentTimestamps = []
        phase = .browsing
    }

    func tryAgain() {
        stopAll()
        liveTranscript = ""; elapsedTime = 0; amplitude = 0
        analysisResult = nil; isListening = false; segmentTimestamps = []
        phase = selectedPrompt != nil ? .preparing : .browsing
    }

    // MARK: - Recording

    private func beginRecording() {
        phase = .recording
        startDate = Date()
        elapsedTime = 0; liveTranscript = ""
        segmentTimestamps = []; isListening = true
        lastVoiceActivityTime = Date()

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    self.elapsedTime = Date().timeIntervalSince(self.startDate ?? Date())
                }
            }
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized, let self = self else { return }
            DispatchQueue.main.async { self.startSpeechEngine() }
        }
    }

    private func startSpeechEngine() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // NOTE: requiresOnDeviceRecognition = false allows server-side recognition
        // which is MORE continuous and less prone to early termination than on-device.
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16, *) { request.addsPunctuation = false }
        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    self.liveTranscript = result.bestTranscription.formattedString
                    let ts = result.bestTranscription.segments.map { $0.timestamp }
                    if ts.count > self.segmentTimestamps.count { self.segmentTimestamps = ts }
                    // Mark voice activity whenever we get new transcription
                    if !result.bestTranscription.formattedString.isEmpty {
                        self.lastVoiceActivityTime = Date()
                    }
                }
                // IMPORTANT: Do NOT auto-finish on isFinal or on errors.
                // iOS fires isFinal mid-sentence when it pauses briefly — this was
                // causing the early cutoff. We only finish via silence detection or
                // the user tapping Done.
            }
        }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
            guard let channelData = buf.floatChannelData?[0] else { return }
            let frames = Int(buf.frameLength); guard frames > 0 else { return }
            var sum: Float = 0.0
            for i in 0..<frames { sum += channelData[i] * channelData[i] }
            let rms = sqrt(sum / Float(frames))
            let amp = min(max(CGFloat(rms) * 5.0, 0.0), 1.0)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.amplitude = self.amplitude * 0.7 + amp * 0.3
                // Lower threshold (0.08 vs 0.12) = more sensitive = catches quieter voices
                if amp > 0.08 {
                    self.lastVoiceActivityTime = Date()
                }
            }
        }
        audioEngine.prepare()
        try? audioEngine.start()

        // Start silence detection after engine is running
        startSilenceDetection()
    }

    /// Auto-stop after 6 continuous seconds of silence, but only after user has spoken.
    /// Waits 8 seconds before even checking so user has time to find their voice.
    private func startSilenceDetection() {
        silenceCheckTask?.cancel()
        silenceCheckTask = Task {
            // Grace period — don't check for silence during the first 8 seconds
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let now = Date()
                let silenceDuration = await MainActor.run {
                    now.timeIntervalSince(self.lastVoiceActivityTime)
                }
                let hasSpoken = await MainActor.run { !self.liveTranscript.isEmpty }
                // Only auto-stop if: user has spoken AND silence > 6 seconds
                if hasSpoken && silenceDuration > 6.0 {
                    await MainActor.run { self.finishRecording() }
                    return
                }
            }
        }
    }

    private func finishRecording() {
        guard phase == .recording else { return }
        silenceCheckTask?.cancel()
        timerTask?.cancel()
        stopAudioEngine()
        phase = .analyzing

        let transcript = liveTranscript
        let elapsed    = elapsedTime
        let timestamps = segmentTimestamps
        let prompt     = selectedPrompt

        Task {
            let result = await analyzeReading(
                transcript: transcript,
                duration: elapsed,
                segmentTimestamps: timestamps,
                prompt: prompt
            )
            await MainActor.run {
                self.analysisResult = result
                self.phase = .results
            }
        }
    }

    private func stopAll() {
        countdownTask?.cancel(); timerTask?.cancel(); silenceCheckTask?.cancel()
        stopAudioEngine()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil; recognitionTask = nil
    }

    // MARK: - Analysis

    private func analyzeReading(
        transcript: String,
        duration: TimeInterval,
        segmentTimestamps: [TimeInterval],
        prompt: ReadingPrompt?
    ) async -> ReadingAnalysisResult {

        let words = transcript.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            .map { $0.components(separatedBy: CharacterSet.letters.inverted).joined() }
            .filter { !$0.isEmpty }

        let mins = max(duration / 60.0, 0.1)

        // Tier 1: hard fillers — every occurrence counts
        let hardFillers = words.filter { hardFillerWords.contains($0) }

        // Tier 2: context words — only count occurrences that exceed the allowed rate
        var contextFillerWords: [String] = []
        for (word, allowedPerMin) in contextFillerThresholds {
            let count = words.filter { $0 == word }.count
            let rate = Double(count) / mins
            if rate > allowedPerMin {
                // Number of excess occurrences beyond the allowed rate
                let allowed = Int(allowedPerMin * mins)
                let excess  = max(0, count - allowed)
                contextFillerWords.append(contentsOf: Array(repeating: word, count: excess))
            }
        }

        let allFillers     = hardFillers + contextFillerWords
        // WPM excludes only hard fillers (um/uh etc.) — context words are real speech
        let nonFillerWords = words.filter { !hardFillerWords.contains($0) }
        let wpm            = Int(Double(nonFillerWords.count) / mins)

        var accuracyPercent = 100.0
        var missedWords: [String] = []
        if let prompt = prompt {
            let passageWords = prompt.text.lowercased()
                .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                .map { $0.components(separatedBy: CharacterSet.letters.inverted).joined() }
                .filter { !$0.isEmpty }

            var matchedCount = 0
            for passWord in passageWords {
                if words.contains(where: { fuzzyMatch($0, passWord) }) {
                    matchedCount += 1
                } else {
                    missedWords.append(passWord)
                }
            }
            if !passageWords.isEmpty {
                accuracyPercent = Double(matchedCount) / Double(passageWords.count) * 100.0
            }
        }

        var rhythmStability = -1.0
        if segmentTimestamps.count >= 8 {
            let window = Array(segmentTimestamps.suffix(60))
            var gaps: [Double] = []
            for i in 1..<window.count {
                let gap = window[i] - window[i-1]
                if gap >= 0.05 && gap <= 1.5 { gaps.append(gap) }
            }
            if gaps.count >= 5 {
                let mean = gaps.reduce(0, +) / Double(gaps.count)
                if mean > 0 {
                    let stdDev = sqrt(gaps.map { pow($0 - mean, 2) }.reduce(0, +) / Double(gaps.count))
                    let cv = stdDev / mean
                    rhythmStability = max(5.0, min(100.0, 100.0 - (cv * 65.0)))
                }
            }
        }

        return ReadingAnalysisResult(
            wpm: wpm, fillerCount: allFillers.count, fillerWords: allFillers,
            accuracyPercent: accuracyPercent,
            missedWords: Array(missedWords.prefix(15)),
            rhythmStability: rhythmStability,
            duration: duration, transcript: transcript
        )
    }

    private func fuzzyMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.count < 3 || b.count < 3 { return a == b }
        let shorter = a.count < b.count ? a : b
        let longer  = a.count < b.count ? b : a
        if longer.hasPrefix(shorter) && Double(shorter.count) / Double(longer.count) >= 0.80 { return true }
        let maxDist = longer.count <= 6 ? 1 : 2
        return levenshtein(a, b) <= maxDist
    }

    private func levenshtein(_ s: String, _ t: String) -> Int {
        let s = Array(s), t = Array(t)
        let m = s.count, n = t.count
        if m == 0 { return n }; if n == 0 { return m }
        var prev = Array(0...n)
        for i in 1...m {
            var curr = [i] + Array(repeating: 0, count: n)
            for j in 1...n {
                curr[j] = s[i-1] == t[j-1]
                    ? prev[j-1]
                    : 1 + Swift.min(prev[j-1], Swift.min(prev[j], curr[j-1]))
            }
            prev = curr
        }
        return prev[n]
    }
}

// MARK: - Main View

struct ReadPracticeView: View {
    @StateObject private var engine = ReadingEngine()

    var body: some View {
        ZStack {
            Color.cadenceBG.ignoresSafeArea()
            Group {
                switch engine.phase {
                case .browsing:
                    PassageBrowserView(engine: engine).transition(.opacity)
                case .preparing:
                    PassagePrepView(engine: engine)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                case .countdown:
                    ReadCountdownView(count: engine.countdown)
                        .transition(.scale.combined(with: .opacity))
                case .recording:
                    RecordingView(engine: engine).transition(.opacity)
                case .analyzing:
                    AnalyzingView().transition(.opacity)
                case .results:
                    ReadResultsView(engine: engine)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.phase)
    }
}

// MARK: - Passage Browser

struct PassageBrowserView: View {
    @ObservedObject var engine: ReadingEngine

    private var easyPrompts:  [ReadingPrompt] { ReadingPrompt.library.filter { $0.difficulty == 1 } }
    private var mediumPrompts: [ReadingPrompt] { ReadingPrompt.library.filter { $0.difficulty == 2 } }
    private var hardPrompts:  [ReadingPrompt] { ReadingPrompt.library.filter { $0.difficulty == 3 } }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.cyan).symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Read & Analyse")
                            .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        Text("Read a passage aloud — get instant feedback")
                            .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
                Divider().background(Color.white.opacity(0.07))
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    promptSection("Easy", color: .mint, prompts: easyPrompts)
                    promptSection("Medium", color: .yellow, prompts: mediumPrompts)
                    promptSection("Advanced", color: .orange, prompts: hardPrompts)
                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
        }
    }

    private func promptSection(_ title: String, color: Color, prompts: [ReadingPrompt]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color.opacity(0.7))
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
            VStack(spacing: 8) {
                ForEach(prompts) { p in
                    PromptCard(prompt: p) { engine.selectPrompt(p) }.padding(.horizontal, 16)
                }
            }
        }
    }
}

struct PromptCard: View {
    let prompt: ReadingPrompt
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(prompt.color.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: prompt.icon).font(.system(size: 18, weight: .medium))
                        .foregroundStyle(prompt.color).symbolRenderingMode(.hierarchical)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(prompt.category).font(.system(size: 12)).foregroundStyle(prompt.color.opacity(0.75))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(prompt.wordCount)w").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.35))
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Passage Prep View
// FIX 1: CTA button is pinned to the bottom of the screen.
// The passage text scrolls in a bounded ScrollView above — no need to scroll to the button.

struct PassagePrepView: View {
    @ObservedObject var engine: ReadingEngine
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Fixed top bar ─────────────────────────────────────────
            HStack {
                Button { engine.reset() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("Passages").font(.system(size: 15))
                    }
                    .foregroundStyle(Color.mint)
                }
                Spacer()
                if let p = engine.selectedPrompt {
                    Text("\(p.wordCount) words")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 10)

            if let prompt = engine.selectedPrompt {

                // ── Passage title row ─────────────────────────────────
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9).fill(prompt.color.opacity(0.14)).frame(width: 36, height: 36)
                        Image(systemName: prompt.icon).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(prompt.color).symbolRenderingMode(.hierarchical)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(prompt.title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        Text(prompt.category).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.05), value: appeared)

                // ── Scrollable passage text — bounded height ──────────
                // Gives the text ~55% of screen height so the button is always visible
                ScrollView(showsIndicators: false) {
                    Text(prompt.text)
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                .frame(maxHeight: 320)
                .background(Color.cadenceCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(prompt.color.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.08), value: appeared)

                // ── Coaching tip ──────────────────────────────────────
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill").font(.system(size: 12))
                        .foregroundStyle(.yellow).padding(.top, 2)
                    Text(prompt.tip)
                        .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.55))
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Color.yellow.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.14), value: appeared)

                Spacer(minLength: 12)

                // ── Instructions ──────────────────────────────────────
                HStack(spacing: 0) {
                    instructionPill("1", "Read silently")
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.2))
                    Spacer()
                    instructionPill("2", "Tap Ready")
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.2))
                    Spacer()
                    instructionPill("3", "Speak clearly")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.2), value: appeared)

                // ── CTA PINNED TO BOTTOM — always visible ─────────────
                Button(action: { engine.startCountdown() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill").font(.system(size: 15, weight: .semibold))
                        Text("I'm Ready — Start Recording").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LinearGradient(colors: [.cyan, Color.cadenceAccent],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.cyan.opacity(0.30), radius: 14, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.25), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    private func instructionPill(_ num: String, _ text: String) -> some View {
        VStack(spacing: 5) {
            Text(num).font(.system(size: 11, weight: .black)).foregroundStyle(.black)
                .frame(width: 20, height: 20).background(Color.mint).clipShape(Circle())
            Text(text).font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.4))
        }
    }
}

// MARK: - Countdown

struct ReadCountdownView: View {
    let count: Int
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("\(count)")
                .font(.system(size: 110, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.cyan, Color.cadenceAccent], startPoint: .top, endPoint: .bottom))
                .scaleEffect(scale).opacity(opacity)
            Text("Get ready to speak…").font(.system(size: 15)).foregroundStyle(Color.white.opacity(0.4))
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { scale = 1; opacity = 1 }
        }
        .onChange(of: count) { _, _ in
            scale = 0.4; opacity = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { scale = 1; opacity = 1 }
        }
    }
}

// MARK: - Recording View

struct RecordingView: View {
    @ObservedObject var engine: ReadingEngine

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Speaking").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                        Label("REC", systemImage: "record.circle")
                            .font(.caption2.weight(.black)).foregroundStyle(Color.red)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.red.opacity(0.12)).clipShape(Capsule())
                    }
                    Text(timeStr(engine.elapsedTime))
                        .font(.system(.title, design: .monospaced, weight: .bold))
                        .foregroundStyle(LinearGradient.cadencePrimary)
                }
                Spacer()
                Button { engine.stopRecording() } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(LinearGradient(colors: [.cyan, Color.cadenceAccent],
                            startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20).padding(.top, 56).padding(.bottom, 12)

            // ── Passage reference (scrollable, compact) ───────────────
            if let prompt = engine.selectedPrompt {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: prompt.icon).font(.system(size: 11)).foregroundStyle(prompt.color)
                        Text(prompt.title).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    ScrollView(showsIndicators: false) {
                        Text(prompt.text)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(Color.white.opacity(0.80))
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 240)
                }
                .padding(14)
                .background(Color.cadenceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(prompt.color.opacity(0.20), lineWidth: 1))
                .padding(.horizontal, 20)
            }

            Spacer()

            // ── Live waveform ─────────────────────────────────────────
            LiveReadWaveform(amplitude: engine.amplitude)
                .padding(.horizontal, 20).padding(.bottom, 10)

            // ── Live transcript / listening indicator ─────────────────
            if !engine.liveTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 5, height: 5)
                        Text("Transcribing").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            Text(engine.liveTranscript)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("readTranscriptEnd")
                        }
                        .frame(maxHeight: 52)
                        .onChange(of: engine.liveTranscript) { _, _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("readTranscriptEnd", anchor: .bottom)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.cadenceCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20).padding(.bottom, 10)
            } else {
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 5, height: 5)
                        .opacity(engine.elapsedTime.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.4)
                    Text("Listening for your voice…").font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.28))
                }
                .padding(.bottom, 10)
            }

            Text("Tap Done or pause for 6 seconds to finish")
                .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.18))
                .padding(.bottom, 36)
        }
    }

    private func timeStr(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

struct LiveReadWaveform: View {
    let amplitude: CGFloat
    @State private var samples: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var timer: Timer?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(samples.enumerated()), id: \.0) { _, s in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cadenceAccent.opacity(0.3 + s * 0.7))
                    .frame(width: 5, height: max(4, s * 44 + 4))
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.65), value: s)
            }
        }
        .frame(height: 52).frame(maxWidth: .infinity)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                samples.removeFirst()
                samples.append(amplitude + CGFloat.random(in: -0.04...0.04))
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

// MARK: - Analyzing

struct AnalyzingView: View {
    @State private var rotation: Double = 0
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.mint.opacity(0.15), lineWidth: 3).frame(width: 72, height: 72)
                Circle().trim(from: 0, to: 0.7)
                    .stroke(LinearGradient(colors: [Color.mint, Color.cyan], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 72, height: 72).rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { rotation = 360 }
                    }
                Image(systemName: "waveform.path.ecg").font(.system(size: 22, weight: .light)).foregroundStyle(Color.mint)
            }
            Text("Analysing your speech…").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Text("Comparing against the passage").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.35))
        }
    }
}

// MARK: - Results View
// FIX 3: Action buttons are pinned to bottom — always visible without scrolling.

struct ReadResultsView: View {
    @ObservedObject var engine: ReadingEngine
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Scrollable results content ────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    VStack(spacing: 5) {
                        Text("Reading Complete")
                            .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                        if let prompt = engine.selectedPrompt {
                            Text(prompt.title).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 44)
                    .staggerIn(appeared, delay: 0.05)

                    if let result = engine.analysisResult {

                        // Score cards
                        HStack(spacing: 10) {
                            ReadScoreCard(icon: "speedometer", label: "WPM",
                                value: result.wpm == 0 ? "—" : "\(result.wpm)",
                                badge: result.wpmBadge, color: result.wpmColor)
                            ReadScoreCard(icon: "text.badge.checkmark", label: "Accuracy",
                                value: String(format: "%.0f%%", result.accuracyPercent),
                                badge: result.accuracyBadge, color: result.accuracyColor)
                            ReadScoreCard(icon: "exclamationmark.bubble.fill", label: "Fillers",
                                value: "\(result.fillerCount)",
                                badge: result.fillerCount == 0 ? "Flawless" : result.fillerCount < 4 ? "Good" : "Too many",
                                color: result.fillerCount == 0 ? Color.cadenceGood : result.fillerCount < 4 ? Color.cadenceNeutral : Color.cadenceBad)
                        }
                        .padding(.horizontal, 20).padding(.top, 20)
                        .staggerIn(appeared, delay: 0.10)

                        // Rhythm
                        if result.rhythmStability >= 0 {
                            RhythmBar(stability: result.rhythmStability)
                                .padding(.horizontal, 20).padding(.top, 12)
                                .staggerIn(appeared, delay: 0.17)
                        }

                        // Coaching tip
                        if let tip = coachingTip(for: result, prompt: engine.selectedPrompt) {
                            coachTipCard(tip)
                                .padding(.horizontal, 20).padding(.top, 12)
                                .staggerIn(appeared, delay: 0.23)
                        }

                        // Missed words
                        if !result.missedWords.isEmpty {
                            missedWordsCard(result.missedWords)
                                .padding(.horizontal, 20).padding(.top, 12)
                                .staggerIn(appeared, delay: 0.29)
                        }

                        // Filler breakdown
                        if result.fillerCount > 0 {
                            fillerCard(result)
                                .padding(.horizontal, 20).padding(.top, 12)
                                .staggerIn(appeared, delay: 0.33)
                        }

                        // Transcript
                        if !result.transcript.isEmpty {
                            VStack(alignment: .leading, spacing: 7) {
                                Label("What We Heard", systemImage: "text.quote")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Text(result.transcript)
                                    .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.6))
                                    .lineSpacing(4)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 20).padding(.top, 12)
                            .staggerIn(appeared, delay: 0.37)
                        }

                        // Bottom padding so content clears the pinned buttons
                        Color.clear.frame(height: 24)
                    }
                }
            }

            // ── Pinned action buttons — always visible ─────────────────
            VStack(spacing: 0) {
                // Fade gradient so it looks natural
                LinearGradient(colors: [Color.cadenceBG.opacity(0), Color.cadenceBG],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)

                HStack(spacing: 12) {
                    Button(action: { engine.tryAgain() }) {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: { engine.reset() }) {
                        Label("New Passage", systemImage: "doc.text.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(LinearGradient(colors: [.cyan, Color.cadenceAccent],
                                startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .cyan.opacity(0.25), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
                .background(Color.cadenceBG)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Coaching logic

    private func coachingTip(for result: ReadingAnalysisResult, prompt: ReadingPrompt?)
        -> (icon: String, color: Color, title: String, message: String)? {
        if result.wpm > 175 {
            return ("hare.fill", Color.cadenceNeutral, "Slow Down",
                "At \(result.wpm) WPM you're outrunning your audience. Aim for 130–155 WPM for maximum clarity.")
        }
        if result.wpm > 0 && result.wpm < 100 {
            return ("tortoise.fill", Color.cadenceNeutral, "Pick Up the Pace",
                "\(result.wpm) WPM is too slow. Try again — aim for a natural conversation speed.")
        }
        if result.fillerCount >= 4 {
            return ("exclamationmark.bubble.fill", Color.cadenceWarn, "Watch the Fillers",
                "\(result.fillerCount) filler words detected. Replace each one with a clean pause.")
        }
        if result.accuracyPercent < 70 {
            return ("doc.text.magnifyingglass", Color.cyan, "Read More Closely",
                "We matched \(Int(result.accuracyPercent))% of the passage. Try again — read each word clearly.")
        }
        if result.rhythmStability >= 0 && result.rhythmStability < 50 {
            return ("waveform.path", Color.cadenceWarn, "Even Out Your Rhythm",
                "Your pacing was uneven. Try placing a short breath between each sentence.")
        }
        if result.wpm >= 120 && result.wpm <= 160 && result.fillerCount <= 2 && result.accuracyPercent >= 85 {
            return ("star.fill", Color.cadenceGood, "Excellent Delivery",
                "Ideal pace, few fillers, high accuracy. Try a more challenging passage next.")
        }
        return nil
    }

    private func coachTipCard(_ tip: (icon: String, color: Color, title: String, message: String)) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tip.icon).font(.title3).foregroundStyle(tip.color)
                .symbolRenderingMode(.hierarchical).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(tip.message).font(.subheadline).foregroundStyle(Color.white.opacity(0.55)).lineSpacing(2)
            }
        }
        .padding(14).background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tip.color.opacity(0.22), lineWidth: 1))
    }

    private func missedWordsCard(_ words: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.badge.xmark").font(.system(size: 12)).foregroundStyle(Color.cadenceWarn)
                Text("Words You Skipped or Mispronounced")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            FlowLayout(items: words) { word in
                Text(word).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.cadenceWarn)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.cadenceWarn.opacity(0.10)).clipShape(Capsule())
            }
            Text("Practise these words slowly, then re-read the passage.")
                .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(14)
        .background(Color.cadenceWarn.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cadenceWarn.opacity(0.15), lineWidth: 1))
    }

    private func fillerCard(_ result: ReadingAnalysisResult) -> some View {
        var freq: [String: Int] = [:]
        for w in result.fillerWords { freq[w, default: 0] += 1 }
        let sorted = freq.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.bubble.fill").font(.system(size: 12)).foregroundStyle(Color.cadenceWarn)
                Text("\(result.fillerCount) filler word\(result.fillerCount == 1 ? "" : "s") detected")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            FlowLayout(items: sorted.map { "\"\($0.key)\" ×\($0.value)" }) { label in
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.cadenceWarn)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.cadenceWarn.opacity(0.10)).clipShape(Capsule())
            }
        }
        .padding(14).background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cadenceWarn.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Read Score Card

struct ReadScoreCard: View {
    let icon: String; let label: String; let value: String; let badge: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(color).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.4))
            Text(badge).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(color.opacity(0.13)).clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Rhythm Bar

struct RhythmBar: View {
    let stability: Double
    @State private var appeared = false

    private var color: Color {
        stability >= 75 ? Color.cadenceGood : stability >= 50 ? Color.cadenceNeutral : Color.cadenceWarn
    }
    private var label: String {
        switch stability {
        case 85...100: return "Consistent"
        case 70..<85:  return "Steady"
        case 55..<70:  return "Decent"
        case 40..<55:  return "Uneven"
        default:       return "Choppy"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Rhythm Stability", systemImage: "waveform.path")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.12)).clipShape(Capsule())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 7)
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(appeared ? stability / 100.0 : 0), height: 7)
                        .animation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.3), value: appeared)
                }
            }
            .frame(height: 7)
        }
        .padding(14).background(Color.cadenceCard).clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear { appeared = true }
    }
}

// MARK: - Flow Layout

struct FlowLayout<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    @ViewBuilder let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            generateContent(in: geo).background(HeightReader(height: $totalHeight))
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var rows: [[Data.Element]] = [[]]
        for item in items {
            let itemWidth = estimateWidth(item) + 24
            if width + itemWidth > geo.size.width - 4 && !rows.last!.isEmpty {
                rows.append([]); width = 0
            }
            rows[rows.count - 1].append(item)
            width += itemWidth + 6
        }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.0) { _, row in
                HStack(spacing: 6) { ForEach(row, id: \.self) { content($0) } }
            }
        }
    }

    private func estimateWidth(_ item: Data.Element) -> CGFloat { CGFloat("\(item)".count) * 7.5 }
}

struct HeightReader: View {
    @Binding var height: CGFloat
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: HeightPrefKey.self, value: geo.size.height)
        }.onPreferenceChange(HeightPrefKey.self) { height = $0 }
    }
}

struct HeightPrefKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// Compatibility aliases
typealias ReadingAnalysis = ReadingEngine
typealias ReadResultStatCard = ReadScoreCard
