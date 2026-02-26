// Summary View
//  SummaryView.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                Text("Session Complete")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 50)

                // MARK: Coaching Card — most important, shown first
                CoachingInsightView(
                    wpm: session.finalWPM,
                    fillers: session.finalFillers,
                    attention: session.finalAttentionScore,
                    rhythm: session.finalRhythmStability,
                    events: session.finalFlowEvents
                )
                .padding(.horizontal, 20)

                // MARK: Speech DNA Timeline
                SpeechTimelineView(
                    events: session.finalFlowEvents,
                    duration: session.duration
                )
                .padding(.horizontal, 20)

                // MARK: Metrics Grid
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 14
                ) {
                    SummaryCard(
                        title: "Pacing",
                        value: "\(session.finalWPM)",
                        unit: "Words / Min",
                        color: .teal
                    )
                    SummaryCard(
                        title: "Filler Words",
                        value: "\(session.finalFillers)",
                        unit: "Total Count",
                        color: .orange
                    )
                    SummaryCard(
                        title: "Eye Contact",
                        value: "\(session.eyeContactPercentage)%",
                        unit: "Of Total Time",
                        color: .green
                    )
                    SummaryCard(
                        title: "Rhythm",
                        value: String(format: "%.0f%%", session.finalRhythmStability),
                        unit: "Stability",
                        color: session.finalRhythmStability > 70 ? .mint : .orange
                    )
                }
                .padding(.horizontal, 20)

                // MARK: Transcript
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Transcript")
                        .font(.headline)
                        .foregroundColor(.white)
                    ScrollView {
                        Text(session.finalTranscript)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                    .padding()
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)

                Button {
                    withAnimation { session.resetSession() }
                } label: {
                    Text("Practice Again")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.mint)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Speech DNA Timeline
struct SpeechTimelineView: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speech Flow DNA")
                .font(.headline)
                .foregroundColor(.white)

            Text("Your complete session — every moment visible")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 48)

                    // Mint base fill = spoken time
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.mint.opacity(0.12))
                        .frame(height: 48)

                    // Event markers
                    ForEach(events) { event in
                        let x = duration > 1
                            ? geo.size.width * CGFloat(event.timestamp / duration)
                            : 0
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.color)
                                .frame(width: 5, height: 34)
                            Text(event.label)
                                .font(.system(size: 6, weight: .semibold))
                                .foregroundColor(event.color)
                                .lineLimit(1)
                        }
                        .offset(x: min(max(x - 2.5, 0), geo.size.width - 5))
                    }
                }
            }
            .frame(height: 60)

            // Legend
            HStack(spacing: 14) {
                LegendDot(color: .mint,   label: "Strong")
                LegendDot(color: .orange, label: "Filler")
                LegendDot(color: .yellow, label: "Pause")
                LegendDot(color: .red,    label: "Lost Flow")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Coaching Insight Card
struct CoachingInsightView: View {
    let wpm: Int
    let fillers: Int
    let attention: Double
    let rhythm: Double
    let events: [FlowEvent]

    private var insight: (icon: String, color: Color, title: String, message: String) {
        let flowBreaks = events.filter {
            if case .flowBreak = $0.type { return true }
            return false
        }.count

        if flowBreaks >= 3 {
            return (
                "brain.head.profile", .red,
                "High Cognitive Load Detected",
                "You lost flow \(flowBreaks) times — your brain was searching for words. Next time, pause silently instead of filling with 'um'. Silence is powerful."
            )
        } else if fillers > 8 {
            return (
                "exclamationmark.bubble.fill", .orange,
                "Filler Word Habit Detected",
                "You used \(fillers) filler words. Your most common ones are working against you. Replace them with a 1-second pause — it sounds 10x more confident."
            )
        } else if wpm > 175 {
            return (
                "hare.fill", .yellow,
                "You're Speaking Too Fast",
                "At \(wpm) WPM your audience can't keep up. Aim for 130–155 WPM. Slow down on key points — let them land."
            )
        } else if wpm < 100 && wpm > 5 {
            return (
                "tortoise.fill", .yellow,
                "Pace Is Too Slow",
                "At \(wpm) WPM you risk losing attention. Bring more energy — think 130–150 WPM for natural, engaging delivery."
            )
        } else if attention > 80 && fillers < 4 {
            return (
                "star.fill", .mint,
                "Outstanding Delivery",
                "Audience attention stayed above 80% and you barely used filler words. This is what confident, clear speaking looks like. Keep it up."
            )
        } else {
            return (
                "chart.line.uptrend.xyaxis", .teal,
                "Solid Session",
                "Rhythm stability: \(Int(rhythm))%. The more you practice, the more natural this flow becomes. You're building real skill."
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundColor(insight.color)
                .frame(width: 32)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(insight.color.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(insight.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(unit)
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
    }
}
