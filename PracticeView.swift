// Practise View

import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var coachEngine = SpeechCoachEngine()
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        VStack {
            // Top Bar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Practice Session")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        MetricBadge(icon: "waveform", text: "\(coachEngine.wpm) WPM", color: .mint)
                        MetricBadge(icon: "exclamationmark.bubble", text: "\(coachEngine.fillerWordCount) Fillers", color: .orange)
                        MetricBadge(icon: cameraManager.isMakingEyeContact ? "eye.fill" : "eye.slash.fill",
                                    text: cameraManager.isMakingEyeContact ? "Good Eye Contact" : "Look at Camera",
                                    color: cameraManager.isMakingEyeContact ? .green : .red)
                    }
                }
                Spacer()
                Text(timeString(from: session.duration))
                    .font(.system(size: 24, design: .monospaced).bold())
                    .foregroundColor(.mint)
                    .padding(.top, 5)
            }
            .padding(30)
            
            Spacer()
            
            // Live Transcript
            Text(coachEngine.transcribedText.isEmpty ? "Listening to your speech..." : coachEngine.transcribedText)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 40)
                .frame(height: 120)
                .animation(.easeInOut, value: coachEngine.transcribedText)
            
            Spacer()
            
            // Audio Visualizer
            VisualizerView(amplitude: coachEngine.amplitude, isSpeaking: coachEngine.isSpeaking)
            
            Spacer()
            
            // Stop Button
            Button(action: {
                coachEngine.stop()
                cameraManager.stop()
                session.endSession(
                    wpm: coachEngine.wpm,
                    fillers: coachEngine.fillerWordCount,
                    transcript: coachEngine.transcribedText,
                    eyeContactDuration: cameraManager.eyeContactDuration
                )
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)
                        .shadow(color: .red.opacity(0.5), radius: 15, x: 0, y: 5)
                    
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
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct MetricBadge: View {
    var icon: String
    var text: String
    var color: Color
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

// MARK: - Visualizer Component
struct VisualizerView: View {
    var amplitude: CGFloat
    var isSpeaking: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 150 + (amplitude * 120), height: 150 + (amplitude * 120))
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: amplitude)
            
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.5) : Color.gray.opacity(0.2))
                .frame(width: 120 + (amplitude * 80), height: 120 + (amplitude * 80))
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: amplitude)
            
            Circle()
                .fill(isSpeaking ? Color.mint : Color.gray.opacity(0.4))
                .frame(width: 100 + (amplitude * 40), height: 100 + (amplitude * 40))
                .shadow(color: isSpeaking ? .mint.opacity(0.8) : .clear, radius: 20, x: 0, y: 0)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.7), value: amplitude)
            
            Text(isSpeaking ? "Listening..." : "Paused")
                .font(.caption.bold())
                .foregroundColor(isSpeaking ? .black : .white)
        }
    }
}
