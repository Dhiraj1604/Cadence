// SpeechSignatureView.swift
// Cadence — Vocal Spectrogram Redesign
//
// Each session generates a unique "vocal fingerprint":
//   • Vertical bars = energy at each moment (height = intensity)
//   • Color = event type (mint = strong, orange = filler, gray = hesitation)
//   • GAPS between bars = pauses / silence (choppy speech looks choppy)
//   • Envelope curve connects bar tops to show overall energy arc
//
// This makes the visualization immediately readable:
//   Confident speech  → dense, tall green bars (no gaps)
//   Choppy speech     → sparse bars with visible white space between
//   Filler habit      → orange bars interrupt the green flow
//   Great session     → rising arc from start to peak to close

import SwiftUI

struct SpeechCanvasPoint: Identifiable {
    let id = UUID()
    let progress: Double
    let intensity: Double
    let isFiller: Bool
    let hasEyeContact: Bool
}

struct SpeechSignatureView: View {
    var dataPoints: [SpeechCanvasPoint]

    var body: some View {
        GeometryReader { size in
            Canvas { ctx, sz in
                drawSpectrogram(ctx: ctx, size: sz)
            }
        }
        .drawingGroup()
    }

    private func drawSpectrogram(ctx: GraphicsContext, size: CGSize) {
        guard !dataPoints.isEmpty else {
            // Empty state: flat dashed baseline
            var base = Path()
            base.move(to: CGPoint(x: 0, y: size.height / 2))
            base.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(base, with: .color(.white.opacity(0.1)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            return
        }

        let w = size.width
        let h = size.height
        let baseline = h * 0.72   // bars grow upward from here
        let maxBarH  = h * 0.65   // tallest possible bar

        // ── 1. Baseline ─────────────────────────────────────────────────
        var basePath = Path()
        basePath.move(to: CGPoint(x: 0, y: baseline))
        basePath.addLine(to: CGPoint(x: w, y: baseline))
        ctx.stroke(basePath, with: .color(.white.opacity(0.07)), lineWidth: 1)

        // ── 2. Compute bar positions ────────────────────────────────────
        // Sort by progress so bars always go left → right
        let sorted = dataPoints.sorted { $0.progress < $1.progress }

        // Bar width: smaller = more detail, but we need room for gaps.
        // Cap at a visible minimum so short sessions still look good.
        let totalBars = sorted.count
        let barWidth  = max(4.0, min(14.0, w / CGFloat(totalBars + 1) * 0.55))
        let _ = barWidth * 0.35

        // ── 3. Collect bar top points for envelope curve ────────────────
        var envelopePts: [CGPoint] = [CGPoint(x: 0, y: baseline)]

        // ── 4. Draw bars ────────────────────────────────────────────────
        for pt in sorted {
            let cx     = pt.progress * Double(w)
            let barH   = CGFloat(pt.intensity) * maxBarH
            let top    = baseline - barH

            // Bar color: filler = amber, low eye contact = dimmed mint, strong = mint
            let barColor: Color
            if pt.isFiller {
                barColor = Color(red: 1.0, green: 0.62, blue: 0.04) // amber
            } else if !pt.hasEyeContact {
                barColor = Color.mint.opacity(0.30)
            } else {
                // Tint from teal→cyan based on intensity
                let t = CGFloat(pt.intensity)
                barColor = Color(red: 0.0 + t * 0.1,
                                 green: 0.78 + t * 0.12,
                                 blue:  0.75 + t * 0.15)
            }

            // Glow halo behind bar (only for strong moments)
            if pt.intensity > 0.7 && !pt.isFiller {
                let haloRect = CGRect(
                    x: CGFloat(cx) - barWidth * 1.2,
                    y: top - 4,
                    width: barWidth * 2.4,
                    height: barH + 4
                )
                let halo = Path(roundedRect: haloRect, cornerRadius: barWidth * 0.6)
                ctx.fill(halo, with: .color(Color.mint.opacity(0.12)))
            }

            // Main bar (rounded top)
            let barRect = CGRect(
                x: CGFloat(cx) - barWidth / 2,
                y: top,
                width: barWidth,
                height: barH
            )
            let barPath = Path(roundedRect: barRect, cornerRadius: barWidth * 0.4)

            // Gradient fill: brighter at top, fades to base
            ctx.fill(barPath, with: .color(barColor.opacity(0.85)))

            // Subtle highlight line on left edge of bar
            var edgeLine = Path()
            edgeLine.move(to: CGPoint(x: CGFloat(cx) - barWidth / 2 + 1, y: top + 2))
            edgeLine.addLine(to: CGPoint(x: CGFloat(cx) - barWidth / 2 + 1, y: baseline - 2))
            ctx.stroke(edgeLine, with: .color(.white.opacity(0.18)), lineWidth: 0.8)

            // Filler marker: small diamond on top
            if pt.isFiller {
                let dSz: CGFloat = 5
                var diamond = Path()
                diamond.move(to: CGPoint(x: CGFloat(cx),         y: top - dSz - 2))
                diamond.addLine(to: CGPoint(x: CGFloat(cx) + dSz, y: top - 2))
                diamond.addLine(to: CGPoint(x: CGFloat(cx),        y: top + dSz - 2))
                diamond.addLine(to: CGPoint(x: CGFloat(cx) - dSz,  y: top - 2))
                diamond.closeSubpath()
                ctx.fill(diamond, with: .color(barColor))
            }

            envelopePts.append(CGPoint(x: CGFloat(cx), y: top))
        }

        envelopePts.append(CGPoint(x: w, y: baseline))

        // ── 5. Smooth envelope curve over all bar tops ──────────────────
        // This shows the overall energy arc of the session
        if envelopePts.count >= 3 {
            var envelope = Path()
            envelope.move(to: envelopePts[0])
            for i in 1..<envelopePts.count {
                let curr = envelopePts[i]
                let prev = envelopePts[i - 1]
                let ctrl = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
                envelope.addQuadCurve(to: ctrl, control: prev)
            }
            if let last = envelopePts.last {
                envelope.addLine(to: last)
            }
            ctx.stroke(envelope,
                       with: .color(Color.mint.opacity(0.22)),
                       style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round, dash: [3, 4]))
        }

        // ── 6. Time ruler: tiny tick marks at 25% / 50% / 75% ──────────
        for frac in [0.25, 0.5, 0.75] {
            let tx = CGFloat(frac) * w
            var tick = Path()
            tick.move(to: CGPoint(x: tx, y: baseline + 3))
            tick.addLine(to: CGPoint(x: tx, y: baseline + 7))
            ctx.stroke(tick, with: .color(.white.opacity(0.12)), lineWidth: 1)
        }

        // ── 7. Label: "START" and "END" at edges ───────────────────────
        // (only drawn if there's room — minimum width 200pt)
        if w > 200 {
            let labelAttr = AttributedString("START",
                attributes: AttributeContainer().font(.system(size: 7, weight: .medium, design: .monospaced)))
            let endAttr   = AttributedString("END",
                attributes: AttributeContainer().font(.system(size: 7, weight: .medium, design: .monospaced)))
            ctx.draw(Text(labelAttr).foregroundColor(.white.opacity(0.18)),
                     at: CGPoint(x: 14, y: baseline + 12), anchor: .center)
            ctx.draw(Text(endAttr).foregroundColor(.white.opacity(0.18)),
                     at: CGPoint(x: w - 14, y: baseline + 12), anchor: .center)
        }
    }
}

// MARK: - Compact signature used in InsightsView session cards
struct CompactSpeechSignature: View {
    var data: SpeechSignatureData

