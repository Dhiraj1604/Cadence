// OnboardingView.swift
// Cadence — one-time intro screen
// Shows on first install only. Never again.
// Design: almost nothing. Orb. Name. One line. Signature strip. Begin.

import SwiftUI

struct OnboardingView: View {
    let onBegin: () -> Void

    @State private var orbRotation: Double = 0
    @State private var pulse = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.12, blue: 0.10), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft glow
            RadialGradient(
                colors: [Color.mint.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.22),
                startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(spacing: 0) {

                Spacer()

                // ── Orb ───────────────────────────────────
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.mint.opacity(0.07 - Double(i) * 0.018), lineWidth: 1)
                            .frame(width: CGFloat(86 + i * 30))
                            .scaleEffect(pulse ? 1.0 : 0.85)
                            .animation(
                                .easeInOut(duration: 2.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.5),
                                value: pulse
                            )
                    }
                    Circle()
                        .trim(from: 0, to: 0.22)
                        .stroke(
                            AngularGradient(
                                colors: [Color.mint.opacity(0.9), .clear],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .frame(width: 84)
                        .rotationEffect(.degrees(orbRotation))
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.mint.opacity(0.18), .clear],
                            center: .center, startRadius: 0, endRadius: 38
                        ))
                        .frame(width: 72)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .mint],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                .frame(height: 110)
                .accessibilityHidden(true)

                Spacer().frame(height: 28)

                // ── Name + tagline ─────────────────────────
                VStack(spacing: 8) {
                    Text("Cadence")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.white)

                    Text("See the shape of your voice.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color(white: 0.48))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                Spacer().frame(height: 48)

                // ── Speech Signature strip ─────────────────
                // The invention — shown visually, minimal words
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.mint)
                        Text("Speech Signature")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.mint)
                            .tracking(0.5)
                        Spacer()
                        Text("your voice, made visible")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(white: 0.38))
                    }

                    // Signature canvas — the visual proof of the concept
                    SignaturePreviewCanvas()
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)
                .accessibilityLabel("Speech Signature: a unique visual generated from how you speak")

                Spacer()

                // ── Begin ──────────────────────────────────
                Button(action: onBegin) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            LinearGradient(
                                colors: [.mint, Color(red: 0.18, green: 0.90, blue: 0.76)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.mint.opacity(0.40), radius: 20, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .sensoryFeedback(.impact(weight: .medium), trigger: appeared)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
                .accessibilityLabel("Get started with Cadence")

                Spacer().frame(height: 56)
            }
        }
        .onAppear {
            appeared = true
            pulse    = true
            withAnimation(.linear(duration: 11).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
        }
    }
}

// MARK: - Signature Preview Canvas
// Minimal static canvas — just enough to show the concept
struct SignaturePreviewCanvas: View {
    private let segments: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
        (0.00, 0.50, 0.10, 0.38, .mint),
        (0.10, 0.38, 0.20, 0.28, .mint),
        (0.20, 0.28, 0.28, 0.42, .mint),
        (0.28, 0.42, 0.36, 0.64, .orange),
        (0.36, 0.64, 0.44, 0.52, .orange),
        (0.44, 0.52, 0.52, 0.30, .mint),
        (0.52, 0.30, 0.60, 0.22, .mint),
        (0.60, 0.22, 0.68, 0.38, .mint),
        (0.68, 0.38, 0.76, 0.54, .yellow),
        (0.76, 0.54, 0.84, 0.40, .cyan),
        (0.84, 0.40, 0.92, 0.30, .cyan),
        (0.92, 0.30, 1.00, 0.50, .mint),
    ]

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Dark bg
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.white.opacity(0.05))
            )

            // Segments
            for (x0, y0, x1, y1, color) in segments {
                var path = Path()
                let p0 = CGPoint(x: x0 * w, y: y0 * h)
                let p1 = CGPoint(x: x1 * w, y: y1 * h)
                path.move(to: p0)
                path.addCurve(
                    to: p1,
                    control1: CGPoint(x: (x0 * 0.5 + x1 * 0.5) * w, y: p0.y),
                    control2: CGPoint(x: (x0 * 0.5 + x1 * 0.5) * w, y: p1.y)
                )
                ctx.stroke(path, with: .color(color.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            }

            // Filler knot dots
            for fx: CGFloat in [0.32, 0.38] {
                let pt = CGPoint(x: fx * w, y: 0.58 * h)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pt.x-3.5, y: pt.y-3.5, width: 7, height: 7)),
                    with: .color(Color.orange.opacity(0.9))
                )
            }

            // Strong moment bloom
            let bx = 0.56 * w, by = 0.26 * h
            ctx.fill(
                Path(ellipseIn: CGRect(x: bx-3, y: by-3, width: 6, height: 6)),
                with: .color(Color.mint.opacity(0.95))
            )
            for r: CGFloat in [7, 12] {
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: bx-r, y: by-r, width: r*2, height: r*2)),
                    with: .color(Color.mint.opacity(0.12)),
                    lineWidth: 0.8
                )
            }
        }
    }
}

#Preview {
    OnboardingView { }
}
