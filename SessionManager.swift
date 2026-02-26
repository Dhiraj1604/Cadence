//  SessionManager.swift

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

    // Final stats
    @Published var finalWPM: Int = 0
    @Published var finalFillers: Int = 0
    @Published var finalTranscript: String = "No speech was detected during this session."
    @Published var eyeContactPercentage: Int = 0

    // Flow data for SummaryView
    @Published var finalFlowEvents: [FlowEvent] = []
    @Published var finalRhythmStability: Double = 100
    @Published var finalAttentionScore: Double = 100

    private var timerTask: Task<Void, Never>?

    func startSession() {
        duration = 0
        state = .practicing
        timerTask?.cancel()

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                duration += 1
            }
        }
    }

    func endSession(
        wpm: Int,
        fillers: Int,
        transcript: String,
        eyeContactDuration: TimeInterval,
        flowEvents: [FlowEvent],
        rhythmStability: Double,
        attentionScore: Double
    ) {
        timerTask?.cancel()

        finalWPM = wpm
        finalFillers = fillers
        finalFlowEvents = flowEvents
        finalRhythmStability = rhythmStability
        finalAttentionScore = attentionScore

        if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalTranscript = transcript
        }

        if duration > 0 {
            eyeContactPercentage = min(100, Int((eyeContactDuration / duration) * 100))
        } else {
            eyeContactPercentage = 0
        }

        state = .summary
    }

    func resetSession() {
        timerTask?.cancel()
        duration = 0
        finalWPM = 0
        finalFillers = 0
        eyeContactPercentage = 0
        finalFlowEvents = []
        finalRhythmStability = 100
        finalAttentionScore = 100
        finalTranscript = "No speech was detected during this session."
        state = .idle
    }
}
