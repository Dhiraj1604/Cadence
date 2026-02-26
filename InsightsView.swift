// InsightsView.swift
// Cadence — iOS 26 Native
// UPDATED: Session history cards now include compact Speech Signature previews.
// Each past session shows its unique visual fingerprint at a glance.

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        NavigationStack {
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

                            // ── WPM Trend ─────────────────────────
                            if session.sessionHistory.count >= 2 {
                                WPMTrendCard(history: session.sessionHistory)
                                    .padding(.horizontal, 20)
                            }

                            // ── Session History ───────────────────
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Session History")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)

                                ForEach(session.sessionHistory) { record in
                                    EnhancedSessionCard(record: record)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
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
            ZStack {
                Circle()
                    .fill(Color(white: 0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundStyle(Color(white: 0.3))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 8) {
                Text("No sessions yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Complete your first practice session\nto see your progress here.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(white: 0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .foregroundStyle(color.opacity(0.9))
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(white: 0.38))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - WPM Trend Sparkline
struct WPMTrendCard: View {
    let history: [SessionRecord]

    private var wpmValues: [Int] {
        history.reversed().map { $0.wpm }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WPM Trend")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Your pace over time")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(white: 0.38))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    let best = wpmValues.max() ?? 0
                    Text("Best: \(best)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.mint)
                    Text("Ideal: 130–150")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(white: 0.3))
                }
            }

            GeometryReader { geo in
                let maxVal = max(wpmValues.max() ?? 1, 200)
                let minVal = max((wpmValues.min() ?? 0) - 10, 0)
                let range = max(maxVal - minVal, 1)
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .topLeading) {
                    let idealTop = h - h * CGFloat(160 - minVal) / CGFloat(range)
                    let idealHeight = h * CGFloat(40) / CGFloat(range)
                    Rectangle()
                        .fill(Color.mint.opacity(0.07))
                        .frame(width: w, height: max(idealHeight, 0))
                        .offset(y: max(idealTop, 0))

                    if wpmValues.count >= 2 {
                        Path { path in
                            for (i, val) in wpmValues.enumerated() {
                                let x = w * CGFloat(i) / CGFloat(wpmValues.count - 1)
                                let y = h - h * CGFloat(val - minVal) / CGFloat(range)
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(.mint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        ForEach(wpmValues.indices, id: \.self) { i in
                            let x = w * CGFloat(i) / CGFloat(wpmValues.count - 1)
                            let y = h - h * CGFloat(wpmValues[i] - minVal) / CGFloat(range)
                            Circle()
                                .fill(.mint)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 72)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Enhanced Session Card (with Speech Signature)

struct EnhancedSessionCard: View {
    let record: SessionRecord
    @State private var expanded = false

    private var signatureData: SpeechSignatureData {
        record.signatureData
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
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
                        .foregroundStyle(record.scoreColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(record.dateString)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(white: 0.45))
                        Text(record.durationString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(white: 0.35))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
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

                // Expand chevron
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.3))
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            }

            // Expanded: compact signature
            if expanded {
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(record.scoreColor)
                        Text("Speech Signature")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.4))
                    }
                    CompactSpeechSignature(data: signatureData)
                }
                .padding(14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session: score \(record.performanceScore), \(record.wpm) WPM, \(record.fillers) fillers, \(record.durationString)")
    }
}

struct InsightStatPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
    }
}
