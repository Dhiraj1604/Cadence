// InsightsView.swift
// Cadence — Insights redesign
// • Session type tag (Live Practice vs Record & Review)
// • Real metric breakdown replaces useless speech signature line
// • Multi-metric performance trend (score + WPM + eye contact)

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        ZStack {
            Color.cadenceBG.ignoresSafeArea()
            NavigationStack {
                Group {
                    if session.sessionHistory.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                statTiles.padding(.top, 8)
                                performanceTrend
                                sessionHistory
                            }
                            .padding(.bottom, 48)
                        }
                    }
                }
                .navigationTitle("Progress")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(Color.cadenceBG, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Color.mint.opacity(0.5))
            Text("No Sessions Yet").font(.title2.bold()).foregroundStyle(.white)
            Text("Complete your first practice session\nto see your progress here.")
                .font(.subheadline).foregroundStyle(Color.white.opacity(0.4))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var statTiles: some View {
        HStack(spacing: 10) {
            InsightStatTile(value: "\(session.totalSessions)", label: "Sessions",
                            icon: "mic.fill", color: .mint)
            InsightStatTile(value: "\(session.averageWPM)", label: "Avg WPM",
                            icon: "speedometer", color: .yellow)
            InsightStatTile(value: totalTimeLabel(session.totalPracticeTime),
                            label: "Practice", icon: "timer", color: .cyan)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var performanceTrend: some View {
        if session.sessionHistory.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                CadenceSectionHeader(title: "Performance Trend")
                    .padding(.horizontal, 16)
                PerformanceTrendCard(history: session.sessionHistory)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            CadenceSectionHeader(title: "Session History")
                .padding(.horizontal, 16)
            ForEach(session.sessionHistory) { record in
                InsightSessionCard(record: record)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func totalTimeLabel(_ t: TimeInterval) -> String {
        let s = Int(t)
        if s < 60   { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}

// MARK: - Stat Tile
struct InsightStatTile: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.caption.weight(.bold))
                .foregroundStyle(color).symbolRenderingMode(.hierarchical)
            Text(value).font(.title2.bold().monospacedDigit())
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Performance Trend Card
// Three smooth curves: overall score, WPM normalised, eye contact.
// At a glance you see if each metric is trending up or down.
struct PerformanceTrendCard: View {
    let history: [SessionRecord]
    private var ordered: [SessionRecord] { history.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Are You Improving?")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("Overall score, pace and eye contact trend")
                        .font(.caption).foregroundStyle(Color.white.opacity(0.35))
                }
                Spacer()
                if let best = ordered.max(by: { $0.performanceScore < $1.performanceScore }) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Label("Best: \(best.performanceScore)", systemImage: "crown.fill")
                            .font(.caption.weight(.bold)).foregroundStyle(.yellow)
                        Text("session score").font(.caption2).foregroundStyle(Color.white.opacity(0.3))
                    }
                }
            }

            GeometryReader { geo in
                ZStack {
                    // Ideal zone stripe
                    Rectangle()
                        .fill(Color.mint.opacity(0.05))
                        .frame(width: geo.size.width, height: geo.size.height * 0.3)
                        .offset(y: geo.size.height * 0.05)

                    TrendLine(values: ordered.map { Double($0.performanceScore) },
                              minV: 0, maxV: 100, color: .mint)
                    TrendLine(values: ordered.map { min(Double($0.wpm), 200) },
                              minV: 0, maxV: 200, color: .cyan.opacity(0.65))
                    TrendLine(values: ordered.map { Double($0.eyeContact) },
                              minV: 0, maxV: 100, color: Color.purple.opacity(0.65))
                }
            }
            .frame(height: 80)

            HStack(spacing: 16) {
                legendDot(.mint,                "Score /100")
                legendDot(.cyan.opacity(0.8),   "WPM")
                legendDot(.purple.opacity(0.8), "Eye Contact %")
            }
        }
        .padding(14)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.mint.opacity(0.10), lineWidth: 1))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.4))
        }
    }
}

struct TrendLine: View {
    let values: [Double]
    let minV: Double; let maxV: Double
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard values.count >= 2 else { return }
            let n = values.count
            var path = Path()
            for (i, val) in values.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(n - 1)
                let y = size.height * (1 - CGFloat((val - minV) / max(maxV - minV, 1)))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else {
                    let prev = values[i - 1]
                    let px = size.width * CGFloat(i - 1) / CGFloat(n - 1)
                    let py = size.height * (1 - CGFloat((prev - minV) / max(maxV - minV, 1)))
                    path.addCurve(to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: (px + x) / 2, y: py),
                        control2: CGPoint(x: (px + x) / 2, y: y))
                }
            }
            ctx.stroke(path, with: .color(color),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            // End dot
            if let last = values.last {
                let x = size.width
                let y = size.height * (1 - CGFloat((last - minV) / max(maxV - minV, 1)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                         with: .color(color))
            }
        }
    }
}

