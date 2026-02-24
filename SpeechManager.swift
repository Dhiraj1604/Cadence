//
//  SpeechManager.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//

import Foundation
import Speech

@MainActor
class SpeechManager: ObservableObject {
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var wpm: Int = 0
    
    private let fillerWords = ["um", "uh", "like", "so", "actually", "basically"]
    private var startTime: Date?

    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status == .authorized {
                self.startRecording()
            }
        }
    }
    
    func stop() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
    
    private func startRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        startTime = Date()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                self.analyzeSpeech(self.transcribedText)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    private func analyzeSpeech(_ text: String) {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        // Count Fillers
        let fillers = words.filter { fillerWords.contains($0) }
        self.fillerWordCount = fillers.count
        
        // Calculate WPM
        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start) / 60.0
            if elapsed > 0 {
                self.wpm = Int(Double(words.count) / elapsed)
            }
        }
    }
}
