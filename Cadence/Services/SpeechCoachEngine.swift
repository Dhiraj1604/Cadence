// SpeechCoachEngine.swift
// Cadence — Intelligent Speech Analysis Engine
//
// v2: Voice Isolation + NLP-powered filler detection + noise floor tracking
//
// Key changes from v1:
//   1. AVAudioSession.Mode.voiceIsolation — system-level noise cancellation
//   2. NaturalLanguageProcessor — context-aware, confidence-positive filler detection
//   3. Noise floor tracking — ambient noise measured during first 2s, speech threshold adapts
//   4. Amplitude threshold raised 0.06→0.10 to prevent false DNA events from AC/fan noise
//   5. Word-based event fallback gated on isSpeaking to prevent silent DNA population
//   6. Rolling WPM requires 5s minimum window + 3 segments before showing a value

import SwiftUI
import Combine
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

    // MARK: - NLP Processor
    private let nlpProcessor = NaturalLanguageProcessor()

    // Common words excluded from "repeated words" analysis
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

    // ── Rolling restart to prevent iOS's ~60s silent cutoff ─────────────
    private var restartTimer:            Task<Void, Never>?
    private let restartIntervalSecs:     Double = 45.0
    // State carried across recognition windows
    private var accumulatedTranscript:   String = ""
    private var accumulatedNonFillerWords: Int  = 0

    // Timing
    private var startTime:             Date?
    private var silenceTimer:          Date = Date()
    private var lastSpeakingStart:     Date?
    private var pauseStartTime:        Date?
    private var strongStreakReported:  Set<Int> = []

    // Word-based event fallback — fires strongMoment every N words from transcription
    // so Flow DNA populates even when amplitude detection is unreliable.
    // GATED: only fires when isSpeaking is true (amplitude confirms voice).
    private var lastEventWordCount:    Int = 0

    // WPM snapshots for spontaneity
    private var wpmSnapshots:          [(elapsed: TimeInterval, wpm: Int)] = []
    private var lastSnapshotTime:      TimeInterval = 0

    // Filler tracking
    private var recentFillerTimestamps:   [Date] = []

    // Rhythm via segment timestamps
    private var allSegmentTimestamps:  [TimeInterval] = []

    private var amplitudeHistory: [CGFloat] = []

    // ── Noise floor tracking ────────────────────────────────────────────
    // Measures ambient noise during the first 2 seconds of a session.
    // Only amplitude ABOVE (noiseFloor + margin) is considered speech.
    private var noiseFloorSamples: [CGFloat] = []
    private var noiseFloor: CGFloat = 0.0
    private var noiseFloorCalibrated: Bool = false
    private let noiseFloorCalibrationDuration: TimeInterval = 2.0
    private let noiseFloorMargin: CGFloat = 0.04
    // Effective speaking threshold (after calibration)
    private var speakingThreshold: CGFloat { max(0.10, noiseFloor + noiseFloorMargin) }

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
        recentFillerTimestamps = []
        amplitudeHistory = []; wpmSnapshots = []; lastSnapshotTime = 0
        strongStreakReported = []; lastSpeakingStart = nil; pauseStartTime = nil
        allSegmentTimestamps = []
        accumulatedTranscript = ""
        accumulatedNonFillerWords = 0
        lastEventWordCount = 0
        noiseFloorSamples = []
        noiseFloor = 0.0
        noiseFloorCalibrated = false
        nlpProcessor.reset()
        startTime = Date()

        // ── Voice Isolation: iOS system-level noise cancellation ────────
        // This tells iOS to use its neural engine to isolate the human voice
        // from background noise (AC, fans, music, traffic, etc.).
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            // Attempt voice isolation if available (iOS 17+)
            if #available(iOS 17.0, *) {
                if audioSession.availableInputs?.first != nil {
                    try audioSession.setPreferredInputOrientation(.portrait)
                }
            }
        } catch {
            // Fallback: continue without voice isolation
            try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }

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

        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request
        request.shouldReportPartialResults = true
        // Server-side recognition for better accuracy (internet required)
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
        let hardFillers: Set<String> = ["um", "uh", "er", "hmm", "uhh", "umm", "erm", "ah", "ehh"]
        accumulatedNonFillerWords += windowWords.filter { !hardFillers.contains($0) }.count

        // Reset segment timestamps — new window gets new timestamps starting from 0
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

        // ── 1. NLP-Powered Filler Detection ──────────────────────────
        let elapsedMinutes = max(0.1, startTime.map { Date().timeIntervalSince($0) / 60.0 } ?? 0.1)

        let nlpResult = nlpProcessor.analyze(
            fullTranscript: fullText,
            elapsedMinutes: elapsedMinutes
        )

        // Record new filler events for Flow DNA
        for word in nlpResult.newFillers {
            recordEvent(.filler(word: word))
            recentFillerTimestamps.append(Date())
        }

        fillerWordCount = nlpResult.totalFillerCount
        detectedFillerWords = nlpResult.detectedFillers

        // ── 2. Session-average WPM ────────────────────────────────────
        let hardFillers: Set<String> = ["um", "uh", "er", "hmm", "uhh", "umm", "erm", "ah", "ehh"]
        let windowNonFiller = windowWords.filter { !hardFillers.contains($0) }.count
        let totalNonFiller  = accumulatedNonFillerWords + windowNonFiller
        if let start = startTime {
            let mins = Date().timeIntervalSince(start) / 60.0
            if mins > 0.05 { wpm = Int(Double(totalNonFiller) / mins) }
        }

        // ── 2b. Word-based event fallback ────────────────────────────
        // Fires strongMoment every 6 clean words from the transcription.
        // GATED: only when isSpeaking is true (amplitude confirms voice)
        // This prevents silent/noise DNA population.
        if isSpeaking {
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
        }

        // ── 3. Rolling WPM using real segment timestamps ──────────────
        // Minimum 5s window and 3 segments before showing a value
        let segments = transcription.segments
        if segments.count >= 3 {
            let latestTs    = segments.last!.timestamp
            let targetWindow = min(15.0, max(5.0, latestTs)) // grow from 5s → 15s
            let cutoff      = latestTs - targetWindow
            let recent      = segments.filter { $0.timestamp >= cutoff }
            if recent.count >= 3 {
                let span = latestTs - recent.first!.timestamp
                if span > 2.0 {
                    let wordsInSpan = recent.filter {
                        !hardFillers.contains($0.substring.lowercased().trimmingCharacters(in: .punctuationCharacters))
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
        // Uses Median Absolute Deviation (MAD) instead of standard deviation
        // for more robust rhythm measurement that isn't skewed by outlier pauses.
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
                if gap >= 0.05 && gap <= 1.5 { gaps.append(gap) }
            }
            if gaps.count >= 3 {
                // MAD-based rhythm: more robust than standard deviation
                let sorted = gaps.sorted()
                let median = sorted[sorted.count / 2]
                guard median > 0 else { return }
                let absoluteDeviations = gaps.map { abs($0 - median) }
                let mad = absoluteDeviations.sorted()[absoluteDeviations.count / 2]
                let normalizedMAD = mad / median

                rhythmStability = max(5.0, min(100.0, 100.0 - (normalizedMAD * 80.0)))
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

        // ── Noise floor calibration ──────────────────────────────────
        // During the first 2 seconds, collect ambient noise samples to
        // establish a baseline. Speech threshold adapts accordingly.
        if !noiseFloorCalibrated, let start = startTime {
            noiseFloorSamples.append(amplitude)
            if Date().timeIntervalSince(start) >= noiseFloorCalibrationDuration {
                noiseFloor = noiseFloorSamples.isEmpty ? 0.0
                    : noiseFloorSamples.sorted()[noiseFloorSamples.count / 2] // median
                noiseFloorCalibrated = true
            }
            // During calibration, don't trigger speaking state
            return
        }

        let wasSpeaking = isSpeaking

        // Threshold: must exceed noise floor + margin (minimum 0.10)
        if amplitude > speakingThreshold {
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
