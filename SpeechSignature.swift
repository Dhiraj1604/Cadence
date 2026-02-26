// SpeechSignature.swift
// Cadence — The Invention
//
// Speech Signature is a generative visual artifact — a unique artwork
// mathematically derived from exactly how you spoke in a session.
//
// Input data → visual properties:
//   WPM          → path curvature / oscillation frequency
//   Fillers      → visible "knots" at exact timestamps
//   Rhythm       → line stroke weight consistency
//   Eye contact  → overall path opacity
//   Strong moments → bioluminescent blooms
//   Flow breaks  → fractures / path discontinuities
//   Hesitations  → gentle dips in the wave

import SwiftUI

// MARK: - Speech Signature Generator

struct SpeechSignatureData {
    let wpm: Int
    let fillerCount: Int
    let rhythmStability: Double     // 0–100
    let eyeContactPercent: Int      // 0–100
    let flowEvents: [FlowEvent]
    let duration: TimeInterval
    let overallScore: Int           // 0–100
}

// MARK: - Main Signature View

struct SpeechSignatureView: View {
    let data: SpeechSignatureData
    @State private var drawProgress: CGFloat = 0
    @State private var appeared = false

    private var signatureColor: Color {
        switch data.overallScore {
        case 80...100: return .mint
        case 60..<80:  return Color(red: 0.4, green: 0.85, blue: 0.7)
        default:       return Color(red: 0.7, green: 0.6, blue: 0.3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(signatureColor)
                        Text("Speech Signature")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("A visual fingerprint of this session — uniquely yours")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(white: 0.40))
                }
                Spacer()
                // Score encoded into the corner
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(data.overallScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(signatureColor)
                    Text("score")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.3))
                }
            }

            // The Signature Canvas
            SignatureCanvas(data: data, drawProgress: drawProgress)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(signatureColor.opacity(0.15), lineWidth: 1)
                )

            // Legend
            HStack(spacing: 0) {
                SignatureLegendItem(color: signatureColor, label: "Flow")
                Spacer()
                SignatureLegendItem(color: .orange, label: "Fillers", dotStyle: .knot)
                Spacer()
                SignatureLegendItem(color: .mint, label: "Strong moments", dotStyle: .bloom)
                Spacer()
                SignatureLegendItem(color: .red, label: "Breaks", dotStyle: .fracture)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(signatureColor.opacity(0.10), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).delay(0.3)) {
                drawProgress = 1.0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speech Signature: a unique visual generated from your session. Score \(data.overallScore). \(data.wpm) words per minute, \(data.fillerCount) fillers, \(data.eyeContactPercent) percent eye contact.")
    }
}

// MARK: - Canvas Renderer

struct SignatureCanvas: View {
    let data: SpeechSignatureData
    let drawProgress: CGFloat

    var body: some View {
        Canvas { ctx, size in
            // Background
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.white.opacity(0.03))
            )

            // Subtle grid lines
            drawGrid(ctx: ctx, size: size)

            // Main signature path
            drawSignaturePath(ctx: ctx, size: size)

            // Event markers
            drawFlowEvents(ctx: ctx, size: size)

