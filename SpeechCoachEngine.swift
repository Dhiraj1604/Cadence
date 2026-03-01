// SpeechCoachEngine.swift
// Cadence — Intelligent Speech Analysis Engine

import SwiftUI
import AVFoundation
import Speech

// MARK: - FlowEvent

struct FlowEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let type: EventType

    // Keeps existing call sites FlowEvent(timestamp:type:) working unchanged
    init(id: UUID = UUID(), timestamp: TimeInterval, type: EventType) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
    }

    enum EventType: Codable {
        case filler(word: String)
        case hesitation
        case strongMoment
        case flowBreak

        private enum CodingKeys: String, CodingKey { case kind, word }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(String.self, forKey: .kind)
            switch kind {
            case "filler":
                let w = (try? c.decode(String.self, forKey: .word)) ?? ""
                self = .filler(word: w)
            case "hesitation":   self = .hesitation
            case "strongMoment": self = .strongMoment
            default:             self = .flowBreak
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .filler(let w):
                try c.encode("filler", forKey: .kind)
                try c.encode(w, forKey: .word)
            case .hesitation:   try c.encode("hesitation",   forKey: .kind)
            case .strongMoment: try c.encode("strongMoment", forKey: .kind)
            case .flowBreak:    try c.encode("flowBreak",    forKey: .kind)
            }
        }
    }

    var color: Color {
        switch type {
        case .filler:       return Color.cadenceWarn
        case .hesitation:   return Color.cadenceNeutral
        case .strongMoment: return Color.mint
        case .flowBreak:    return Color.cadenceBad
        }
    }

    var label: String {
        switch type {
        case .filler(let w): return "\"\(w)\""
        case .hesitation:    return "Pause"
        case .strongMoment:  return "Strong"
        case .flowBreak:     return "Lost Flow"
        }
    }
}

// MARK: - WordFrequencyEntry

struct WordFrequencyEntry: Identifiable {
    let id = UUID()
    let word: String
    let count: Int
}

// MARK: - SpeechCoachEngine

@MainActor
class SpeechCoachEngine: ObservableObject {

    // Core
    @Published var amplitude:            CGFloat = 0.0
    @Published var isSpeaking:           Bool    = false
    @Published var transcribedText:      String  = ""
    @Published var fillerWordCount:      Int     = 0
    @Published var wpm:                  Int     = 0
    @Published var rollingWPM:           Int     = 0

    // Flow & rhythm
    @Published var flowEvents:           [FlowEvent] = []
    @Published var rhythmStability:      Double  = -1.0
    @Published var cognitiveLoadWarning: Bool    = false

    // Richer signals
    @Published var spontaneityScore:     Double  = 50.0
    @Published var waveformSamples:      [CGFloat] = Array(repeating: 0, count: 40)
    @Published var topRepeatedWords:     [WordFrequencyEntry] = []
    @Published var detectedFillerWords:  [String] = []

    // MARK: - Filler Word System
    //
    // Two tiers:
    //
    // Tier 1 — ALWAYS fillers ("um", "uh", "er", "hmm"):
    //   These are never intentional. Every single usage is a filler. Count them all.
    //
    // Tier 2 — CONTEXT-DEPENDENT words ("like", "so", "right", "actually", etc.):
    //   These are normal, useful words in good speech. Saying "like" once is fine.
    //   Saying "like" 8 times in 2 minutes is a filler habit.
    //   Each word has its own allowedPerMinute threshold — beyond that it's flagged.
    //
    // This mirrors how real speech coaches think: frequency is the problem, not presence.

    // Tier 1: Always a filler — zero tolerance
    private let hardFillerWords: Set<String> = [
        "um", "uh", "er", "hmm", "uhh", "umm", "erm"
    ]

