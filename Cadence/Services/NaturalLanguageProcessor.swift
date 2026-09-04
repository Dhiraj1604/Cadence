// NaturalLanguageProcessor.swift
// Cadence — Context-Aware NLP Filler Detection
//
// Philosophy: Cadence is a CONFIDENCE-BUILDING tool, not a grammar checker.
// Phrases like "you know", "I mean", "kind of" are natural parts of human speech.
// They only become fillers when used EXCESSIVELY in a short timeframe.
//
// Three-Tier Classification:
//   Tier 1 — HARD FILLERS: "um", "uh", "er" (always a filler, flagged immediately)
//   Tier 2 — DISCOURSE MARKERS: "you know", "I mean" (natural in moderation)
//   Tier 3 — CONTEXTUAL WORDS: "like", "so" (depends on part-of-speech context)

import Foundation
import NaturalLanguage

// MARK: - Filler Analysis Result

struct FillerAnalysisResult {
    /// Total count of words/phrases classified as fillers this session
    let totalFillerCount: Int
    /// List of filler words/phrases detected (for display)
    let detectedFillers: [String]
    /// New fillers detected since last analysis (for live event recording)
    let newFillers: [String]
    /// Confidence-positive feedback message
    let feedbackMessage: String
    /// Severity level for UI coloring
    let severity: FillerSeverity
}

enum FillerSeverity {
    case clean       // No fillers or well within acceptable range
    case gentle      // Slightly above threshold — gentle nudge
    case noticeable  // Clearly above threshold — actionable feedback
    case excessive   // Way above threshold — needs attention
}

// MARK: - NaturalLanguageProcessor

/// Context-aware filler word detection using Apple's NaturalLanguage framework.
/// Uses NLTagger for part-of-speech analysis to distinguish meaningful word usage
/// from filler usage (e.g., "I like pizza" vs "It was, like, amazing").
@MainActor
final class NaturalLanguageProcessor {

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Tier 1: Hard Fillers (always a filler, zero tolerance)
    // ─────────────────────────────────────────────────────────────────────
    // These sounds are NEVER intentional in public speaking.
    // Every single occurrence is a filler. Count them all immediately.
    private let hardFillers: Set<String> = [
        "um", "uh", "er", "hmm", "uhh", "umm", "erm", "ah", "ehh"
    ]

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Tier 2: Discourse Markers (natural in moderation)
    // ─────────────────────────────────────────────────────────────────────
    // Multi-word phrases that are part of natural conversational flow.
    // Only flagged when their RATE exceeds the threshold per minute.
    //
    // Thresholds are generous — set by public speaking coaching standards:
    //   "you know" — most common verbal check-in, allow ~1.5/min
    //   "I mean"   — clarification phrase, allow ~1.5/min
    //   "kind of"  — hedging phrase, allow ~1.0/min
    //   "sort of"  — hedging phrase, allow ~1.0/min
    private let discourseMarkers: [String: Double] = [
        "you know":   1.5,
        "i mean":     1.5,
        "kind of":    1.0,
        "sort of":    1.0
    ]

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Tier 3: Contextual Words (depends on part-of-speech)
    // ─────────────────────────────────────────────────────────────────────
    // These are real, useful English words. "like" as a verb is NOT a filler.
    // We use NLTagger to check the part-of-speech context.
    //
    // FILLER usage patterns (flagged):
    //   "It was, like, amazing"     → "like" as interjection/particle
    //   "So, so, so yeah"           → "so" as repetitive hedging
    //   "Okay so basically right"   → discourse filler chain
    //
    // MEANINGFUL usage patterns (NOT flagged):
    //   "I like pizza"              → "like" as verb
    //   "So the idea is..."         → "so" as conjunction
    //   "That's basically correct"  → "basically" as adverb modifying adjective
    //
    // Rate thresholds (per minute) — generous to avoid false positives:
    private let contextualWords: [String: Double] = [
        "like":       2.5,   // Very common — generous threshold
        "so":         2.5,   // Common sentence opener
        "right":      2.0,
        "okay":       2.0,
        "ok":         2.0,
        "actually":   1.5,
        "basically":  1.0,
        "literally":  1.0,
        "honestly":   1.5,
        "seriously":  1.0,
        "anyway":     1.5,
        "whatever":   0.8
    ]

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - NLTagger for Part-of-Speech Analysis
    // ─────────────────────────────────────────────────────────────────────
    private let tagger: NLTagger = {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        return tagger
    }()

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Session State
    // ─────────────────────────────────────────────────────────────────────
    private var previousHardFillerCount: Int = 0
    private var previousDiscourseMarkerCounts: [String: Int] = [:]
    private var previousContextualFlagCounts: [String: Int] = [:]
    private var allDetectedFillers: [String] = []

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Public API
    // ─────────────────────────────────────────────────────────────────────

    /// Reset all state for a new session
    func reset() {
        previousHardFillerCount = 0
        previousDiscourseMarkerCounts = [:]
        previousContextualFlagCounts = [:]
        allDetectedFillers = []
    }

