//
//  SpeechAnalyzer.swift
//  Cadence
//
//  Created by Dhiraj on 26/02/26.
//

import AVFoundation
import Speech
import SwiftUI

class SpeechAnalyzer: ObservableObject {
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var wpm: Int = 0
    @Published var cognitivePauses: Int = 0
    @Published var fullTranscript: String = ""
    
    // NEW: Alert the UI if offline speech isn't supported on this specific device
    @Published var isOfflineSupported: Bool = true
    
    init() {
        // Check if the device supports on-device recognition
        if let recognizer = speechRecognizer, !recognizer.supportsOnDeviceRecognition {
            self.isOfflineSupported = false
            print("WARNING: On-device speech recognition is not supported on this device.")
        }
    }
    
    func startRecording() throws {
        DispatchQueue.main.async {
            self.wpm = 0
            self.cognitivePauses = 0
            self.fullTranscript = ""
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        // 🔥 CRITICAL FOR SWIFT STUDENT CHALLENGE OFFLINE RULE 🔥
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            guard let result = result else { return }
            
            DispatchQueue.main.async {
                self.fullTranscript = result.bestTranscription.formattedString
            }
            
            let segments = result.bestTranscription.segments
            self.analyzeSpeechFlow(segments: segments)
            
            if error != nil || result.isFinal {
                self.stopRecording()
            }
        }
    }
    
    private func analyzeSpeechFlow(segments: [SFTranscriptionSegment]) {
        guard let lastSegment = segments.last else { return }
        
        let elapsedSeconds = lastSegment.timestamp
        if elapsedSeconds > 0 {
            let minutes = elapsedSeconds / 60.0
            DispatchQueue.main.async {
                self.wpm = Int(Double(segments.count) / minutes)
            }
        }
        
        if segments.count > 1 {
            let previousSegment = segments[segments.count - 2]
            let timeGap = lastSegment.timestamp - (previousSegment.timestamp + previousSegment.duration)
            
            if timeGap > 1.2 {
                DispatchQueue.main.async {
                    self.cognitivePauses += 1
                }
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}
