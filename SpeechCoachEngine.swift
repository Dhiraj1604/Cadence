// SpeechCoachEngine

import SwiftUI
import AVFoundation
import Speech

@MainActor
class SpeechCoachEngine: ObservableObject {
    @Published var amplitude: CGFloat = 0.0
    @Published var isSpeaking: Bool = false
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var wpm: Int = 0
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let fillerWords = ["um", "uh", "like", "so", "actually", "basically"]
    private var startTime: Date?
    private var silenceTimer: Date = Date()
    
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
        transcribedText = ""
        fillerWordCount = 0
        wpm = 0
        amplitude = 0.0
        isSpeaking = false
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
        
        // Recognition task callback — always dispatch to main
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let result = result {
                    self.analyzeSpeech(result.bestTranscription.formattedString)
                }
                if error != nil {
                    self.stop()
                }
            }
        }
        
        let inputNode = audioEngine.inputNode
        
        // Always remove existing tap before installing a new one
        inputNode.removeTap(onBus: 0)
        
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // BACKGROUND AUDIO THREAD — only compute here, never touch UI
            request.append(buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            
            var sumSquares: Float = 0.0
            for i in 0..<frames {
                let sample = channelData[i]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(frames))
            let normalizedAmplitude = min(max(CGFloat(rms) * 5.0, 0.0), 1.0)
            
            // THE FIX: DispatchQueue.main.async — NOT Task {@MainActor}
            DispatchQueue.main.async { [weak self] in
                self?.updateVisualizer(normalizedAmplitude)
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
        self.transcribedText = text
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        self.fillerWordCount = words.filter { fillerWords.contains($0) }.count
        
        if let start = startTime {
            let elapsedMinutes = Date().timeIntervalSince(start) / 60.0
            if elapsedMinutes > 0 {
                self.wpm = Int(Double(words.count) / elapsedMinutes)
            }
        }
    }
    
    private func updateVisualizer(_ newAmplitude: CGFloat) {
        self.amplitude = self.amplitude * 0.8 + newAmplitude * 0.2
        if self.amplitude > 0.1 {
            self.isSpeaking = true
            self.silenceTimer = Date()
        } else if Date().timeIntervalSince(self.silenceTimer) > 1.5 {
            self.isSpeaking = false
        }
    }
}
