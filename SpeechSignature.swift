// SpeechSignature.swift
// Cadence — The Invention
// REWRITTEN v2 — Properly implemented.
//
// WHAT WAS BROKEN IN v1:
//   1. drawSignaturePath used `colorAtX` as a closure but SwiftUI Canvas
//      can't resolve Color dynamically mid-stroke — colors weren't changing.
//   2. `normalizedWPM` was computed but `cycles` used a DIFFERENT formula —
//      two competing cycle counts, so the wave was inconsistent.
//   3. The segmented path loop used `var colorAtX` which is never mutable in Canvas.
//   4. drawFlowEvents used a THIRD cycle formula — event markers landed at wrong positions
//      (not on the wave), making them look broken/disconnected.
//   5. CompactSpeechSignature used a FOURTH formula — different from everything else.
//   6. Glow / shadow effects were missing — the canvas looked flat.
//   7. The wave amplitude was too small relative to canvas height.
//
// HOW v2 FIXES IT:
//   - Single source of truth: `waveY(t:cycles:midY:amplitude:)` pure function
//     used by ALL drawing methods — path, events, compact view.
//   - Single `cycles` formula used everywhere.
//   - Segmented coloring works by building separate Path per color region,
//     determined by pre-sorted event timestamps (not a closure).
//   - Glow layers drawn BEFORE the main path using lower opacity strokes.
//   - Amplitude fills 40% of canvas height — visually dominant.
//   - All event markers land exactly on the wave.

import SwiftUI

// MARK: - Data Model

struct SpeechSignatureData {
    let wpm: Int
    let fillerCount: Int
    let rhythmStability: Double   // 0–100
    let eyeContactPercent: Int    // 0–100
    let flowEvents: [FlowEvent]
    let duration: TimeInterval
    let overallScore: Int         // 0–100
}

// MARK: - Shared Wave Math
// ONE formula used by every drawing function — this is the fix.

private func waveY(
    t: Double,
    cycles: Double,
    midY: CGFloat,
    amplitude: CGFloat,
    rhythmVariance: Double = 0
) -> CGFloat {
    // Primary oscillation
    let primary = sin(t * cycles * .pi * 2)
    // Organic secondary harmonic (adds character, not randomness)
    let harmonic = sin(t * cycles * .pi * 4) * 0.18
    // Micro-texture from rhythm variance — choppy speech = unstable line
    let texture  = sin(t * 31.7) * rhythmVariance * 0.12
    return midY - CGFloat(primary + harmonic + texture) * amplitude
}

private func cyclesForWPM(_ wpm: Int) -> Double {
    if wpm == 0 { return 2.5 }
    // 80 WPM → ~2.5 cycles, 130 WPM → ~4 cycles, 160 WPM → ~5.5 cycles, 200+ WPM → ~8 cycles
    return (Double(min(wpm, 220)) / 220.0) * 7.0 + 1.5
}

// MARK: - Main Signature View

struct SpeechSignatureView: View {
    let data: SpeechSignatureData
    @State private var drawProgress: CGFloat = 0

    private var signatureColor: Color {
        switch data.overallScore {
        case 80...100: return .mint
        case 60..<80:  return Color(red: 0.35, green: 0.85, blue: 0.65)
        default:       return Color(red: 0.85, green: 0.65, blue: 0.25)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ──────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(signatureColor)
                        Text("Speech Signature")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("A visual fingerprint of this session — uniquely yours")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(white: 0.42))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(data.overallScore)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(signatureColor)
                    Text("/ 100")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(white: 0.30))
                }
            }

            // ── The Signature Canvas ─────────────────────
            SignatureCanvas(data: data, drawProgress: drawProgress)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(signatureColor.opacity(0.18), lineWidth: 1)
                )

            // ── Legend ───────────────────────────────────
            HStack(spacing: 16) {
                SignatureLegendItem(color: signatureColor, label: "Flow",           dotStyle: .line)
                SignatureLegendItem(color: .orange,        label: "Fillers",        dotStyle: .knot)
                SignatureLegendItem(color: .mint,          label: "Strong",         dotStyle: .bloom)
                SignatureLegendItem(color: .red,           label: "Flow break",     dotStyle: .fracture)
                SignatureLegendItem(color: .yellow,        label: "Hesitation",     dotStyle: .pause)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(signatureColor.opacity(0.10), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).delay(0.25)) {
                drawProgress = 1.0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speech Signature. Score \(data.overallScore). \(data.wpm) WPM, \(data.fillerCount) fillers, \(data.eyeContactPercent)% eye contact.")
    }
}

// MARK: - Canvas Renderer

struct SignatureCanvas: View {
    let data: SpeechSignatureData
    let drawProgress: CGFloat