            // Baseline
            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: 0, y: size.height * 0.72))
            baselinePath.addLine(to: CGPoint(x: size.width * drawProgress, y: size.height * 0.72))
            ctx.stroke(baselinePath, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)
        }
    }

    // MARK: Grid

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let lineColor = Color.white.opacity(0.04)
        for i in 1...3 {
            var p = Path()
            let y = size.height * CGFloat(i) / 4.0
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(lineColor), lineWidth: 0.5)
        }
    }

    // MARK: Main Path

    private func drawSignaturePath(ctx: GraphicsContext, size: CGSize) {
        guard drawProgress > 0 else { return }

        let w = size.width
        let h = size.height
        let midY = h * 0.55

        // WPM maps to oscillation: 100 WPM = 3 cycles, 160 WPM = 6 cycles, 200+ WPM = 9 cycles
        let normalizedWPM = max(0, min(Double(data.wpm), 220))
        let cycles: Double = data.wpm == 0 ? 2 : (normalizedWPM / 220.0 * 8 + 2)

        // Amplitude: lower for choppy rhythm (wide variance), higher for stable
        let baseAmplitude: CGFloat = h * 0.22 * CGFloat(data.rhythmStability / 100.0 * 0.7 + 0.3)

        // Eye contact → opacity
        let eyeOpacity = 0.5 + Double(data.eyeContactPercent) / 100.0 * 0.5

        // Rhythm stability → line width variance
        let baseLineWidth: CGFloat = 2.0
        let lineWidthVariance: CGFloat = CGFloat((100 - data.rhythmStability) / 100.0) * 1.5

        // Generate the main sine wave path in segments for color
        let totalPoints = max(Int(w * drawProgress), 2)
        let step: CGFloat = w / CGFloat(totalPoints)

        // Color stops based on flow events
        var colorAtX: (CGFloat) -> Color = { x in
            let t = Double(x / w)
            let timeAtX = t * data.duration
            // Find the most recent event before this point
            let eventsBeforeX = data.flowEvents.filter { $0.timestamp <= timeAtX }
            if let last = eventsBeforeX.last {
                switch last.type {
                case .filler:       return .orange
                case .flowBreak:    return .red
                case .hesitation:   return Color(red: 0.7, green: 0.7, blue: 0.3)
                case .strongMoment: return .mint
                }
            }
            return scoreColor()
        }

        // Draw path as connected segments (short strokes for color variation)
        let segmentLength = 12
        var segStart: CGFloat = 0
        while segStart < w * drawProgress {
            let segEnd = min(segStart + CGFloat(segmentLength), w * drawProgress)
            let midX = (segStart + segEnd) / 2

            // Local line width variation based on rhythm
            let rhythmNoise = sin(Double(segStart / w) * 17.3) * Double(lineWidthVariance)
            let localWidth = max(1.0, baseLineWidth + CGFloat(rhythmNoise))

            var segPath = Path()
            var isFirst = true
            var x = segStart
            while x <= segEnd {
                let t = Double(x / w)
                let angle = t * cycles * .pi * 2
                // Add slight irregularity for organic feel
                let noise = sin(t * 23.7 + 1.1) * 0.12 + sin(t * 7.3) * 0.08
                let y = midY - CGFloat(sin(angle) + noise) * baseAmplitude
                let pt = CGPoint(x: x, y: y)
                if isFirst {
                    segPath.move(to: pt)
                    isFirst = false
                } else {
                    segPath.addLine(to: pt)
                }
                x += step
            }

            let segColor = colorAtX(midX).opacity(eyeOpacity)
            ctx.stroke(segPath, with: .color(segColor), style: StrokeStyle(
                lineWidth: localWidth,
                lineCap: .round,
                lineJoin: .round
            ))
            segStart = segEnd
        }
    }

    // MARK: Event Markers

    private func drawFlowEvents(ctx: GraphicsContext, size: CGSize) {
        guard data.duration > 0 else { return }
        let w = size.width
        let h = size.height
        let midY = h * 0.55
        let cycles = data.wpm == 0 ? 2.0 : (Double(min(data.wpm, 220)) / 220.0 * 8 + 2)
        let baseAmplitude: CGFloat = h * 0.22 * CGFloat(data.rhythmStability / 100.0 * 0.7 + 0.3)

        for event in data.flowEvents {
            let t = event.timestamp / data.duration
            guard t <= Double(drawProgress) else { continue }
            let x = CGFloat(t) * w
            let angle = t * cycles * .pi * 2
            let noise = sin(t * 23.7 + 1.1) * 0.12
            let y = midY - CGFloat(sin(angle) + noise) * baseAmplitude

            switch event.type {
            case .filler(let word):
                drawFillerKnot(ctx: ctx, at: CGPoint(x: x, y: y), label: word)

            case .strongMoment:
                drawBloom(ctx: ctx, at: CGPoint(x: x, y: y))

            case .flowBreak:
                drawFracture(ctx: ctx, at: CGPoint(x: x, y: y), size: size)

            case .hesitation:
                drawHesitationDip(ctx: ctx, at: CGPoint(x: x, y: y))
            }
        }
    }

    // Filler: an orange loop/knot
    private func drawFillerKnot(ctx: GraphicsContext, at pt: CGPoint, label: String) {
        let r: CGFloat = 5
        // Outer ring
        ctx.stroke(
            Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r*2, height: r*2)),
            with: .color(Color.orange.opacity(0.9)),
            lineWidth: 1.5
        )
        // Inner dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)),
            with: .color(Color.orange)
        )
    }

    // Strong moment: mint bioluminescent bloom
    private func drawBloom(ctx: GraphicsContext, at pt: CGPoint) {
        // Core dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
            with: .color(Color.mint.opacity(0.95))
        )
        // Expanding rings
        for (r, opacity) in [(CGFloat(9), 0.35), (14, 0.18), (20, 0.08)] as [(CGFloat, Double)] {
            ctx.stroke(
                Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r*2, height: r*2)),
                with: .color(Color.mint.opacity(opacity)),
                lineWidth: 0.8
            )
        }
    }

    // Flow break: a red fracture gap
    private func drawFracture(ctx: GraphicsContext, at pt: CGPoint, size: CGSize) {
        // Red vertical slash
        var slash = Path()
        slash.move(to: CGPoint(x: pt.x - 2, y: pt.y - 10))
        slash.addLine(to: CGPoint(x: pt.x + 2, y: pt.y + 10))
        ctx.stroke(slash, with: .color(Color.red.opacity(0.7)), lineWidth: 1.5)

        // Gap indicator — two small red dots
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 1.5, y: pt.y - 14, width: 3, height: 3)),
            with: .color(Color.red.opacity(0.5))
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 1.5, y: pt.y + 11, width: 3, height: 3)),
            with: .color(Color.red.opacity(0.5))
        )
    }

    // Hesitation: yellow dip indicator
    private func drawHesitationDip(ctx: GraphicsContext, at pt: CGPoint) {
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)),
            with: .color(Color.yellow.opacity(0.75))
        )
    }

    private func scoreColor() -> Color {
        switch data.overallScore {
        case 80...100: return .mint
        case 60..<80:  return Color(red: 0.4, green: 0.85, blue: 0.6)
        default:       return Color(red: 0.7, green: 0.6, blue: 0.3)
        }
    }
}

