import SwiftUI

// Screen width available globally — no GeometryReader needed
private let SW = UIScreen.main.bounds.width
private let CW = SW - 48  // 24pt margins each side

struct IdleView: View {
    @EnvironmentObject var session: SessionManager
    @State private var pulse = false
    @State private var orbRotation: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var dnaOpacity: Double = 0
    @State private var pillsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var dnaHeights: [CGFloat] = [18,28,22,34,16,30,24,20,32,18,26,34,20,28,16,30,22,18,34,26,20,28,32,16]

    private let dnaColors: [Color] = [
        .mint,.orange,.mint,.mint,.yellow,.mint,
        .red,.mint,.mint,.orange,.mint,.mint,
        .mint,.yellow,.mint,.orange,.mint,.mint,
        .mint,.mint,.yellow,.mint,.orange,.mint
    ]

    // Pre-compute bar width once
    private var barW: CGFloat {
        let count = CGFloat(dnaColors.count)
        let spacing = (count - 1) * 4
        let innerPadding: CGFloat = 20
        return (CW - spacing - innerPadding) / count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.05), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.mint.opacity(0.07))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .offset(y: -180)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // ── ORB ──────────────────────────────
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.mint.opacity(0.07 - Double(i) * 0.02), lineWidth: 1)
                            .frame(width: CGFloat(160 + i * 50), height: CGFloat(160 + i * 50))
                            .scaleEffect(pulse ? 1.0 : 0.88)
                            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(Double(i) * 0.35), value: pulse)
                    }
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(
                            AngularGradient(colors: [Color.mint.opacity(0.7), .clear], center: .center),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .frame(width: 148, height: 148)
                        .rotationEffect(.degrees(orbRotation))
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.mint.opacity(0.22), Color.mint.opacity(0.05)],
                            center: .center, startRadius: 0, endRadius: 68
                        ))
                        .frame(width: 136, height: 136)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(LinearGradient(colors: [.white, .mint], startPoint: .top, endPoint: .bottom))
                }

                Spacer().frame(height: 44)

                // ── TITLE ─────────────────────────────
                VStack(spacing: 8) {
                    Text("Cadence")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.82)], startPoint: .top, endPoint: .bottom))
                    Text("See the shape of your speech")
                        .font(.system(size: 15))
                        .foregroundColor(Color(white: 0.45))
                }
                .opacity(titleOpacity)

                Spacer().frame(height: 36)

                // ── DNA STRIP ─────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 10)).foregroundColor(.mint)
                        Text("SPEECH FLOW DNA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(white: 0.42))
                            .tracking(2.2)
                    }

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mint.opacity(0.12), lineWidth: 1))

                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(0..<dnaColors.count, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(dnaColors[i])
                                    .frame(width: barW, height: dnaHeights[i])
                                    .animation(.easeInOut(duration: 1.4 + Double(i) * 0.12).repeatForever(autoreverses: true), value: dnaHeights[i])
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                    .frame(width: CW, height: 68)
                    .opacity(dnaOpacity)

                    HStack(spacing: 14) {
                        MiniLegend(color: .mint,   label: "Confident")
                        MiniLegend(color: .orange, label: "Filler")
                        MiniLegend(color: .yellow, label: "Pause")
                        MiniLegend(color: .red,    label: "Lost Flow")
                    }
                    .opacity(dnaOpacity)
                }
                .frame(width: CW, alignment: .leading)

                Spacer().frame(height: 24)

                // ── FEATURE ROWS ──────────────────────
                VStack(spacing: 9) {
                    FeatureRow(icon: "person.3.fill", text: "Live audience attention score", color: .purple)
                    FeatureRow(icon: "eye.fill",      text: "Real-time eye contact tracking", color: .cyan)
                    FeatureRow(icon: "bolt.fill",     text: "Instant personalised coaching",  color: .yellow)
                }
                .frame(width: CW)
                .opacity(pillsOpacity)

                Spacer()

                // ── CTA ───────────────────────────────
                Button { session.startSession() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold))
                        Text("Begin Practice").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(width: CW, height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.mint, Color(red: 0.2, green: 0.85, blue: 0.68)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .mint.opacity(0.35), radius: 24, y: 8)
                }
                .opacity(buttonOpacity)

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
            // Animate bars — staggered so each moves independently
            for i in 0..<dnaHeights.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 1.3 + Double(i) * 0.13).repeatForever(autoreverses: true)) {
                        dnaHeights[i] = CGFloat.random(in: 12...38)
                    }
                }
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.2))  { titleOpacity  = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(0.55)) { dnaOpacity    = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(0.85)) { pillsOpacity  = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(1.05)) { buttonOpacity = 1 }
        }
    }
}

struct MiniLegend: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(Color(white: 0.42))
        }
    }
}

struct FeatureRow: View {
    let icon: String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.14)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(color)
            }
            Text(text).font(.system(size: 14)).foregroundColor(Color(white: 0.62))
            Spacer()
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(color.opacity(0.6))
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct FeaturePill: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(.mint).frame(width: 20)
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.white.opacity(0.06)).cornerRadius(12)
    }
}