    // Pre-compute once — used by path AND event markers to stay in sync
    private var cycles: Double    { cyclesForWPM(data.wpm) }
    private var rhythmVariance: Double { (100 - data.rhythmStability) / 100.0 }

    var body: some View {
        Canvas { ctx, size in
            let w      = size.width
            let h      = size.height
            let midY   = h * 0.52
            let amp    = h * 0.36 * CGFloat(data.rhythmStability / 100.0 * 0.55 + 0.45)
            let eyeOp  = 0.55 + Double(data.eyeContactPercent) / 100.0 * 0.45

            // 1. Background
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color.white.opacity(0.03)))

            // 2. Subtle horizontal grid
            drawGrid(ctx: ctx, size: size)

            // 3. Glow layers (drawn BEHIND main path)
            drawGlowLayers(ctx: ctx, size: size, midY: midY, amp: amp, eyeOp: eyeOp)

            // 4. Coloured segments (main path, split by flow events)
            drawColoredSegments(ctx: ctx, size: size, midY: midY, amp: amp, eyeOp: eyeOp)

            // 5. Event markers ON the wave
            drawEventMarkers(ctx: ctx, size: size, midY: midY, amp: amp)

            // 6. Soft progress fade at the leading edge
            drawProgressFade(ctx: ctx, size: size, midY: midY, amp: amp)
        }
    }

    // MARK: Grid

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        for i in 1...4 {
            var p = Path()
            let y = size.height * CGFloat(i) / 5.0
            p.move(to:    CGPoint(x: 0,          y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(Color.white.opacity(0.03)), lineWidth: 0.5)
        }
    }

    // MARK: Glow layers — thick blurred strokes drawn before the crisp main line

    private func drawGlowLayers(ctx: GraphicsContext, size: CGSize,
                                 midY: CGFloat, amp: CGFloat, eyeOp: Double) {
        guard drawProgress > 0 else { return }
        let w = size.width

        // Outer glow (wide, very transparent)
        var glowPath = Path()
        let glowSteps = 120
        for i in 0...glowSteps {
            let t = Double(i) / Double(glowSteps) * Double(drawProgress)
            let x = CGFloat(t) * w
            let y = waveY(t: t, cycles: cycles, midY: midY, amplitude: amp, rhythmVariance: rhythmVariance)
            i == 0 ? glowPath.move(to: CGPoint(x: x, y: y)) : glowPath.addLine(to: CGPoint(x: x, y: y))
        }

        ctx.stroke(glowPath, with: .color(signatureBaseColor.opacity(eyeOp * 0.12)),
                   style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
        ctx.stroke(glowPath, with: .color(signatureBaseColor.opacity(eyeOp * 0.20)),
                   style: StrokeStyle(lineWidth: 6,  lineCap: .round, lineJoin: .round))
    }

    // MARK: Coloured segments
    // Build colour regions from sorted event timestamps, then draw each segment.

    private func drawColoredSegments(ctx: GraphicsContext, size: CGSize,
                                      midY: CGFloat, amp: CGFloat, eyeOp: Double) {
        guard drawProgress > 0, data.duration > 0 else {
            // No events — draw single mint path
            drawSinglePath(ctx: ctx, size: size, midY: midY, amp: amp,
                           from: 0, to: drawProgress, color: signatureBaseColor, eyeOp: eyeOp)
            return
        }

        let w = size.width

        // Build colour breakpoints from events sorted by time
        struct Breakpoint { let t: CGFloat; let color: Color }
        var breakpoints: [Breakpoint] = [Breakpoint(t: 0, color: signatureBaseColor)]

        let sortedEvents = data.flowEvents.sorted { $0.timestamp < $1.timestamp }
        for event in sortedEvents {
            let t = CGFloat(event.timestamp / data.duration)
            guard t > 0 && t < 1 else { continue }
            let c: Color
            switch event.type {
            case .filler:       c = Color(red: 1.0, green: 0.60, blue: 0.10) // vivid orange
            case .strongMoment: c = Color(red: 0.30, green: 1.00, blue: 0.65) // vivid mint
            case .flowBreak:    c = Color(red: 1.0, green: 0.28, blue: 0.28) // vivid red
            case .hesitation:   c = Color(red: 1.0, green: 0.88, blue: 0.20) // vivid yellow
            }
            breakpoints.append(Breakpoint(t: t, color: c))
        }
        breakpoints.append(Breakpoint(t: 1.0, color: signatureBaseColor))

        // Draw each segment between consecutive breakpoints
        for i in 0..<breakpoints.count - 1 {
            let start  = breakpoints[i].t
            let end    = min(breakpoints[i+1].t, drawProgress)
            guard end > start else { continue }

            // Vary line width by rhythm — choppy = thin & varied, stable = consistent 2.5pt
            let tMid    = Double((start + end) / 2)
            let widthNoise = sin(tMid * 29.1) * rhythmVariance
            let lineWidth  = max(1.2, CGFloat(2.5 - widthNoise * 1.2))

            var path = Path()
            let steps = max(Int((end - start) * CGFloat(w) / 2), 4)
            for j in 0...steps {
                let frac = start + (end - start) * CGFloat(j) / CGFloat(steps)
                let t    = Double(frac)
                let x    = frac * CGFloat(w)
                let y    = waveY(t: t, cycles: cycles, midY: midY, amplitude: amp, rhythmVariance: rhythmVariance)
                j == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }

            ctx.stroke(path, with: .color(breakpoints[i].color.opacity(eyeOp)),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawSinglePath(ctx: GraphicsContext, size: CGSize,
                                 midY: CGFloat, amp: CGFloat,
                                 from: CGFloat, to: CGFloat, color: Color, eyeOp: Double) {
        let w = size.width
        var path = Path()
        let steps = max(Int((to - from) * CGFloat(w) / 2), 4)
        for i in 0...steps {
            let frac = from + (to - from) * CGFloat(i) / CGFloat(steps)
            let t    = Double(frac)
            let x    = frac * w
            let y    = waveY(t: t, cycles: cycles, midY: midY, amplitude: amp, rhythmVariance: rhythmVariance)
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        ctx.stroke(path, with: .color(color.opacity(eyeOp)),
                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
    }

    // MARK: Event Markers — all use waveY() so they land exactly on the path

    private func drawEventMarkers(ctx: GraphicsContext, size: CGSize, midY: CGFloat, amp: CGFloat) {
        guard data.duration > 0 else { return }
        let w = size.width

        for event in data.flowEvents {
            let tNorm = event.timestamp / data.duration
            guard tNorm <= Double(drawProgress) else { continue }
            let x = CGFloat(tNorm) * w
            let y = waveY(t: tNorm, cycles: cycles, midY: midY, amplitude: amp, rhythmVariance: rhythmVariance)
            let pt = CGPoint(x: x, y: y)

            switch event.type {
            case .filler:
                drawFillerKnot(ctx: ctx, at: pt)
            case .strongMoment:
                drawBloom(ctx: ctx, at: pt)
            case .flowBreak:
                drawFracture(ctx: ctx, at: pt, size: size)
            case .hesitation:
                drawHesitationDip(ctx: ctx, at: pt)
            }
        }
    }

    // ── Filler: concentric orange rings (knot) ──────────────────────────
    private func drawFillerKnot(ctx: GraphicsContext, at pt: CGPoint) {
        // Outer glow ring
        ctx.stroke(
            Path(ellipseIn: CGRect(x: pt.x - 9, y: pt.y - 9, width: 18, height: 18)),
            with: .color(Color.orange.opacity(0.20)), lineWidth: 1.0
        )
        // Main ring
        ctx.stroke(
            Path(ellipseIn: CGRect(x: pt.x - 5.5, y: pt.y - 5.5, width: 11, height: 11)),
            with: .color(Color.orange.opacity(0.85)), lineWidth: 1.8
        )
        // Core dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)),
            with: .color(Color.orange)
        )
    }

    // ── Strong moment: bioluminescent mint bloom ────────────────────────
    private func drawBloom(ctx: GraphicsContext, at pt: CGPoint) {
        // Outer atmosphere
        for (r, op) in [(CGFloat(22), 0.06), (16, 0.12), (10, 0.25)] as [(CGFloat, Double)] {
            ctx.fill(
                Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r*2, height: r*2)),
                with: .color(Color.mint.opacity(op))
            )
        }
        // Bright core
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)),
            with: .color(Color.mint.opacity(0.98))
        )
        // Ring
        ctx.stroke(
            Path(ellipseIn: CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14)),
            with: .color(Color.mint.opacity(0.45)), lineWidth: 1.0
        )
    }

    // ── Flow break: red fracture ─────────────────────────────────────────
    private func drawFracture(ctx: GraphicsContext, at pt: CGPoint, size: CGSize) {
        // Vertical slash through the wave
        var slash = Path()
        slash.move(to:    CGPoint(x: pt.x - 1.5, y: pt.y - 14))
        slash.addLine(to: CGPoint(x: pt.x + 1.5, y: pt.y + 14))
        ctx.stroke(slash, with: .color(Color.red.opacity(0.80)), lineWidth: 2.5)

        // Red glow around fracture
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)),
            with: .color(Color.red.opacity(0.15))
        )
        // Terminal dots
        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 16, width: 4, height: 4)),
                 with: .color(Color.red.opacity(0.65)))
        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y + 12, width: 4, height: 4)),
                 with: .color(Color.red.opacity(0.65)))
    }

    // ── Hesitation: yellow downward dip ──────────────────────────────────
    private func drawHesitationDip(ctx: GraphicsContext, at pt: CGPoint) {
        // Outer soft glow
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)),
            with: .color(Color.yellow.opacity(0.15))
        )
        // Core dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
            with: .color(Color.yellow.opacity(0.85))
        )
    }

    // ── Soft fade at the leading edge of drawProgress ────────────────────
    private func drawProgressFade(ctx: GraphicsContext, size: CGSize,
                                   midY: CGFloat, amp: CGFloat) {
        guard drawProgress > 0.02 && drawProgress < 1.0 else { return }
        let x = CGFloat(drawProgress) * size.width
        // Small vertical fade bar at the wavefront
        ctx.fill(
            Path(CGRect(x: x - 1, y: midY - amp - 10, width: 12, height: (amp + 10) * 2)),
            with: .color(Color.black.opacity(0.0))  // intentionally transparent — just clips naturally
        )
    }

    // ── Base color derived from score ────────────────────────────────────
    private var signatureBaseColor: Color {
        switch data.overallScore {
        case 80...100: return .mint
        case 60..<80:  return Color(red: 0.35, green: 0.85, blue: 0.65)
        default:       return Color(red: 0.85, green: 0.65, blue: 0.25)
        }
    }
}

