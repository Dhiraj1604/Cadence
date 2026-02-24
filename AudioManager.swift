//
//  File.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class AudioManager: ObservableObject {
    
    private let engine = AVAudioEngine()
    
    @Published var amplitude: CGFloat = 0
    
    private var smoothedAmplitude: CGFloat = 0
    
    private var demoTimer: Timer?
    
    func start() {
        
        let inputNode = engine.inputNode
        
        let format = inputNode.inputFormat(forBus: 0)
        
        if format.sampleRate == 0 {
            
            startDemoMode()
            return
        }
        
        inputNode.installTap(onBus: 0,
                             bufferSize: 1024,
                             format: format) { [weak self] buffer, _ in
            
            self?.process(buffer)
        }
        
        try? engine.start()
    }
    
    func stop() {
        
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        
        demoTimer?.invalidate()
    }
    
    private func process(_ buffer: AVAudioPCMBuffer) {
        
        guard let data = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        
        for i in 0..<frameLength {
            sum += abs(data[i])
        }
        
        let avg = sum / Float(frameLength)
        
        let normalized = min(max(CGFloat(avg) * 10, 0), 1)
        
        smoothedAmplitude =
            smoothedAmplitude * 0.85 +
            normalized * 0.15
        
        Task { @MainActor in
            self.amplitude = smoothedAmplitude
        }
    }
    
    private func startDemoMode() {
        
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.05,
                                         repeats: true) { [weak self] _ in
            
            guard let self else { return }
            
            let random = CGFloat.random(in: 0...0.6)
            
            self.smoothedAmplitude =
                self.smoothedAmplitude * 0.9 +
                random * 0.1
            
            self.amplitude = self.smoothedAmplitude
        }
    }
}
