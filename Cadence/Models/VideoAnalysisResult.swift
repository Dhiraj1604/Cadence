// VideoAnalysisResult.swift
// Cadence

import SwiftUI

struct VideoAnalysisResult: Equatable {
    let transcript:       String
    let wordCount:        Int
    let wpm:              Int
    let fillerCount:      Int
    let duration:         TimeInterval
    let eyeContactScore:  Int

    static let empty = VideoAnalysisResult(
        transcript: "", wordCount: 0, wpm: 0,
        fillerCount: 0, duration: 0, eyeContactScore: 0
    )

    static func == (lhs: VideoAnalysisResult, rhs: VideoAnalysisResult) -> Bool {
        lhs.transcript == rhs.transcript && lhs.wpm == rhs.wpm
    }

    var wpmBadge: String {
        switch wpm {
        case 120...160: return "Ideal Pace"
        case 100..<120: return "Slightly Slow"
        case 160..<180: return "Slightly Fast"
        case 0:         return "No Speech"
        default:        return wpm > 180 ? "Too Fast" : "Too Slow"
        }
    }
    var fillerBadge: String {
        switch fillerCount {
        case 0:     return "Flawless"
        case 1...3: return "Great"
        case 4...7: return "Noticeable"
        default:    return "Needs Work"
        }
    }
    var eyeContactBadge: String {
        switch eyeContactScore {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Fair"
        default:       return "Needs Work"
        }
    }
    var eyeContactColor: Color {
        switch eyeContactScore {
        case 70...100: return Color.cadenceAccent
        case 45..<70:  return .yellow
        default:       return Color.cadenceWarn
        }
    }
}