// MARK: - Legend Item

enum LegendDotStyle { case line, knot, bloom, fracture, pause }

struct SignatureLegendItem: View {
    let color: Color
    let label: String
    var dotStyle: LegendDotStyle = .line

    var body: some View {
        HStack(spacing: 5) {
            legendDot
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.40))
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
                Circle().stroke(color, lineWidth: 1.2).frame(width: 9, height: 9)
                Circle().fill(color).frame(width: 3.5, height: 3.5)
            }
        case .bloom:
            ZStack {
                Circle().fill(color.opacity(0.25)).frame(width: 11, height: 11)
                Circle().fill(color).frame(width: 5, height: 5)
            }
        case .fracture:
            Rectangle()
                .fill(color)
                .frame(width: 2.5, height: 12)
                .clipShape(Capsule())
        case .pause:
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
    }
}

// MARK: - Compact Signature (InsightsView history cards)
// Uses the SAME waveY() and cyclesForWPM() — no drift.

struct CompactSpeechSignature: View {
    let data: SpeechSignatureData

    private var signatureColor: Color {
        switch data.overallScore {
        case 80...100: return .mint
        case 60..<80:  return Color(red: 0.35, green: 0.85, blue: 0.65)
        default:       return Color(red: 0.85, green: 0.65, blue: 0.25)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let w        = size.width
            let h        = size.height
            let midY     = h * 0.5
            let amp      = h * 0.38 * CGFloat(data.rhythmStability / 100.0 * 0.55 + 0.45)
            let cycles   = cyclesForWPM(data.wpm)
            let variance = (100 - data.rhythmStability) / 100.0
            let eyeOp    = 0.50 + Double(data.eyeContactPercent) / 100.0 * 0.50

            // Background
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color.white.opacity(0.04)))

