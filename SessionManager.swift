//  SessionManager.swift

// SessionManager.swift
// Cadence — SSC Edition

import SwiftUI

// MARK: - Session State
enum SessionState {
    case idle
    case practicing
    case summary
}

// MARK: - Session Record
struct SessionRecord: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let wpm: Int
    let fillers: Int
    let eyeContact: Int
    let rhythmStability: Double
    let transcript: String

    var durationString: String {
        let d = Int(duration)
        return d < 60 ? "\(d)s" : "\(d/60)m \(d%60)s"
    }

    var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    var performanceScore: Int {
        var score = 50
        if wpm >= 120 && wpm <= 160 { score += 20 }
        else if (wpm >= 100 && wpm < 120) || (wpm > 160 && wpm <= 180) { score += 10 }
        if fillers == 0 { score += 15 }
        else if fillers <= 3 { score += 10 }
        else if fillers <= 7 { score += 4 }
        score += Int(Double(eyeContact) / 100.0 * 15)
        return min(100, score)
    }

    var scoreBadge: String {
        switch performanceScore {
        case 90...100: return "★ Elite"
        case 75..<90:  return "Strong"
        case 60..<75:  return "Decent"
        default:       return "Needs Work"
        }
    }

    var scoreColor: Color {
        switch performanceScore {
        case 75...100: return .mint
        case 55..<75:  return .yellow
        default:       return .orange
        }
    }
}

// MARK: - Session Manager
@MainActor
final class SessionManager: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var duration: TimeInterval = 0

    @Published var finalWPM: Int = 0
    @Published var finalFillers: Int = 0
    @Published var finalTranscript: String = "No speech was detected during this session."
    @Published var eyeContactPercentage: Int = 0
    @Published var finalFlowEvents: [FlowEvent] = []
    @Published var finalRhythmStability: Double = 100
    @Published var finalAttentionScore: Double = 100

    @Published var sessionHistory: [SessionRecord] = []

    var totalSessions: Int { sessionHistory.count }

    var averageWPM: Int {
        guard !sessionHistory.isEmpty else { return 0 }
        let total = sessionHistory.reduce(0) { $0 + $1.wpm }
        return total / sessionHistory.count
    }

    var bestWPM: Int {
        sessionHistory.reduce(0) { max($0, $1.wpm) }
    }

    var totalPracticeTime: TimeInterval {
        sessionHistory.reduce(0.0) { $0 + $1.duration }
    }

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

        if wpm > 0 || fillers > 0 {
            let record = SessionRecord(
                date: Date(),
                duration: duration,
                wpm: wpm,
                fillers: fillers,
                eyeContact: eyeContactPercentage,
                rhythmStability: rhythmStability,
                transcript: finalTranscript
            )
            sessionHistory.insert(record, at: 0)
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
