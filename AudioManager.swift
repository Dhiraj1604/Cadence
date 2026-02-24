import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class AudioManager: ObservableObject {
    private let engine = AVAudioEngine()
    
    // Smooth amplitude (0.0 to 1.0) for fluid UI animation
    @Published var amplitude: CGFloat = 0.0
    
    // Boolean to detect awkward pauses
    @Published var isSpeaking: Bool = false
    
    private var silenceTimer: Date = Date()
    
    func start() {
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        
        // Prevent crash on simulator where sample rate might be 0
        guard format.sampleRate > 0 else {
            print("Audio engine not supported on this simulator/device state.")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioData(buffer: buffer)
        }
        
        engine.prepare()
        try? engine.start()
    }
    
    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        amplitude = 0.0
        isSpeaking = false
    }
    
    private func processAudioData(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        // Calculate Root Mean Square (RMS) for accurate audio power
        var sumSquares: Float = 0.0
        for i in 0..<Int(frames) {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frames))
        
        // Convert to a smooth 0-1 scale for SwiftUI
        let normalizedAmplitude = min(max(CGFloat(rms) * 5.0, 0.0), 1.0)
        
        Task { @MainActor in
            // Smooth the animation mathematically (80% old value, 20% new value)
            self.amplitude = self.amplitude * 0.8 + normalizedAmplitude * 0.2
            
            // Determine if the user is actively speaking
            if self.amplitude > 0.1 {
                self.isSpeaking = true
                self.silenceTimer = Date()
            } else {
                // If silent for more than 1.5 seconds, flag as not speaking
                if Date().timeIntervalSince(self.silenceTimer) > 1.5 {
                    self.isSpeaking = false
                }
            }
        }
    }
}
