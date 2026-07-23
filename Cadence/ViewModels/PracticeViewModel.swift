// PracticeViewModel.swift
// Cadence

import SwiftUI
import Combine

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published var liveTip: LiveCoachTip?
    @Published var tipVisible = false
    @Published var showEndSheet = false
    
    private var lastTipTime: TimeInterval = -30
    private var lastFillerCountForTip = 0
    
    // MARK: - Tip Logic
    func checkForLiveTip(fillers: Int, duration: TimeInterval) {
        guard duration - lastTipTime > 20 else { return }
        if fillers - lastFillerCountForTip >= 3 {
            showTip(.fillers(count: fillers), duration: duration)
            lastFillerCountForTip = fillers
        }
    }
    
    func checkWPMTip(wpm: Int, duration: TimeInterval) {
        guard duration - lastTipTime > 25 else { return }
        showTip(.tooFast(wpm: wpm), duration: duration)
    }
    
    func checkSlowTip(wpm: Int, duration: TimeInterval) {
        guard duration - lastTipTime > 25 else { return }
        showTip(.tooSlow(wpm: wpm), duration: duration)
    }
    
    func checkEyeContactTip(duration: TimeInterval) {
        guard duration - lastTipTime > 30, duration > 5 else { return }
        showTip(.eyeContact, duration: duration)
    }
    
    func showTip(_ tip: LiveCoachTip, duration: TimeInterval) {
        guard !tipVisible else { return }
        lastTipTime = duration
        liveTip = tip
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { tipVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.4)) { self.tipVisible = false }
        }
    }
    
    func checkCognitiveLoadWarning(warning: Bool, duration: TimeInterval) {
        if warning {
            showTip(.cognitiveLoad, duration: duration)
        }
    }
    
    // MARK: - Formatters & Colors
    func wpmStatus(wpm: Int) -> String {
        switch wpm {
        case 130...150: return "Ideal"
        case 120..<130, 151...160: return "Good"
        case 100..<120: return "Slow"
        case 161..<180: return "Fast"
        case 0: return "Waiting"
        default: return wpm > 180 ? "Too fast" : "Too slow"
        }
    }
    
    func wpmColor(wpm: Int) -> Color {
        switch wpm {
        case 120...160: return Color.cadenceGood
        case 100..<120, 161..<180: return Color.cadenceNeutral
        case 0: return Color(.secondaryLabel)
        default: return Color.cadenceWarn
        }
    }
    
    func fillerStatus(count: Int) -> String {
        switch count {
        case 0: return "Flawless"
        case 1...3: return "Good"
        case 4...7: return "Notice"
        default: return "High"
        }
    }
    
    func fillerColor(count: Int) -> Color {
        count == 0 ? Color.cadenceGood
            : count < 5 ? Color.cadenceWarn : Color.cadenceBad
    }
    
    func rhythmStatus(stability: Double) -> String {
        guard stability >= 0 else { return "Waiting" }
        switch stability {
        case 85...100: return "Consistent"
        case 70..<85:  return "Steady"
        case 55..<70:  return "Decent"
        case 40..<55:  return "Uneven"
        default:       return "Choppy"
        }
    }
    
    func rhythmColor(stability: Double) -> Color {
        guard stability >= 0 else { return Color(.secondaryLabel) }
        switch stability {
        case 70...100: return Color.cadenceGood
        case 50..<70:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }
    
    func spontaneityLabel(score: Double) -> String {
        switch score {
        case 70...100: return "Natural"
        case 40..<70: return "Mixed"
        default: return "Scripted"
        }
    }
    
    func spontaneityColor(score: Double) -> Color {
        switch score {
        case 70...100: return Color.cadenceGood
        case 40..<70: return Color.cadenceNeutral
        default: return Color.cadenceWarn
        }
    }
}