    // Tier 2: Allowed up to N times per minute of speech before flagging
    // Values chosen to match what real public speaking coaches consider acceptable:
    //   "so" — very common sentence opener, allow ~2/min before it becomes a crutch
    //   "like" — allowed ~1.5/min (common but noticed quickly)
    //   "actually", "basically", "literally" — buzzwords, allow ~1/min
    //   "right", "okay" — verbal check-ins, allow ~1.5/min
    //   "you know", "i mean" — filler phrases, allow ~1/min
    private let contextFillerThresholds: [String: Double] = [
        "like":       1.5,
        "so":         2.0,
        "right":      1.5,
        "okay":       1.5,
        "ok":         1.5,
        "actually":   1.0,
        "basically":  1.0,
        "literally":  0.8,
        "anyway":     1.0,
        "you know":   1.0,
        "i mean":     1.0,
        "kind of":    1.0,
        "sort of":    1.0,
        "honestly":   1.0,
        "seriously":  0.8,
        "whatever":   0.5
    ]

    // All words this system tracks (for quick membership check)
    private var allTrackedFillerWords: Set<String> {
        hardFillerWords.union(Set(contextFillerThresholds.keys))
    }

    // Live frequency counters for context-dependent words
    private var contextFillerCounts: [String: Int] = [:]

    private let commonWords: Set<String> = [
        "the","a","an","is","it","in","of","to","and","for","on","at","by","as","be",
        "or","was","are","were","been","has","have","had","will","would","could","should",
        "may","might","do","does","did","can","not","no","i","you","he","she","we","they",
        "my","your","his","her","its","our","their","this","that","these","those","with",
        "from","about","into","just","but","so","if","then","than","when","what","how",
        "who","which","there","here","where","up","out","very","some","more","also","me",
        "him","us","them","am","got","get","let","go","going","now","well","even","really",
        "think","know","see","one","two","three","yeah","yes",
        "want","need","make","made","good","great","say","said","back","look","come"
    ]

    // AVFoundation / Speech
    private let audioEngine      = AVAudioEngine()
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
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?

    // ── Rolling restart to prevent iOS's ~60s silent cutoff ─────────────────
    private var restartTimer:            Task<Void, Never>?
    private let restartIntervalSecs:     Double = 45.0
    // State carried across recognition windows
    private var accumulatedTranscript:   String = ""
    private var accumulatedNonFillerWords: Int  = 0
    private var accumulatedFillerCount:  Int    = 0

    // Timing
    private var startTime:             Date?
    private var silenceTimer:          Date = Date()
    private var lastSpeakingStart:     Date?
    private var pauseStartTime:        Date?
    private var strongStreakReported:  Set<Int> = []

    // Word-based event fallback — fires strongMoment every N words from transcription
    // so Flow DNA populates even when amplitude detection is unreliable
    private var lastEventWordCount:    Int = 0

    // WPM snapshots for spontaneity
    private var wpmSnapshots:          [(elapsed: TimeInterval, wpm: Int)] = []
    private var lastSnapshotTime:      TimeInterval = 0

    // Filler tracking
    private var previousWindowFillerCount = 0
    private var recentFillerTimestamps:   [Date] = []

    // Rhythm via segment timestamps
    private var allSegmentTimestamps:  [TimeInterval] = []

    private var amplitudeHistory: [CGFloat] = []

    // MARK: - Public API

