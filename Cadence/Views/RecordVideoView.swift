// RecordVideoView.swift
// Cadence — iOS 26 Native

import SwiftUI
@preconcurrency import AVFoundation

// MARK: - Camera Preview
struct RecordCameraPreview: UIViewRepresentable {
    let viewModel: RecordVideoViewModel

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.clipsToBounds   = true
        if let layer = viewModel.previewLayer {
            view.previewLayer = layer
            view.layer.addSublayer(layer)
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if let layer = viewModel.previewLayer, uiView.previewLayer == nil {
            uiView.previewLayer = layer
            uiView.layer.addSublayer(layer)
            uiView.setNeedsLayout()
        }
    }
}

final class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Video Player View
struct VideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> VideoPlayerUIView {
        let view = VideoPlayerUIView()
        view.backgroundColor = .black
        view.clipsToBounds   = true

        let player = AVPlayer(url: url)
        let layer  = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        view.playerLayer = layer
        view.layer.addSublayer(layer)
        player.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        context.coordinator.player = player
        return view
    }

    func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var player: AVPlayer?
    }
}

final class VideoPlayerUIView: UIView {
    var playerLayer: AVPlayerLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

// MARK: - Main View
struct RecordVideoView: View {
    @StateObject private var viewModel = RecordVideoViewModel()
    @State private var showAnalysis   = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch viewModel.permissionStatus {
                case .unknown, .requesting:
                    VStack(spacing: 16) {
                        ProgressView().tint(Color.cadenceAccent).scaleEffect(1.3)
                        Text("Requesting camera & microphone access…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                case .denied:
                    ContentUnavailableView {
                        Label("Camera Access Required", systemImage: "video.slash.fill")
                    } description: {
                        Text("Cadence needs camera and microphone to record your practice session.\n\nGo to Settings → Privacy → Camera to enable access.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.cadenceAccent)
                    }

                case .granted:
                    if showAnalysis, let result = viewModel.analysisResult {
                        VideoAnalysisView(
                            result: result,
                            videoURL: viewModel.recordedURL,
                            duration: viewModel.recordingDuration
                        ) {
                            showAnalysis = false
                            viewModel.reset()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    } else {
                        CameraRecordingView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Record & Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onChange(of: viewModel.analysisResult) { _, result in
                if let result = result {
                    // Auto-save immediately — no manual prompt
                    session.saveVideoSession(
                        wpm: result.wpm,
                        fillers: result.fillerCount,
                        transcript: result.transcript,
                        eyeContactScore: result.eyeContactScore,
                        duration: viewModel.recordingDuration
                    )
                    withAnimation(.spring()) { showAnalysis = true }
                }
            }
        }
        
        .task {
            await viewModel.requestPermissionsAndSetup()
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.permissionStatus)
        .animation(.easeInOut(duration: 0.3), value: showAnalysis)
    }
}

// MARK: - Camera Recording View
struct CameraRecordingView: View {
    @ObservedObject var viewModel: RecordVideoViewModel

    var body: some View {
        ZStack {
            if viewModel.sessionStarted {
                RecordCameraPreview(viewModel: viewModel)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(Color.cadenceAccent)
                    Text("Starting camera…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            // Top gradient
            LinearGradient(colors: [.black.opacity(0.50), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()

            // Bottom gradient
            LinearGradient(colors: [.clear, .black.opacity(0.80)], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()

            // Tip banner
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.cyan)
                    Text("Look at the camera lens, not the screen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                
                .padding(.top, 8)
                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()

                if viewModel.isAnalyzing {
                    VStack(spacing: 10) {
                        ProgressView().tint(Color.cadenceAccent).scaleEffect(1.2)
                        Text("Analyzing your speech & eye contact…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    .padding(.bottom, 16)
                }

                if viewModel.isRecording {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 7, height: 7)
                            .opacity(viewModel.isRecording ? 1.0 : 0)
                        Text(timeString(viewModel.recordingDuration))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    
                    .padding(.bottom, 12)
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        if viewModel.isRecording { viewModel.stopRecording() }
                        else { viewModel.startRecording() }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white.opacity(0.5), lineWidth: 3)
                            .frame(width: 80, height: 80)
                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.red)
                                .frame(width: 28, height: 28)
                        } else {
                            Circle().fill(.red).frame(width: 64, height: 64)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isRecording ? "Stop recording" : "Start recording")
                .disabled(viewModel.isAnalyzing)

                Text(viewModel.isRecording ? "Tap to stop" : "Tap to start recording")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
                    .padding(.bottom, 48)
            }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Analysis + Playback View
struct VideoAnalysisView: View {
    let result:    VideoAnalysisResult
    let videoURL:  URL?
    let duration:  TimeInterval
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if let url = videoURL {
                    ZStack(alignment: .bottomLeading) {
                        VideoPlayerView(url: url)
                            .frame(height: 300)

                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(result.eyeContactColor)
                                Text("\(result.eyeContactScore)% eye contact")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.black.opacity(0.65), in: Capsule())

                            Spacer()

                            // Auto-saved badge
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.mint)
                                Text("Saved to Insights")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(.black.opacity(0.65), in: Capsule())
                        }
                        .padding(12)
                    }
                }

                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Recording Analysis")
                            .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                        Text(String(format: "%.0f seconds recorded", duration))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        VideoMetricCard(icon: "speedometer", title: "Pacing",
                            value: result.wpm == 0 ? "—" : "\(result.wpm) WPM",
                            badge: result.wpmBadge,
                            color: (result.wpm >= 120 && result.wpm <= 160) ? Color.cadenceAccent : Color.cadenceWarn)
                        VideoMetricCard(icon: "exclamationmark.bubble.fill", title: "Fillers",
                            value: "\(result.fillerCount)", badge: result.fillerBadge,
                            color: result.fillerCount <= 3 ? Color.cadenceAccent : Color.cadenceWarn)
                        VideoMetricCard(icon: "eye.fill", title: "Eye Contact",
                            value: "\(result.eyeContactScore)%", badge: result.eyeContactBadge,
                            color: result.eyeContactColor)
                        VideoMetricCard(icon: "clock.fill", title: "Duration",
                            value: String(format: "%.0fs", duration),
                            badge: "\(result.wordCount) words", color: .cyan)
                    }
                    .padding(.horizontal, 16)

                    EyeContactTipCard(score: result.eyeContactScore).padding(.horizontal, 16)

                    if !result.transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.quote").font(.system(size: 12)).foregroundStyle(.secondary)
                                Text("Transcript").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                            }
                            Text(result.transcript)
                                .font(.system(size: 14)).foregroundStyle(Color(white: 0.70)).lineSpacing(4)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.02))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }

                    Button(action: onDismiss) {
                        Text("Record Again")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(LinearGradient.cadencePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16).padding(.bottom, 48)
                }
            }
        }
        .background(Color.cadenceBG.ignoresSafeArea())
    }
}

