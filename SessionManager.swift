// SessionManager.swift
// Cadence — Apple Native Redesign
// SessionRecord.scoreColor now uses semantic cadence colors (adaptive light/dark)

import SwiftUI

// MARK: - Session State
enum SessionState { case idle, practicing, summary }

struct SpeechSignatureData {
    var wpm: Int
    var fillerCount: Int
    var rhythmStability: Double
    var eyeContactPercent: Int
    var flowEvents: [FlowEvent]
    var duration: TimeInterval
    var overallScore: Int
}

// MARK: - Session Record
struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let wpm: Int
    let fillers: Int
    let eyeContact: Int
    let rhythmStability: Double
    let transcript: String
    let flowEvents: [FlowEvent]
    var isVideoSession: Bool = false

    // Explicit init keeps all existing call sites (which don't pass id) working
    init(id: UUID = UUID(), date: Date, duration: TimeInterval, wpm: Int,
         fillers: Int, eyeContact: Int, rhythmStability: Double,
         transcript: String, flowEvents: [FlowEvent], isVideoSession: Bool = false) {
        self.id = id; self.date = date; self.duration = duration
        self.wpm = wpm; self.fillers = fillers; self.eyeContact = eyeContact
        self.rhythmStability = rhythmStability; self.transcript = transcript
        self.flowEvents = flowEvents; self.isVideoSession = isVideoSession
    }

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
        var score = 0
        switch wpm {
        case 130...150: score += 28
        case 120..<130, 151...160: score += 22
        case 110..<120, 161...170: score += 15
        case 100..<110, 171...180: score += 8
        case 1..<100:   score += 3
        case 181...:    score += 4
        default: break
        }
        switch fillers {
        case 0: score += 25; case 1: score += 21; case 2...3: score += 16
        case 4...6: score += 10; case 7...10: score += 5; default: score += 1
        }
        score += Int(Double(eyeContact) / 100.0 * 25)
        switch rhythmStability {
        case 85...100: score += 15; case 70..<85: score += 11
        case 55..<70: score += 7; case 40..<55: score += 4; default: score += 1
        }
        let secs = Int(duration)
        switch secs {
        case 120...: score += 7; case 60..<120: score += 5
        case 30..<60: score += 3; default: score += 1
        }
        return min(100, score)
    }

    var scoreBadge: String {
        switch performanceScore {
        case 90...100: return "Excellent"
        case 75..<90:  return "Strong"
        case 60..<75:  return "Decent"
        default:       return "Needs Work"
        }
    }

    /// ✅ Uses semantic cadence colors — fully adaptive light/dark
    var scoreColor: Color {
        switch performanceScore {
        case 75...100: return Color.cadenceGood
        case 55..<75:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }

    var signatureData: SpeechSignatureData {
        SpeechSignatureData(
            wpm: wpm, fillerCount: fillers, rhythmStability: rhythmStability,
            eyeContactPercent: eyeContact, flowEvents: flowEvents,
            duration: duration, overallScore: performanceScore
        )
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
    @Published var finalSpontaneityScore: Double = 50.0
    @Published var finalDetectedFillerWords: [String] = []
    
    @Published var sessionHistory: [SessionRecord] = []
    
    private let persistenceKey = "cadence_history_v1"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let saved = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            sessionHistory = saved
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }
    
    var totalSessions: Int { sessionHistory.count }
    var averageWPM: Int {
        guard !sessionHistory.isEmpty else { return 0 }
        return sessionHistory.reduce(0) { $0 + $1.wpm } / sessionHistory.count
    }
    var bestWPM: Int { sessionHistory.reduce(0) { max($0, $1.wpm) } }
    var totalPracticeTime: TimeInterval { sessionHistory.reduce(0.0) { $0 + $1.duration } }
    
    private var timerTask: Task<Void, Never>?
    
    func startSession() {
        duration = 0; state = .practicing
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                duration += 1
            }
        }
    }
    
    func endSession(wpm: Int, fillers: Int, transcript: String,
                    eyeContactDuration: TimeInterval, flowEvents: [FlowEvent],
                    rhythmStability: Double, attentionScore: Double,
                    spontaneityScore: Double = 50.0,
                    detectedFillerWords: [String] = []) {
        timerTask?.cancel()
        finalWPM = wpm; finalFillers = fillers
        finalFlowEvents = flowEvents; finalRhythmStability = rhythmStability
        finalAttentionScore = attentionScore
        finalSpontaneityScore = spontaneityScore
        finalDetectedFillerWords = detectedFillerWords
        if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalTranscript = transcript
        }
        eyeContactPercentage = duration > 0 ? min(100, Int((eyeContactDuration / duration) * 100)) : 0
        if wpm > 0 || fillers > 0 {
            let record = SessionRecord(date: Date(), duration: duration, wpm: wpm,
                                       fillers: fillers, eyeContact: eyeContactPercentage,
                                       rhythmStability: rhythmStability, transcript: finalTranscript,
                                       flowEvents: flowEvents)
            sessionHistory.insert(record, at: 0)
            saveHistory()
        }
        state = .summary
    }
    
    func resetSession() {
        timerTask?.cancel(); duration = 0; finalWPM = 0; finalFillers = 0
        eyeContactPercentage = 0; finalFlowEvents = []; finalRhythmStability = 100
        finalAttentionScore = 100; finalSpontaneityScore = 50.0; finalDetectedFillerWords = []
        finalTranscript = "No speech was detected during this session."
        state = .idle
    }
    
    /// Saves a Record & Review session to history. Called automatically — no user prompt needed.
    func saveVideoSession(wpm: Int, fillers: Int, transcript: String,
                          eyeContactScore: Int, duration: TimeInterval) {
        guard duration >= 5 else { return }
        var record = SessionRecord(
            date: Date(),
            duration: duration,
            wpm: wpm,
            fillers: fillers,
            eyeContact: eyeContactScore,
            rhythmStability: 80,
            transcript: transcript.isEmpty ? "No transcript available." : transcript,
            flowEvents: []
        )
        record.isVideoSession = true
        sessionHistory.insert(record, at: 0)
        saveHistory()
    }
}
