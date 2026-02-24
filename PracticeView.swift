import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var audio = AudioManager()
    
    var body: some View {
        VStack {
            // Top Bar
            HStack {
                Text("Practice Session")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Live Timer
                Text(timeString(from: session.duration))
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundColor(.mint)
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)
            
            Spacer()
            
            // The Breathing Visualizer
            VisualizerView(amplitude: audio.amplitude, isSpeaking: audio.isSpeaking)
            
            Spacer()
            
            // Stop Button
            Button(action: {
                session.endSession()
            }) {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            audio.start()
        }
        .onDisappear {
            audio.stop()
        }
    }
    
    // Helper to format the timer
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Visualizer Component
// Placed in the same file to guarantee Xcode sees it
struct VisualizerView: View {
    var amplitude: CGFloat
    var isSpeaking: Bool
    
    var body: some View {
        ZStack {
            // Background pulsing ring
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 150 + (amplitude * 120), height: 150 + (amplitude * 120))
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: amplitude)
            
            // Middle ring
            Circle()
                .fill(isSpeaking ? Color.mint.opacity(0.5) : Color.gray.opacity(0.2))
                .frame(width: 120 + (amplitude * 80), height: 120 + (amplitude * 80))
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: amplitude)
            
            // Inner Core
            Circle()
                .fill(isSpeaking ? Color.mint : Color.gray.opacity(0.4))
                .frame(width: 100 + (amplitude * 40), height: 100 + (amplitude * 40))
                .shadow(color: isSpeaking ? .mint.opacity(0.8) : .clear, radius: 20, x: 0, y: 0)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.7), value: amplitude)
            
            // Status Text
            Text(isSpeaking ? "Listening..." : "Paused")
                .font(.caption.bold())
                .foregroundColor(isSpeaking ? .black : .white)
        }
    }
}
