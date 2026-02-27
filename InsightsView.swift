// InsightsView.swift
// Cadence — iOS 26 Native Liquid Glass

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
                        VStack(spacing: 20) {

                            // ── Summary Row ─────────────────────────
                            HStack(spacing: 14) {
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
                            .padding(.top, 12)

                            // ── WPM Trend ─────────────────────────
                            if session.sessionHistory.count >= 2 {
                                WPMTrendCard(history: session.sessionHistory)
                                    .padding(.horizontal, 20)
                            }

                            // ── Session History ───────────────────
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Session History")
                                    .font(.system(size: 18, weight: .bold))
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
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 10) {
                Text("No sessions yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Complete your first practice session\nto see your progress here.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
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
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WPM Trend")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your pace over time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    let best = wpmValues.max() ?? 0
                    Text("Best: \(best)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.mint)
                    Text("Ideal: 130–150")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
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
                        .fill(Color.mint.opacity(0.1))
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
                        .stroke(.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .shadow(color: .mint.opacity(0.5), radius: 4)

                        ForEach(wpmValues.indices, id: \.self) { i in
                            let x = w * CGFloat(i) / CGFloat(wpmValues.count - 1)
                            let y = h - h * CGFloat(wpmValues[i] - minVal) / CGFloat(range)
                            Circle()
                                .fill(.mint)
                                .frame(width: 8, height: 8)
                                .position(x: x, y: y)
                                .shadow(color: .mint, radius: 4)
                        }
                    }
                }
            }
            .frame(height: 80)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
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
            HStack(spacing: 16) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(record.scoreColor.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: CGFloat(record.performanceScore) / 100.0)
                        .stroke(record.scoreColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: record.scoreColor.opacity(0.4), radius: 4)
                    Text("\(record.performanceScore)")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(record.scoreColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(record.dateString)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Text(record.durationString)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.15))
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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            }

            // Expanded: compact signature
            if expanded {
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(record.scoreColor)
                        Text("Speech Signature")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    CompactSpeechSignature(data: signatureData)
                }
                .padding(16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
        .environment(\.colorScheme, .dark)
    }
}

struct InsightStatPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
    }
}
