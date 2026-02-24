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
    
    private var timerTask: Task<Void, Never>?
    
    let maxDuration: TimeInterval = 15
    
    func startSession() {
        
        duration = 0
        state = .practicing
        
        timerTask?.cancel()
        
        timerTask = Task {
            
            while !Task.isCancelled {
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                duration += 0.1
                
                if duration >= maxDuration {
                    endSession()
                    break
                }
            }
        }
    }
    
    func endSession() {
        
        timerTask?.cancel()
        state = .summary
    }
    
    func resetSession() {
        
        timerTask?.cancel()
        duration = 0
        state = .idle
    }
}
