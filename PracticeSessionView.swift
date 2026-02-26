//
//  SwiftUIView 2.swift
//  Cadence
//
//  Created by Dhiraj on 26/02/26.
//
import SwiftUI
import Speech
import AVFoundation

struct PracticeSessionView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject var analyzer = SpeechAnalyzer()
    
    @State private var isRecording = false
    @State private var timeElapsed: Int = 0
    
    // Vision tracking variables
    @State private var isLookingAtCamera = false
    @State private var eyeContactTimeElapsed: TimeInterval = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Camera now tracks if the user is looking
            CameraPreviewView(isLooking: $isLookingAtCamera)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Text(isRecording ? "Listening..." : "Practice Session")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text(timeString(from: timeElapsed))
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding()
                
                HStack(spacing: 15) {
                    MetricPill(title: "WPM", value: "\(analyzer.wpm)", icon: "waveform")
                    MetricPill(title: "Pauses", value: "\(analyzer.cognitivePauses)", icon: "pause.circle")
                    // Real-time eye contact feedback
                    MetricPill(title: "Eye Contact", value: isLookingAtCamera ? "Good" : "Lost", icon: isLookingAtCamera ? "eye" : "eye.slash")
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    endSession()
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                                .frame(width: 25, height: 25)
                        )
                }
                .padding(.bottom, 50)
            }
        }
        .onReceive(timer) { _ in
            if isRecording {
                timeElapsed += 1
                // Add to eye contact duration if looking
                if isLookingAtCamera {
                    eyeContactTimeElapsed += 1
                }
            }
        }
        .onAppear {
            requestPermissionsAndStart()
        }
    }
    
    private func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                self.isRecording = true
                                try? self.analyzer.startRecording()
                            } else {
                                print("Microphone permission denied")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func endSession() {
        analyzer.stopRecording()
        isRecording = false
        
        session.duration = TimeInterval(timeElapsed)
        
        // Pass everything cleanly to the SessionManager
        session.endSession(
            wpm: analyzer.wpm,
            fillers: analyzer.cognitivePauses,
            transcript: analyzer.fullTranscript,
            eyeContactDuration: eyeContactTimeElapsed
        )
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// Reusable Glass Pill Component (Keep this at the bottom)
struct MetricPill: View {
    var title: String
    var value: String
    var icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
            VStack(alignment: .leading) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}