// MARK: - Session Card
struct InsightSessionCard: View {
    let record: SessionRecord
    @State private var expanded = false

    private var typeTag: some View {
        HStack(spacing: 4) {
            Image(systemName: record.isVideoSession ? "video.fill" : "mic.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(record.isVideoSession ? "Record & Review" : "Live Practice")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(record.isVideoSession ? Color.cyan : Color.mint)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background((record.isVideoSession ? Color.cyan : Color.mint).opacity(0.12))
        .clipShape(Capsule())
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { expanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    // Score ring
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.10), lineWidth: 2.5)
                            .frame(width: 48, height: 48)
                        Circle()
                            .trim(from: 0, to: CGFloat(record.performanceScore) / 100)
                            .stroke(record.scoreColor,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 48, height: 48).rotationEffect(.degrees(-90))
                        Text("\(record.performanceScore)")
                            .font(.caption.weight(.heavy).monospacedDigit())
                            .foregroundStyle(record.scoreColor)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(record.dateString)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.45))
                            StatBadge(text: record.durationString, color: .mint)
                        }
                        typeTag
                    }

                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().background(Color.white.opacity(0.07))
                // Compact signature strip
                if !record.flowEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.mint.opacity(0.6))
                            Text("Speech Signature")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        CompactSpeechSignature(data: record.signatureData)
                            .frame(height: 36)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }
                SessionMetricBreakdown(record: record)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.mint.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Session Metric Breakdown
// Shown when a session card is expanded. Real numbers, contextual labels.
struct SessionMetricBreakdown: View {
    let record: SessionRecord

    var body: some View {
        VStack(spacing: 10) {
            metricRow("speedometer", "\(record.wpm) WPM",
                wpmLabel, wpmColor)
            metricRow("exclamationmark.bubble", "\(record.fillers) filler\(record.fillers == 1 ? "" : "s")",
                fillerLabel, fillerColor)
            metricRow("eye", "\(record.eyeContact)% eye contact",
                eyeLabel, eyeColor)
            if !record.isVideoSession {
                metricRow("waveform.path",
                    String(format: "%.0f%% rhythm", record.rhythmStability),
                    rhythmLabel, rhythmColor)
            }
            if !record.transcript.isEmpty && record.transcript != "No transcript available." {
                Divider().background(Color.white.opacity(0.07)).padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 5) {
                    Label("Transcript", systemImage: "text.quote")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Text(record.transcript.count > 220
                         ? String(record.transcript.prefix(220)) + "…"
                         : record.transcript)
                        .font(.caption).foregroundStyle(Color.white.opacity(0.55))
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metricRow(_ icon: String, _ value: String,
                            _ label: String, _ color: Color) -> some View {
        HStack {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
                .symbolRenderingMode(.hierarchical).frame(width: 18)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(.white)
            Spacer()
            Text(label).font(.caption.weight(.medium)).foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.12)).clipShape(Capsule())
        }
    }

    // WPM
    private var wpmColor: Color {
        switch record.wpm {
        case 130...150: return .mint
        case 110..<130, 151...170: return .yellow
        default: return .orange
        }
    }
    private var wpmLabel: String {
        switch record.wpm {
        case 130...150: return "Ideal ✓"
        case 110..<130: return "Slightly slow"
        case 151...170: return "Slightly fast"
        case 171...: return "Too fast"
        default: return "Too slow"
        }
    }
    // Fillers
    private var fillerColor: Color { record.fillers == 0 ? .mint : record.fillers < 4 ? .yellow : .orange }
    private var fillerLabel: String { record.fillers == 0 ? "Flawless" : record.fillers < 4 ? "Manageable" : "Too many" }
    // Eye contact
    private var eyeColor: Color { record.eyeContact >= 75 ? .mint : record.eyeContact >= 50 ? .yellow : .orange }
    private var eyeLabel: String { record.eyeContact >= 75 ? "Excellent" : record.eyeContact >= 50 ? "Good" : "Needs work" }
    // Rhythm
    private var rhythmColor: Color { record.rhythmStability >= 75 ? .mint : record.rhythmStability >= 50 ? .yellow : .orange }
    private var rhythmLabel: String { record.rhythmStability >= 75 ? "Consistent" : record.rhythmStability >= 50 ? "Moderate" : "Choppy" }
}