// MARK: - Video Metric Card
struct VideoMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let badge: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.38))
            Text(badge)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.14))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.white.opacity(0.02))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value). \(badge)")
    }
}

// MARK: - Eye Contact Tip Card
struct EyeContactTipCard: View {
    let score: Int

    private var tip: (icon: String, color: Color, title: String, message: String) {
        switch score {
        case 80...100:
            return ("eye.fill", Color.cadenceAccent, "Excellent Eye Contact",
                    "You maintained strong eye contact. This builds trust and confidence with your audience.")
        case 60..<80:
            return ("eye", Color.yellow, "Good Eye Contact",
                    "Look toward the camera lens more — treat it as your audience's eyes. Avoid glancing at your own image.")
        case 40..<60:
            return ("eye.slash", Color.cadenceWarn, "Improve Eye Contact",
                    "Try placing a sticky dot next to the camera lens as a target. Aim to look there 70–80% of the time.")
        default:
            return ("eye.slash.fill", Color.red, "Focus on Eye Contact",
                    "Eye contact is critical for credibility. Practice looking directly at the camera lens, not the screen.")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(tip.color.opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: tip.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tip.color)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(tip.message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.55))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(tip.color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tip.color.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Analysis Metric Row
struct AnalysisMetricRow: View {
    let symbol: String
    let label:  String
    let value:  String
    let badge:  String
    let color:  Color

    var body: some View {
        HStack {
            Label(label, systemImage: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(badge).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value). \(badge)")
    }
}
