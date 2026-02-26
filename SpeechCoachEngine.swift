// SpeechCoachEngine

// SpeechCoachEngine.swift
// Cadence — SSC Edition

import SwiftUI
import AVFoundation
import Speech

// ─────────────────────────────────────────────────────────────
// MARK: - FlowEvent
// ─────────────────────────────────────────────────────────────

struct FlowEvent: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let type: EventType

    enum EventType {
        case filler(word: String)
        case hesitation
        case strongMoment
        case flowBreak
    }

    var color: Color {
        switch type {
        case .filler:       return .orange
        case .hesitation:   return .yellow
        case .strongMoment: return .mint
        case .flowBreak:    return .red
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

// ─────────────────────────────────────────────────────────────
// MARK: - WordFrequencyEntry
// ─────────────────────────────────────────────────────────────

struct WordFrequencyEntry: Identifiable {
    let id = UUID()
    let word: String
    let count: Int
}

// ─────────────────────────────────────────────────────────────
// MARK: - SpeechCoachEngine
// ─────────────────────────────────────────────────────────────

@MainActor
class SpeechCoachEngine: ObservableObject {

    // Core
    @Published var amplitude: CGFloat = 0.0
    @Published var isSpeaking: Bool = false
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var wpm: Int = 0

    // Flow
    @Published var flowEvents: [FlowEvent] = []
    @Published var rhythmStability: Double = 100.0
    @Published var cognitiveLoadWarning: Bool = false

    // Word repetition tracker (replaces fake audience attention)
    @Published var topRepeatedWords: [WordFrequencyEntry] = []

    // Private
    private let fillerWords: Set<String> = ["um", "uh", "like", "so", "actually", "basically"]
    private let commonWords: Set<String> = [
        "the","a","an","is","it","in","of","to","and","for","on","at","by","as","be",
        "or","was","are","were","been","has","have","had","will","would","could","should",
        "may","might","do","does","did","can","not","no","i","you","he","she","we","they",
        "my","your","his","her","its","our","their","this","that","these","those","with",
        "from","about","into","just","but","so","if","then","than","when","what","how",
        "who","which","there","here","where","up","out","very","some","more","also","me",
        "him","us","them","am","got","get","let","go","going","now","well","even","really",
        "think","know","see","one","two","three","okay","right","yeah","yes","ok",
        "want","need","make","made","good","great","say","said","back","look","come","um","uh"
    ]

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var startTime: Date?
    private var silenceTimer: Date = Date()
    private var previousFillerCount = 0
    private var recentFillerTimestamps: [Date] = []
    private var amplitudeHistory: [CGFloat] = []
    private var lastSpeakingStart: Date?
    private var pauseStartTime: Date?
    private var strongStreakReported: Set<Int> = []
    private var previousWordList: [String] = []

    // MARK: - Public API

    func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                if status == .authorized { self?.startRecording() }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Private: Recording

    private func startRecording() {
        transcribedText = ""
        fillerWordCount = 0
        wpm = 0
        amplitude = 0.0
        isSpeaking = false
        flowEvents = []
        rhythmStability = 100.0
        cognitiveLoadWarning = false
        topRepeatedWords = []
        previousFillerCount = 0
        recentFillerTimestamps = []
        amplitudeHistory = []
        strongStreakReported = []
        lastSpeakingStart = nil
        pauseStartTime = nil
        previousWordList = []
        startTime = Date()

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let result = result {
                    self.analyzeSpeech(result.bestTranscription.formattedString)
                }
                if error != nil { self.stop() }
            }
        }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            var sum: Float = 0.0
            for i in 0..<frames { sum += channelData[i] * channelData[i] }
            let rms = sqrt(sum / Float(frames))
            let normalized = min(max(CGFloat(rms) * 5.0, 0.0), 1.0)
            DispatchQueue.main.async { [weak self] in
                self?.updateVisualizer(normalized)
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }

    // MARK: - Speech Analysis

    private func analyzeSpeech(_ text: String) {
        transcribedText = text

        let rawWords = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Filler detection
        let newFillerCount = rawWords.filter { fillerWords.contains($0) }.count
        if newFillerCount > previousFillerCount {
            for _ in 0..<(newFillerCount - previousFillerCount) {
                let word = rawWords.last(where: { fillerWords.contains($0) }) ?? "um"
                recordEvent(.filler(word: word))
                recentFillerTimestamps.append(Date())
            }
        }
        previousFillerCount = newFillerCount
        fillerWordCount = newFillerCount

        // WPM
        if let start = startTime {
            let mins = Date().timeIntervalSince(start) / 60.0
            if mins > 0 { wpm = Int(Double(rawWords.count) / mins) }
        }

        // Cognitive load: 3+ fillers in 10 seconds
        let now = Date()
        recentFillerTimestamps = recentFillerTimestamps.filter {
            now.timeIntervalSince($0) < 10
        }
        let newCogLoad = recentFillerTimestamps.count >= 3
        if newCogLoad && !cognitiveLoadWarning {
            recordEvent(.flowBreak)
        }
        cognitiveLoadWarning = newCogLoad

        // Rhythm stability from amplitude variance
        if amplitudeHistory.count > 20 {
            let mean = amplitudeHistory.reduce(CGFloat(0)) { $0 + $1 } / CGFloat(amplitudeHistory.count)
            let variance = amplitudeHistory.map { abs($0 - mean) }.reduce(CGFloat(0)) { $0 + $1 } / CGFloat(amplitudeHistory.count)
            rhythmStability = max(0, min(100, Double(100 - variance * 300)))
        }

        // Word frequency tracking
        updateWordFrequency(rawWords)
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

        let entries = freq
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { WordFrequencyEntry(word: $0.key, count: $0.value) }

        // Only update if content actually changed
        let newWords = entries.map { $0.word }
        let newCounts = entries.map { $0.count }
        let oldWords = topRepeatedWords.map { $0.word }
        let oldCounts = topRepeatedWords.map { $0.count }
        if newWords != oldWords || newCounts != oldCounts {
            topRepeatedWords = entries
        }
    }

    // MARK: - Visualizer / Speaking State

    private func updateVisualizer(_ newAmplitude: CGFloat) {
        amplitude = amplitude * 0.8 + newAmplitude * 0.2
        amplitudeHistory.append(amplitude)
        if amplitudeHistory.count > 100 { amplitudeHistory.removeFirst() }

        let wasSpeaking = isSpeaking

        if amplitude > 0.1 {
            isSpeaking = true
            silenceTimer = Date()

            if !wasSpeaking {
                if let ps = pauseStartTime {
                    if Date().timeIntervalSince(ps) > 2.0 {
                        recordEvent(.hesitation)
                    }
                    pauseStartTime = nil
                }
                lastSpeakingStart = Date()
            }

            // Reward sustained speech every 8 seconds
            if let ls = lastSpeakingStart {
                let streak = Int(Date().timeIntervalSince(ls))
                if streak > 0, streak % 8 == 0, !strongStreakReported.contains(streak) {
                    recordEvent(.strongMoment)
                    strongStreakReported.insert(streak)
                }
            }
        } else if Date().timeIntervalSince(silenceTimer) > 1.5 {
            if isSpeaking {
                pauseStartTime = Date()
                lastSpeakingStart = nil
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
            if same && ts - last.timestamp < 1.5 { return }
        }
        flowEvents.append(FlowEvent(timestamp: ts, type: type))
    }
}
