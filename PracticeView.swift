// Practise View

import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var coachEngine = SpeechCoachEngine()
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Top Bar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Practice Session")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        MetricBadge(
                            icon: "waveform",
                            text: "\(coachEngine.wpm) WPM",
                            color: wpmColor
                        )
                        MetricBadge(
                            icon: "exclamationmark.bubble",
                            text: "\(coachEngine.fillerWordCount) Fillers",
                            color: .orange
                        )
                        MetricBadge(
                            icon: cameraManager.isMakingEyeContact ? "eye.fill" : "eye.slash.fill",
                            text: cameraManager.isMakingEyeContact ? "Eye ✓" : "Look up",
                            color: cameraManager.isMakingEyeContact ? .green : .red
                        )
                    }
                }
                Spacer()
                Text(timeString(from: session.duration))
                    .font(.system(size: 22, design: .monospaced).bold())
                    .foregroundColor(.mint)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 14)

            // MARK: Audience Attention Meter
            AttentionMeterView(
                score: coachEngine.attentionScore,
                cognitiveLoad: coachEngine.cognitiveLoadWarning
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            // MARK: Live Flow Strip
            LiveFlowStrip(
                events: coachEngine.flowEvents,
                duration: session.duration
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            // Rhythm stability row
            HStack {
                Image(systemName: "metronome.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                Text("Rhythm Stability")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(String(format: "%.0f%%", coachEngine.rhythmStability))
                    .font(.caption.bold())
                    .foregroundColor(coachEngine.rhythmStability > 70 ? .mint : .orange)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)

            // MARK: Live Transcript
            Text(coachEngine.transcribedText.isEmpty
                 ? "Start speaking — I'm listening..."
                 : coachEngine.transcribedText)
                .font(.body)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 32)
                .frame(height: 72)
                .animation(.easeInOut, value: coachEngine.transcribedText)

            Spacer()

            // MARK: Visualizer
            VisualizerView(
                amplitude: coachEngine.amplitude,
                isSpeaking: coachEngine.isSpeaking
            )

            Spacer()

            // MARK: Stop Button
            Button {
                coachEngine.stop()
                cameraManager.stop()
                session.endSession(
                    wpm: coachEngine.wpm,
                    fillers: coachEngine.fillerWordCount,
                    transcript: coachEngine.transcribedText,
                    eyeContactDuration: cameraManager.eyeContactDuration,
                    flowEvents: coachEngine.flowEvents,
                    rhythmStability: coachEngine.rhythmStability,
                    attentionScore: coachEngine.attentionScore
                )
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)
                        .shadow(color: .red.opacity(0.5), radius: 15)
                    Image(systemName: "stop.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            coachEngine.requestPermissionsAndStart()
            cameraManager.start()
        }
        .onDisappear {
            coachEngine.stop()
            cameraManager.stop()
        }
    }

    private var wpmColor: Color {
        switch coachEngine.wpm {
        case 120...160: return .mint
        case 100..<120, 160..<180: return .yellow
        case 0: return .gray
        default: return .orange
        }
    }

    private func timeString(from t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Audience Attention Meter
struct AttentionMeterView: View {
    let score: Double
    let cognitiveLoad: Bool

    private var color: Color {
        switch score {
        case 75...100: return .mint
        case 50..<75:  return .yellow
        case 25..<50:  return .orange
        default:       return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Text("Audience Attention")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if cognitiveLoad {
                    Text("⚠ Lost Flow")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                } else {
                    Text(String(format: "%.0f%%", score))
                        .font(.caption.bold())
                        .foregroundColor(color)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score / 100), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: score)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }
}

// MARK: - Live Flow Strip
struct LiveFlowStrip: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Speech Flow")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 28)

                    ForEach(events.suffix(40)) { event in
                        let x = duration > 1
                            ? geo.size.width * CGFloat(event.timestamp / duration)
                            : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.color)
                            .frame(width: 4, height: 20)
                            .offset(x: min(max(x, 0), geo.size.width - 4))
                    }
                }
            }
            .frame(height: 28)
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }
}

// MARK: - Metric Badge
struct MetricBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text).fontWeight(.medium)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

// MARK: - Visualizer
struct VisualizerView: View {
    let amplitude: CGFloat
    let isSpeaking: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 150 + amplitude * 120, height: 150 + amplitude * 120)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: amplitude)
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.5) : Color.gray.opacity(0.2))
                .frame(width: 120 + amplitude * 80, height: 120 + amplitude * 80)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: amplitude)
            Circle()
                .fill(isSpeaking ? Color.mint : Color.gray.opacity(0.4))
                .frame(width: 100 + amplitude * 40, height: 100 + amplitude * 40)
                .shadow(color: isSpeaking ? .mint.opacity(0.8) : .clear, radius: 20)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.7), value: amplitude)
            Text(isSpeaking ? "Listening..." : "Paused")
                .font(.caption.bold())
                .foregroundColor(isSpeaking ? .black : .white)
        }
    }
}