    func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                if status == .authorized { self?.startRecording() }
            }
        }
    }

    func stop() {
        restartTimer?.cancel()
        restartTimer = nil
        teardownRecognition()
        startTime = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Session start

    private func startRecording() {
        // Full reset
        transcribedText = ""; fillerWordCount = 0; wpm = 0; rollingWPM = 0
        spontaneityScore = 50.0
        waveformSamples  = Array(repeating: 0, count: 40)
        amplitude = 0.0; isSpeaking = false; flowEvents = []
        rhythmStability = -1.0; cognitiveLoadWarning = false
        topRepeatedWords = []; detectedFillerWords = []
        previousWindowFillerCount = 0; recentFillerTimestamps = []
        contextFillerCounts = [:]
        amplitudeHistory = []; wpmSnapshots = []; lastSnapshotTime = 0
        strongStreakReported = []; lastSpeakingStart = nil; pauseStartTime = nil
        allSegmentTimestamps = []
        accumulatedTranscript = ""
        accumulatedNonFillerWords = 0
        accumulatedFillerCount = 0
        lastEventWordCount = 0
        startTime = Date()

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        startAudioEngine()
        beginRecognitionWindow()
        scheduleRollingRestart()
    }

    // MARK: - Audio engine (start once, keep running across windows)

    private func startAudioEngine() {
        guard !audioEngine.isRunning else { return }
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // Feed buffer to the CURRENT recognition request (updated on each restart)
            self?.recognitionRequest?.append(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            var sum: Float = 0.0
            for i in 0..<frames { sum += channelData[i] * channelData[i] }
            let rms = sqrt(sum / Float(frames))
            // Multiplier raised 5→10 so quiet/distant speech still registers
            let normalized = min(max(CGFloat(rms) * 10.0, 0.0), 1.0)
            DispatchQueue.main.async { [weak self] in self?.updateVisualizer(normalized) }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }

    // MARK: - Recognition window management

    /// Opens a fresh recognition request. Audio engine stays running.
    private func beginRecognitionWindow() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask    = nil
        previousWindowFillerCount = accumulatedFillerCount

        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request
        request.shouldReportPartialResults = true
        // On-device recognition has inconsistent segment timestamps on many devices.
        // Server-side recognition is more reliable for WPM and rhythm calculation.
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16, *) {
            request.addsPunctuation = false
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let result = result {
                    self.processTranscriptionResult(result)
                }
                if let err = error {
                    let nsErr = err as NSError
                    // Ignore: no-speech (1110), cancelled by us (301), timeout (203)
                    let safeToIgnore = [1110, 203, 301, -1]
                    if !safeToIgnore.contains(nsErr.code) {
                        // Unexpected error — restart the window
                        self.rolloverToNewWindow()
                    }
                }
            }
        }
    }

    /// Snapshot current window, start a new one (called every 45s or on error)
    private func rolloverToNewWindow() {
        // Save what this window produced
        let windowText = transcribedText.hasPrefix(accumulatedTranscript)
            ? String(transcribedText.dropFirst(accumulatedTranscript.count)).trimmingCharacters(in: .whitespaces)
            : transcribedText

        if !windowText.isEmpty {
            accumulatedTranscript = accumulatedTranscript.isEmpty
                ? windowText
                : accumulatedTranscript + " " + windowText
        }

        // Carry over word counts
        let windowWords = windowText.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        accumulatedNonFillerWords += windowWords.filter { !hardFillerWords.contains($0) }.count
        accumulatedFillerCount    += windowWords.filter {  hardFillerWords.contains($0) }.count

        // Reset segment timestamps — new window gets new timestamps starting from 0
        // (we keep allSegmentTimestamps for rhythm, offset them by accumulated time)
        beginRecognitionWindow()
    }

    private func scheduleRollingRestart() {
        restartTimer?.cancel()
        restartTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(restartIntervalSecs * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.rolloverToNewWindow() }
            }
        }
    }

    private func teardownRecognition() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask    = nil
    }

    // MARK: - Transcription analysis

    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult) {
        let transcription = result.bestTranscription
        let windowText    = transcription.formattedString

        // Build full display text: past windows + current live window
        let fullText = accumulatedTranscript.isEmpty
            ? windowText
            : accumulatedTranscript + " " + windowText
        transcribedText = fullText

        let windowWords = windowText.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // ── 1. Filler detection ───────────────────────────────────────
        //
        // Tier 1 (hard fillers: um/uh/er): flag every occurrence immediately.
        // Tier 2 (context words: like/so/right/actually etc.): only flag when
        // the word's usage rate exceeds its allowed threshold (per minute of speech).
        //
        let elapsedMinutes = max(0.1, startTime.map { Date().timeIntervalSince($0) / 60.0 } ?? 0.1)

        let windowFillers = windowWords.filter { hardFillerWords.contains($0) }
        let windowFillerCount = windowFillers.count
        let previousCount = previousWindowFillerCount

        // New hard fillers in this window delta
        if windowFillerCount > previousCount {
            let newOnes = Array(windowFillers.suffix(windowFillerCount - previousCount))
            for word in newOnes {
                recordEvent(.filler(word: word))
                recentFillerTimestamps.append(Date())
                detectedFillerWords.append(word)
            }
        }
        previousWindowFillerCount = windowFillerCount

        // Context-dependent fillers: count occurrences in full transcript so far,
        // flag only when rate exceeds threshold
        var contextFillerTotal = 0
        for (word, allowedPerMin) in contextFillerThresholds {
            let fullTranscriptLower = (accumulatedTranscript + " " + windowText).lowercased()
            let occurrences = fullTranscriptLower
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.trimmingCharacters(in: .punctuationCharacters) == word }
                .count
            let previousOccurrences = contextFillerCounts[word, default: 0]
            contextFillerCounts[word] = occurrences

            // Only flag if rate exceeds threshold AND this is a new occurrence
            if occurrences > previousOccurrences {
                let rate = Double(occurrences) / elapsedMinutes
                if rate > allowedPerMin {
                    // Flag as filler only when crossing threshold, not every occurrence
                    if previousOccurrences == 0 || Double(previousOccurrences) / elapsedMinutes <= allowedPerMin {
                        recordEvent(.filler(word: word))
                        recentFillerTimestamps.append(Date())
                    }
                    detectedFillerWords.append(word)
                    contextFillerTotal += 1
                }
            }
        }

        fillerWordCount = accumulatedFillerCount + windowFillerCount + contextFillerTotal

        // ── 2. Session-average WPM ────────────────────────────────────
        let windowNonFiller = windowWords.filter { !hardFillerWords.contains($0) }.count
        let totalNonFiller  = accumulatedNonFillerWords + windowNonFiller
        if let start = startTime {
            let mins = Date().timeIntervalSince(start) / 60.0
            if mins > 0.05 { wpm = Int(Double(totalNonFiller) / mins) }
        }

        // ── 2b. Word-based event fallback ────────────────────────────
        // Fires strongMoment every 6 clean words from the transcription.
        // This guarantees Flow DNA and Speech Signature populate for clean
        // speech even when mic amplitude never crosses the threshold —
        // the primary fix for blank DNA on normal speech.
        let totalWords = totalNonFiller
        let wordsPerEvent = 6
        let expectedEvents = totalWords / wordsPerEvent
        if expectedEvents > lastEventWordCount / wordsPerEvent {
            let newEvents = expectedEvents - (lastEventWordCount / wordsPerEvent)
            for _ in 0..<min(newEvents, 3) { // cap at 3 per callback to avoid spam
                recordEvent(.strongMoment)
            }
        }
        lastEventWordCount = totalWords

        // ── 3. Rolling WPM using real segment timestamps ──────────────
        // Use a dynamic window: start with whatever span is available (min 3s),
        // grow to 15s once enough speech has accumulated. This means WPM shows
        // a real number within the first few words rather than waiting 15 seconds.
        let segments = transcription.segments
        if segments.count >= 2 {
            let latestTs    = segments.last!.timestamp
            let targetWindow = min(15.0, max(3.0, latestTs)) // grow from 3s → 15s
            let cutoff      = latestTs - targetWindow
            let recent      = segments.filter { $0.timestamp >= cutoff }
            if recent.count >= 2 {
                let span = latestTs - recent.first!.timestamp
                if span > 1.0 {
                    let wordsInSpan = recent.filter {
                        !hardFillerWords.contains($0.substring.lowercased().trimmingCharacters(in: .punctuationCharacters))
                    }.count
                    let mins = span / 60.0
                    if mins > 0 { rollingWPM = Int(Double(wordsInSpan) / mins) }
                }
            }
        }

        // ── 4. Spontaneity from WPM variance ─────────────────────────
        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed - lastSnapshotTime >= 8.0, wpm > 0 {
                wpmSnapshots.append((elapsed, wpm))
                if wpmSnapshots.count > 8 { wpmSnapshots.removeFirst() }
                lastSnapshotTime = elapsed
                if wpmSnapshots.count >= 3 {
                    let vals = wpmSnapshots.map { Double($0.wpm) }
                    let mean = vals.reduce(0, +) / Double(vals.count)
                    let variance = vals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(vals.count)
                    let cv = mean > 0 ? sqrt(variance) / mean : 0
                    spontaneityScore = min(100, max(0, cv * 500))
                }
            }
        }

        // ── 5. Cognitive load: 3+ fillers in 12 s ────────────────────
        let now = Date()
        recentFillerTimestamps = recentFillerTimestamps.filter { now.timeIntervalSince($0) < 12 }
        let newCogLoad = recentFillerTimestamps.count >= 3
        if newCogLoad && !cognitiveLoadWarning { recordEvent(.flowBreak) }
        cognitiveLoadWarning = newCogLoad

        // ── 6. Rhythm from segment timestamps ────────────────────────
        // Accumulate timestamps. Each new recognition window resets to 0,
        // so offset by accumulated session time.
        let sessionOffset = accumulatedNonFillerWords > 0
            ? Double(allSegmentTimestamps.last ?? 0)
            : 0.0

        let newTimestamps = transcription.segments.map { $0.timestamp + sessionOffset }
        if newTimestamps.count > allSegmentTimestamps.count {
            allSegmentTimestamps = newTimestamps
        }

        if allSegmentTimestamps.count >= 4 {
            let window = Array(allSegmentTimestamps.suffix(60))
            var gaps: [Double] = []
            for i in 1..<window.count {
                let gap = window[i] - window[i-1]
                // 50ms–1.5s = realistic inter-word gap
                // Longer gaps = deliberate pauses (exclude from rhythm calc)
                if gap >= 0.05 && gap <= 1.5 { gaps.append(gap) }
            }
            if gaps.count >= 3 {
                let mean = gaps.reduce(0, +) / Double(gaps.count)
                guard mean > 0 else { return }
                let stdDev = sqrt(gaps.map { pow($0 - mean, 2) }.reduce(0, +) / Double(gaps.count))
                let cv = stdDev / mean

                rhythmStability = max(5.0, min(100.0, 100.0 - (cv * 65.0)))
            }
        }

        updateWordFrequency(windowWords)
    }

    private func updateWordFrequency(_ words: [String]) {
        var freq: [String: Int] = [:]
        for word in words {
            let clean = word
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)
            guard clean.count > 2, !commonWords.contains(clean) else { continue }
            freq[clean, default: 0] += 1
        }
        let entries = freq.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { WordFrequencyEntry(word: $0.key, count: $0.value) }
        let newWords  = entries.map { $0.word }
        let newCounts = entries.map { $0.count }
        if newWords  != topRepeatedWords.map({ $0.word }) ||
           newCounts != topRepeatedWords.map({ $0.count }) {
            topRepeatedWords = entries
        }
    }

    // MARK: - Visualiser

    private func updateVisualizer(_ newAmplitude: CGFloat) {
        amplitude = amplitude * 0.75 + newAmplitude * 0.25
        amplitudeHistory.append(amplitude)
        if amplitudeHistory.count > 200 { amplitudeHistory.removeFirst() }
        waveformSamples.removeFirst()
        waveformSamples.append(amplitude)

        let wasSpeaking = isSpeaking

        // Threshold lowered 0.15→0.06 — catches quiet and distant speech reliably
        if amplitude > 0.06 {
            isSpeaking   = true
            silenceTimer = Date()
            if !wasSpeaking {
                if let ps = pauseStartTime {
                    if Date().timeIntervalSince(ps) > 1.8 { recordEvent(.hesitation) }
                    pauseStartTime = nil
                }
                lastSpeakingStart = Date()
                recordEvent(.strongMoment)
            }
            if let ls = lastSpeakingStart {
                let streak = Int(Date().timeIntervalSince(ls))
                if streak > 0, streak % 2 == 0, !strongStreakReported.contains(streak) {
                    recordEvent(.strongMoment)
                    strongStreakReported.insert(streak)
                }
            }
        } else if Date().timeIntervalSince(silenceTimer) > 2.0 {
            if isSpeaking {
                pauseStartTime       = Date()
                lastSpeakingStart    = nil
                strongStreakReported = []
            }
            isSpeaking = false
        }
    }

    private func recordEvent(_ type: FlowEvent.EventType) {
        let ts = startTime.map { Date().timeIntervalSince($0) } ?? 0
        if let last = flowEvents.last {
            let same: Bool
            switch (last.type, type) {
            case (.strongMoment, .strongMoment): same = true
            case (.flowBreak,    .flowBreak):    same = true
            case (.hesitation,   .hesitation):   same = true
            default:                             same = false
            }
            let debounce: TimeInterval
            switch type {
            case .strongMoment: debounce = 0.5
            default:            debounce = 1.5
            }
            if same && ts - last.timestamp < debounce { return }
        }
        flowEvents.append(FlowEvent(timestamp: ts, type: type))
    }
}