// MARK: - Legend Item

enum LegendDotStyle { case line, knot, bloom, fracture }

struct SignatureLegendItem: View {
    let color: Color
    let label: String
    var dotStyle: LegendDotStyle = .line

    var body: some View {
        HStack(spacing: 5) {
            legendDot
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.38))
        }
    }

    @ViewBuilder
    private var legendDot: some View {
        switch dotStyle {
        case .line:
            Capsule()
                .fill(color)
                .frame(width: 14, height: 3)
        case .knot:
            ZStack {
                Circle()
                    .stroke(color, lineWidth: 1.2)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(color)
                    .frame(width: 3, height: 3)
            }
        case .bloom:
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 0.8)
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
            }
        case .fracture:
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 10)
        }
    }
}

// MARK: - Compact Signature (for InsightsView history cards)

struct CompactSpeechSignature: View {
    let data: SpeechSignatureData

    private var signatureColor: Color {
        switch data.overallScore {
        case 80...100: return .mint
        case 60..<80:  return Color(red: 0.4, green: 0.85, blue: 0.7)
        default:       return Color(red: 0.7, green: 0.6, blue: 0.3)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            drawCompactSignature(ctx: ctx, size: size)
        }
        .frame(height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Speech signature visual")
    }

    private func drawCompactSignature(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let midY = h * 0.5
        let cycles = data.wpm == 0 ? 2.0 : (Double(min(data.wpm, 220)) / 220.0 * 6 + 1.5)
        let amplitude: CGFloat = h * 0.35 * CGFloat(data.rhythmStability / 100.0 * 0.6 + 0.4)
        let eyeOpacity = 0.4 + Double(data.eyeContactPercent) / 100.0 * 0.6

        // Background
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.03)))

        // Wave
        var path = Path()
        let steps = Int(w / 2)
        for i in 0...steps {
            let x = CGFloat(i) / CGFloat(steps) * w
            let t = Double(i) / Double(steps)
            let angle = t * cycles * .pi * 2
            let noise = sin(t * 19.3) * 0.1
            let y = midY - CGFloat(sin(angle) + noise) * amplitude
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path, with: .color(signatureColor.opacity(eyeOpacity)), lineWidth: 1.5)

        // Event dots
        for event in data.flowEvents.prefix(20) {
            guard data.duration > 0 else { continue }
            let t = event.timestamp / data.duration
            let x = CGFloat(t) * w
            let angle = t * cycles * .pi * 2
            let noise = sin(t * 19.3) * 0.1
            let y = midY - CGFloat(sin(angle) + noise) * amplitude

            let color: Color
            switch event.type {
            case .filler:       color = .orange
            case .strongMoment: color = .mint
            case .flowBreak:    color = .red
            case .hesitation:   color = .yellow
            }
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                with: .color(color.opacity(0.85))
            )
        }
    }
}