    /// Analyze the full transcript for filler words using NLP context.
    ///
    /// Call this every time the transcript updates. It returns:
    /// - The total filler count for the session
    /// - Any NEW fillers detected since the last call (for live events)
    /// - A confidence-positive feedback message
    ///
    /// - Parameters:
    ///   - fullTranscript: The complete transcript text so far
    ///   - elapsedMinutes: How many minutes of speech have elapsed
    /// - Returns: A `FillerAnalysisResult` with counts, new detections, and feedback
    func analyze(fullTranscript: String, elapsedMinutes: Double) -> FillerAnalysisResult {
        let elapsed = max(0.15, elapsedMinutes) // Avoid division by zero
        let lowerTranscript = fullTranscript.lowercased()
        let words = lowerTranscript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        var newFillers: [String] = []
        var totalCount = 0

        // ── Tier 1: Hard fillers — count every occurrence ─────────────
        let hardCount = words.filter { hardFillers.contains($0) }.count
        if hardCount > previousHardFillerCount {
            let newOnes = hardCount - previousHardFillerCount
            let hardWords = words.filter { hardFillers.contains($0) }
            let suffix = Array(hardWords.suffix(newOnes))
            newFillers.append(contentsOf: suffix)
        }
        previousHardFillerCount = hardCount
        totalCount += hardCount

        // ── Tier 2: Discourse markers — rate-based detection ──────────
        var discourseFillerCount = 0
        for (phrase, threshold) in discourseMarkers {
            let occurrences = countPhrase(phrase, in: lowerTranscript)
            let rate = Double(occurrences) / elapsed
            let previousCount = previousDiscourseMarkerCounts[phrase, default: 0]

            if rate > threshold && occurrences > previousCount {
                // Only count occurrences ABOVE the threshold rate
                let excessCount = max(0, occurrences - Int(threshold * elapsed))
                discourseFillerCount += excessCount

                if occurrences > previousCount {
                    let newOccurrences = occurrences - previousCount
                    for _ in 0..<min(newOccurrences, 3) {
                        newFillers.append(phrase)
                    }
                }
            }
            previousDiscourseMarkerCounts[phrase] = occurrences
        }
        totalCount += discourseFillerCount

        // ── Tier 3: Contextual words — POS-aware detection ────────────
        var contextFillerCount = 0
        for (word, threshold) in contextualWords {
            let occurrences = words.filter { $0 == word }.count
            let rate = Double(occurrences) / elapsed
            let previousFlagCount = previousContextualFlagCounts[word, default: 0]

            if rate > threshold && occurrences > 0 {
                // Use NLTagger to check how many are actually filler usage
                let fillerUsages = countFillerUsages(of: word, in: fullTranscript)
                let flaggable = max(0, fillerUsages - Int(threshold * elapsed))

                if flaggable > previousFlagCount {
                    let newFlags = flaggable - previousFlagCount
                    for _ in 0..<min(newFlags, 3) {
                        newFillers.append(word)
                    }
                }
                previousContextualFlagCounts[word] = flaggable
                contextFillerCount += flaggable
            }
        }
        totalCount += contextFillerCount

        // ── Track all detected fillers ────────────────────────────────
        allDetectedFillers.append(contentsOf: newFillers)

        // ── Build feedback ────────────────────────────────────────────
        let fillersPerMin = Double(totalCount) / elapsed
        let severity: FillerSeverity
        let feedback: String

        switch fillersPerMin {
        case 0:
            severity = .clean
            feedback = "Clean speech flow — no fillers detected ✓"
        case ..<1.5:
            severity = .clean
            feedback = "Natural speech flow — well within normal range ✓"
        case ..<3.0:
            severity = .gentle
            feedback = "Slight filler habit forming — try pausing instead"
        case ..<5.0:
            severity = .noticeable
            feedback = "Fillers are becoming noticeable — replace with confident pauses"
        default:
            severity = .excessive
            feedback = "High filler rate — pause and breathe before each thought"
        }

        return FillerAnalysisResult(
            totalFillerCount: totalCount,
            detectedFillers: allDetectedFillers,
            newFillers: newFillers,
            feedbackMessage: feedback,
            severity: severity
        )
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────────────────────────────────────

    /// Count occurrences of a multi-word phrase in text
    private func countPhrase(_ phrase: String, in text: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: phrase, options: .caseInsensitive, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
        }
        return count
    }

    /// Use NLTagger to count how many times a word is used as a FILLER
    /// rather than in its meaningful grammatical role.
    ///
    /// For example:
    ///   "I like pizza"           → "like" is Verb        → NOT filler
    ///   "It was, like, amazing"  → "like" is Interjection → IS filler
    ///   "People like you"        → "like" is Preposition  → NOT filler
    private func countFillerUsages(of targetWord: String, in text: String) -> Int {
        tagger.string = text

        // Parts of speech that indicate MEANINGFUL usage (not a filler)
        let meaningfulTags: Set<NLTag> = [
            .verb,           // "I like pizza"
            .preposition,    // "People like you"
            .conjunction,    // "So the idea is..."
            .adjective,      // "The actual result"
            .adverb          // "Actually, that's correct" (when modifying a verb)
        ]

        let targetLower = targetWord.lowercased()
        var fillerCount = 0
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()
                .trimmingCharacters(in: .punctuationCharacters)

            if word == targetLower {
                if let tag = tag, meaningfulTags.contains(tag) {
                    // Meaningful usage — NOT a filler
                } else {
                    // Interjection, particle, other, or unrecognized → likely filler
                    fillerCount += 1
                }
            }
            return true
        }

        return fillerCount
    }
}