    var body: some View {
        GeometryReader { geometry in
            speechPath(in: geometry.size)
                .stroke(
                    LinearGradient(
                        colors: [Color.cadenceAccent, Color.cadenceAccent.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
        }
    }

    private func speechPath(in size: CGSize) -> Path {
        let events = data.flowEvents
        let w = size.width
        let h = size.height
        let midY = h / 2
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))

        guard !events.isEmpty else {
            path.addLine(to: CGPoint(x: w, y: midY))
            return path
        }

        let maxTime = max(data.duration, events.map { $0.timestamp }.max() ?? 1.0, 1.0)
        var prev = CGPoint(x: 0, y: midY)

        for (i, event) in events.enumerated() {
            let x = w * CGFloat(event.timestamp / maxTime)
            let amplitude: CGFloat
            switch event.type {
            case .strongMoment: amplitude = h * 0.40
            case .flowBreak:    amplitude = h * 0.36
            case .filler:       amplitude = h * 0.26
            case .hesitation:   amplitude = h * 0.14
            }
            let direction: CGFloat = sin(Double(i) * 1.15) >= 0 ? 1 : -1
            let curr = CGPoint(x: x, y: midY + direction * amplitude)
            let ctrlX = prev.x + (curr.x - prev.x) / 2
            path.addCurve(to: curr,
                control1: CGPoint(x: ctrlX, y: prev.y),
                control2: CGPoint(x: ctrlX, y: curr.y))
            prev = curr
        }
        path.addLine(to: CGPoint(x: w, y: midY))
        return path
    }
}

// MARK: - Session Timeline View
// Replaces Speech Signature + Speech Journey with a simple, intuitive visualisation.
// Divides the session into equal time slots. Each slot is coloured by the most
// significant event that occurred in it. Anyone can read it instantly:
//   Green = strong speaking · Orange = filler · Yellow = pause · Red = lost flow · Gray = quiet
struct SessionTimelineView: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    // Number of slots adapts to session length for visual clarity
    private var slotCount: Int {
        let secs = Int(duration)
        if secs <= 15 { return max(5, secs / 2) }
        if secs <= 60 { return 15 }
        if secs <= 120 { return 20 }
        return 24
    }

