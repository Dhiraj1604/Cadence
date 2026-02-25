//
//  SessionManager.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//
import SwiftUI

enum SessionState {
    case idle
    case practicing
    case summary
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var duration: TimeInterval = 0
    
    // Final Session Statistics
    @Published var finalWPM: Int = 0
    @Published var finalFillers: Int = 0
    @Published var finalTranscript: String = ""
    @Published var eyeContactPercentage: Int = 0
    
    private var timerTask: Task<Void, Never>?
    
    func startSession() {
        duration = 0
        state = .practicing
        timerTask?.cancel()
        
        // Count up normally, let the user stop it when they are done
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                duration += 1
            }
        }
    }
    
    func endSession(wpm: Int, fillers: Int, transcript: String, eyeContactDuration: TimeInterval) {
        timerTask?.cancel()
        
        self.finalWPM = wpm
        self.finalFillers = fillers
        self.finalTranscript = transcript
        
        // Calculate Eye Contact %
        if duration > 0 {
            self.eyeContactPercentage = min(100, Int((eyeContactDuration / duration) * 100))
        } else {
            self.eyeContactPercentage = 0
        }
        
        state = .summary
    }
    
    func resetSession() {
        timerTask?.cancel()
        duration = 0
        state = .idle
    }
}
