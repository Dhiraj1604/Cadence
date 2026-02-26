// SpeechCoachEngine

import SwiftUI
import AVFoundation
import Speech

// MARK: - Flow Event
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

@MainActor
class SpeechCoachEngine: ObservableObject {

    // Existing
    @Published var amplitude: CGFloat = 0.0
    @Published var isSpeaking: Bool = false
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var wpm: Int = 0

    // Breakthrough features
    @Published var attentionScore: Double = 100.0
    @Published var flowEvents: [FlowEvent] = []
    @Published var rhythmStability: Double = 100.0
    @Published var cognitiveLoadWarning: Bool = false

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let fillerWords: Set<String> = ["um", "uh", "like", "so", "actually", "basically"]
    private var startTime: Date?
    private var silenceTimer: Date = Date()

    // Flow internals
    private var previousFillerCount = 0
    private var recentFillerTimestamps: [Date] = []
    private var amplitudeHistory: [CGFloat] = []
    private var lastSpeakingStart: Date?
    private var pauseStartTime: Date?
    private var strongStreakReported: Set<Int> = []

    func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self?.startRecording()
                }
            }
        }
    }

    private func startRecording() {
        // Reset all state
        transcribedText = ""
        fillerWordCount = 0
        wpm = 0
        amplitude = 0.0
        isSpeaking = false
        attentionScore = 100.0
        flowEvents = []
        rhythmStability = 100.0
        cognitiveLoadWarning = false
        previousFillerCount = 0
        recentFillerTimestamps = []
        amplitudeHistory = []
        strongStreakReported = []
        lastSpeakingStart = nil
        pauseStartTime = nil
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
            request.append(buffer)

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

    private func analyzeSpeech(_ text: String) {
        transcribedText = text
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        let newFillerCount = words.filter { fillerWords.contains($0) }.count

        // Detect new fillers since last update
        if newFillerCount > previousFillerCount {
            for _ in 0..<(newFillerCount - previousFillerCount) {
                let word = words.last(where: { fillerWords.contains($0) }) ?? "um"
                recordEvent(.filler(word: word))
                attentionScore = max(0, attentionScore - 8)
                recentFillerTimestamps.append(Date())
            }
        }
        previousFillerCount = newFillerCount
        fillerWordCount = newFillerCount

        if let start = startTime {
            let mins = Date().timeIntervalSince(start) / 60.0
            if mins > 0 { wpm = Int(Double(words.count) / mins) }
        }

        // Cognitive load: 3+ fillers within 10 seconds
        let now = Date()
        recentFillerTimestamps = recentFillerTimestamps.filter {
            now.timeIntervalSince($0) < 10
        }
        let newCogLoad = recentFillerTimestamps.count >= 3
        if newCogLoad && !cognitiveLoadWarning {
            recordEvent(.flowBreak)
            attentionScore = max(0, attentionScore - 15)
        }
        cognitiveLoadWarning = newCogLoad

        // Rhythm stability from amplitude variance
        if amplitudeHistory.count > 20 {
            let mean = amplitudeHistory.reduce(0, +) / CGFloat(amplitudeHistory.count)
            let variance = amplitudeHistory.map { abs($0 - mean) }.reduce(0, +) / CGFloat(amplitudeHistory.count)
            rhythmStability = max(0, min(100, Double(100 - variance * 300)))
        }
    }

    private func updateVisualizer(_ newAmplitude: CGFloat) {
        amplitude = amplitude * 0.8 + newAmplitude * 0.2
        amplitudeHistory.append(amplitude)
        if amplitudeHistory.count > 100 { amplitudeHistory.removeFirst() }

        let wasSpeaking = isSpeaking

        if amplitude > 0.1 {
            isSpeaking = true
            silenceTimer = Date()

            if !wasSpeaking {
                // Resumed speaking — close hesitation if pause was long
                if let ps = pauseStartTime {
                    if Date().timeIntervalSince(ps) > 2.0 {
                        recordEvent(.hesitation)
                        attentionScore = max(0, attentionScore - 10)
                    }
                    pauseStartTime = nil
                }
                lastSpeakingStart = Date()
            }

            // Reward sustained clean speech every 8 seconds
            if let ls = lastSpeakingStart {
                let streak = Int(Date().timeIntervalSince(ls))
                if streak > 0 && streak % 8 == 0 && !strongStreakReported.contains(streak) {
                    recordEvent(.strongMoment)
                    strongStreakReported.insert(streak)
                    attentionScore = min(100, attentionScore + 5)
                }
            }

            // Slowly recover attention during good speech
            attentionScore = min(100, attentionScore + 0.03)

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
        // Deduplicate — same type not within 1.5 seconds
        if let last = flowEvents.last {
            let sameType: Bool
            switch (last.type, type) {
            case (.strongMoment, .strongMoment): sameType = true
            case (.flowBreak, .flowBreak):       sameType = true
            case (.hesitation, .hesitation):     sameType = true
            default:                             sameType = false
            }
            if sameType && ts - last.timestamp < 1.5 { return }
        }
        flowEvents.append(FlowEvent(timestamp: ts, type: type))
    }
}