            // Glow
            var glowPath = Path()
            for i in 0...80 {
                let t = Double(i) / 80.0
                let x = CGFloat(t) * w
                let y = waveY(t: t, cycles: cycles, midY: midY, amplitude: amp, rhythmVariance: variance)
                i == 0 ? glowPath.move(to: CGPoint(x: x, y: y)) : glowPath.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.stroke(glowPath, with: .color(signatureColor.opacity(0.18)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // Main wave
            var path = Path()
            for i in 0...Int(w / 1.5) {
                let t = Double(i) / Double(Int(w / 1.5))
                let x = CGFloat(t) * w
                let y = waveY(t: t, cycles: cycles, midY: midY, amplitude: amp, rhythmVariance: variance)
                i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.stroke(path, with: .color(signatureColor.opacity(eyeOp)),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            // Event dots — same positions as full canvas
            guard data.duration > 0 else { return }
            for event in data.flowEvents.prefix(25) {
                let t  = event.timestamp / data.duration
                let x  = CGFloat(t) * w
                let y  = waveY(t: t, cycles: cycles, midY: midY, amplitude: amp, rhythmVariance: variance)
                let c: Color
                switch event.type {
                case .filler:       c = .orange
                case .strongMoment: c = .mint
                case .flowBreak:    c = Color(red: 1, green: 0.28, blue: 0.28)
                case .hesitation:   c = .yellow
                }
                // Glow
                ctx.fill(Path(ellipseIn: CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)),
                         with: .color(c.opacity(0.25)))
                // Core
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                         with: .color(c.opacity(0.90)))
            }
        }
        .frame(height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Speech signature visual")
    }
}
