//
//  InsightsView.swift
//  Cadence
//
//  Created by Dhiraj on 26/02/26.
//

// InsightsView.swift
// Cadence — SSC Edition
// Tab 4: Progress Dashboard

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.06, blue: 0.05), .black],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if session.sessionHistory.isEmpty {
                    EmptyProgressView()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {

                            // ── Summary Row ─────────────────────────
                            HStack(spacing: 12) {
                                ProgressStatCard(
                                    value: "\(session.totalSessions)",
                                    label: "Sessions",
                                    icon: "mic.fill",
                                    color: .mint
                                )
                                ProgressStatCard(
                                    value: "\(session.averageWPM)",
                                    label: "Avg WPM",
                                    icon: "speedometer",
                                    color: .yellow
                                )
                                ProgressStatCard(
                                    value: totalTimeLabel(session.totalPracticeTime),
                                    label: "Practice",
                                    icon: "timer",
                                    color: .purple
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            // ── WPM Trend ───────────────────────────
                            if session.sessionHistory.count >= 2 {
                                WPMTrendCard(history: session.sessionHistory)
                                    .padding(.horizontal, 20)
                            }

                            // ── Session History ─────────────────────
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recent Sessions")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)

                                ForEach(session.sessionHistory) { record in
                                    SessionHistoryCard(record: record)
                                        .padding(.horizontal, 20)
                                }
                            }

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }

    private func totalTimeLabel(_ t: TimeInterval) -> String {
        let seconds = Int(t)
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}

// MARK: - Empty State
struct EmptyProgressView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 52, weight: .thin))
                .foregroundColor(Color(white: 0.25))
            VStack(spacing: 8) {
                Text("No sessions yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text("Complete your first practice session\nto see your progress here.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - Stat Card
struct ProgressStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color.opacity(0.8))
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.38))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}

// MARK: - WPM Trend Sparkline
struct WPMTrendCard: View {
    let history: [SessionRecord]

    // oldest → newest (left → right)
    private var wpmValues: [Int] {
        history.reversed().map { $0.wpm }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WPM Trend")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Your pace over time")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.38))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let best = wpmValues.max() ?? 0
                    Text("Best: \(best)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.mint)
                    Text("Ideal: 130–150")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.3))
                }
            }

            GeometryReader { geo in
                let maxVal = max(wpmValues.max() ?? 1, 200)
                let minVal = max((wpmValues.min() ?? 0) - 10, 0)
                let range = max(maxVal - minVal, 1)
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .topLeading) {
                    // Ideal zone band
                    let idealTop = h - h * CGFloat(160 - minVal) / CGFloat(range)
                    let idealHeight = h * CGFloat(40) / CGFloat(range)
                    Rectangle()
                        .fill(Color.mint.opacity(0.06))
                        .frame(width: w, height: max(idealHeight, 0))
                        .offset(y: max(idealTop, 0))

                    // Sparkline
                    if wpmValues.count >= 2 {
                        Path { path in
                            for (i, val) in wpmValues.enumerated() {
                                let x = w * CGFloat(i) / CGFloat(wpmValues.count - 1)
                                let y = h - h * CGFloat(val - minVal) / CGFloat(range)
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.mint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        ForEach(wpmValues.indices, id: \.self) { i in
                            let x = w * CGFloat(i) / CGFloat(wpmValues.count - 1)
                            let y = h - h * CGFloat(wpmValues[i] - minVal) / CGFloat(range)
                            Circle()
                                .fill(Color.mint)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 72)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - Session History Card
struct SessionHistoryCard: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 14) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(record.scoreColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(record.performanceScore) / 100.0)
                    .stroke(record.scoreColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                Text("\(record.performanceScore)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(record.scoreColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(record.dateString)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                    Text(record.durationString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.35))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }

                HStack(spacing: 12) {
                    InsightStatPill(text: "\(record.wpm) WPM", color: .mint)
                    InsightStatPill(
                        text: "\(record.fillers) fillers",
                        color: record.fillers > 5 ? .red : .orange
                    )
                    InsightStatPill(
                        text: "\(record.eyeContact)% eye",
                        color: record.eyeContact > 70 ? .cyan : .yellow
                    )
                }
            }

            Spacer()

            Text(record.scoreBadge)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(record.scoreColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(record.scoreColor.opacity(0.15))
                .cornerRadius(12)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct InsightStatPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
    }
}
