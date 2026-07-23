// LiveCoachTip.swift
// Cadence

import SwiftUI

enum LiveCoachTip {
    case fillers(count: Int)
    case cognitiveLoad
    case tooFast(wpm: Int)
    case tooSlow(wpm: Int)
    case eyeContact

    var icon: String {
        switch self {
        case .fillers:       return "exclamationmark.bubble.fill"
        case .cognitiveLoad: return "brain.head.profile"
        case .tooFast:       return "hare.fill"
        case .tooSlow:       return "tortoise.fill"
        case .eyeContact:    return "eye.slash.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fillers:           return Color.cadenceWarn
        case .cognitiveLoad:     return Color.cadenceBad
        case .tooFast, .tooSlow: return Color.cadenceNeutral
        case .eyeContact:        return Color.cyan
        }
    }
    
    var message: String {
        switch self {
        case .fillers:          return "Replace fillers with a deliberate 1-second pause"
        case .cognitiveLoad:    return "Breathe — let your thoughts form first, then speak"
        case .tooFast(let w):   return "Slow down — at \(w) WPM your audience can't keep up"
        case .tooSlow:          return "Bring more energy — aim for 130–150 WPM"
        case .eyeContact:       return "Look up — eye contact builds trust immediately"
        }
    }
}