    private var slotDuration: Double {
        guard slotCount > 0 else { return 1 }
        return duration / Double(slotCount)
    }

    /// Returns the priority colour for a time slot based on events within it.
    /// Priority: flowBreak > filler > hesitation > strongMoment > no data
    private func colorForSlot(_ index: Int) -> Color {
        let start = Double(index) * slotDuration
        let end = start + slotDuration
        let slice = events.filter { $0.timestamp >= start && $0.timestamp < end }

        if slice.contains(where: { if case .flowBreak = $0.type { return true }; return false }) {
            return .red
        }
        if slice.contains(where: { if case .filler = $0.type { return true }; return false }) {
            return .orange
        }
        if slice.contains(where: { if case .hesitation = $0.type { return true }; return false }) {
            return .yellow
        }
        if slice.contains(where: { if case .strongMoment = $0.type { return true }; return false }) {
            return .mint
        }

        // No explicit event — check if nearby events exist (speaker was talking cleanly)
        let window = slotDuration * 1.5
        let nearby = events.filter { $0.timestamp >= start - window && $0.timestamp < end + window }
        if !nearby.isEmpty {
            return .mint.opacity(0.5)
        }

        return Color.white.opacity(0.08) // quiet / no data
    }

    /// Time label for the axis (e.g. "0s", "30s", "1m")
    private func timeLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m):\(String(format: "%02d", s))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timeline bars
            GeometryReader { geo in
                let totalGap = CGFloat(max(0, slotCount - 1)) * 2.0
                let barW = max(4, (geo.size.width - totalGap) / CGFloat(slotCount))

                HStack(spacing: 2) {
                    ForEach(0..<slotCount, id: \.self) { i in
                        let color = colorForSlot(i)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color)
                            .frame(width: barW, height: 32)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 32)

            // Time axis
            HStack {
                Text(timeLabel(0))
                Spacer()
                if duration >= 20 {
                    Text(timeLabel(Int(duration / 2)))
                    Spacer()
                }
                Text(timeLabel(Int(duration)))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Color.white.opacity(0.3))

            // Legend
            HStack(spacing: 16) {
                timelineLegend(.mint, "Strong")
                timelineLegend(.orange, "Filler")
                timelineLegend(.yellow, "Pause")
                timelineLegend(.red, "Lost Flow")
            }
        }
    }

    private func timelineLegend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }
}
