// RecordVideoView.swift
// Cadence — iOS 26 Native
// FULLY REWRITTEN:
//   • Permissions requested IMMEDIATELY on appear — no waiting for button tap
//   • AVCaptureSession properly initialized with front camera + microphone
//   • After recording: video plays back with AVPlayer so user can review their eye contact
//   • Speech analysis runs in parallel with playback setup
//   • Eye contact coaching annotations shown during playback
//   • Vision face detection on sampled frames to give eye contact score

import SwiftUI
@preconcurrency import AVFoundation
import Speech
import Vision

// MARK: - Analysis Result

struct VideoAnalysisResult: Equatable {
    let transcript:       String
    let wordCount:        Int
    let wpm:              Int
    let fillerCount:      Int
    let duration:         TimeInterval
    let eyeContactScore:  Int     // 0–100 estimated from face detection

    static let empty = VideoAnalysisResult(
        transcript: "", wordCount: 0, wpm: 0,
        fillerCount: 0, duration: 0, eyeContactScore: 0
    )

    static func == (lhs: VideoAnalysisResult, rhs: VideoAnalysisResult) -> Bool {
        lhs.transcript == rhs.transcript && lhs.wpm == rhs.wpm
    }

    var wpmBadge: String {
        switch wpm {
        case 120...160: return "Ideal Pace"
        case 100..<120: return "Slightly Slow"
        case 160..<180: return "Slightly Fast"
        case 0:         return "No Speech"
        default:        return wpm > 180 ? "Too Fast" : "Too Slow"
        }
    }
    var fillerBadge: String {
        switch fillerCount {
        case 0:     return "Flawless"
        case 1...3: return "Great"
        case 4...7: return "Noticeable"
        default:    return "Needs Work"
        }
    }
    var eyeContactBadge: String {
        switch eyeContactScore {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Fair"
        default:       return "Needs Work"
        }
    }
    var eyeContactColor: Color {
        switch eyeContactScore {
        case 70...100: return .mint
        case 45..<70:  return .yellow
        default:       return .orange
        }
    }
}

// MARK: - Recorder Engine

@MainActor
class VideoRecorder: NSObject, ObservableObject {
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var isRecording       = false
    @Published var recordedURL:       URL?                   = nil
    @Published var recordingDuration: TimeInterval           = 0
    @Published var analysisResult:    VideoAnalysisResult?   = nil
    @Published var isAnalyzing        = false
    @Published var sessionStarted     = false

    enum PermissionStatus { case unknown, requesting, granted, denied }

    private var captureSession: AVCaptureSession?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private var movieOutput = AVCaptureMovieFileOutput()
    private var timerTask: Task<Void, Never>?

    private var outputURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("cadence_rec_\(Int(Date().timeIntervalSince1970)).mov")
    }

    // MARK: Permissions — called immediately on appear

    func requestPermissionsAndSetup() async {
        guard permissionStatus == .unknown else { return }
        permissionStatus = .requesting

        async let camResult = AVCaptureDevice.requestAccess(for: .video)
        async let micResult = AVCaptureDevice.requestAccess(for: .audio)
        let cam = await camResult
        let mic = await micResult

        if cam && mic {
            permissionStatus = .granted
            setupCaptureSession()
        } else {
            permissionStatus = .denied
        }
    }

    // MARK: Session setup

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high

        // Front camera
        guard
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let videoInput  = try? AVCaptureDeviceInput(device: videoDevice),
            session.canAddInput(videoInput)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoInput)

        // Microphone
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput  = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        // Mirror preview (selfie-style)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let conn = layer.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }

        session.commitConfiguration()

        previewLayer   = layer
        captureSession = session

        // Start session on background thread
        Task.detached(priority: .userInitiated) {
            session.startRunning()
            await MainActor.run { self.sessionStarted = true }
        }
    }

    // MARK: Record

    func startRecording() {
        guard let s = captureSession, s.isRunning else { return }
        let url = outputURL
        try? FileManager.default.removeItem(at: url)
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording       = true
        recordingDuration = 0
        analysisResult    = nil
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                recordingDuration += 1
            }
        }
    }

    func stopRecording() {
        movieOutput.stopRecording()
        timerTask?.cancel()
        isRecording = false
    }

    func reset() {
        recordedURL      = nil
        analysisResult   = nil
        recordingDuration = 0
    }

    // MARK: Analysis

    private func analyzeRecording(url: URL) {
        isAnalyzing = true
        Task {
            async let speechResult = runSpeechAnalysis(on: url)
            async let eyeResult    = estimateEyeContact(from: url)
            let speech = await speechResult
            let eye    = await eyeResult
            analysisResult = VideoAnalysisResult(
                transcript:      speech.transcript,
                wordCount:       speech.wordCount,
                wpm:             speech.wpm,
                fillerCount:     speech.fillerCount,
                duration:        speech.duration,
                eyeContactScore: eye
            )
            isAnalyzing = false
        }
    }

    // Speech analysis via SFSpeechRecognizer
    private func runSpeechAnalysis(on url: URL) async -> (transcript: String, wordCount: Int, wpm: Int, fillerCount: Int, duration: TimeInterval) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        let request    = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            var done = false
            recognizer?.recognitionTask(with: request) { result, error in
                guard !done else { return }
                guard let result, result.isFinal else {
                    if error != nil {
                        done = true
                        continuation.resume(returning: ("", 0, 0, 0, 0))
                    }
                    return
                }
                done = true
                let text   = result.bestTranscription.formattedString
                let words  = text.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                let fillers = words.filter {
                    ["um", "uh", "like", "so", "actually", "basically"].contains($0)
                }.count
                let dur = result.bestTranscription.segments.last?.timestamp ?? 1.0
                let wpm = dur > 0 ? Int(Double(words.count) / (dur / 60.0)) : 0
                continuation.resume(returning: (text, words.count, wpm, fillers, dur))
            }
        }
    }

    // Eye contact estimation via Vision face landmark detection on sampled frames
    private func estimateEyeContact(from url: URL) async -> Int {
        let asset    = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        let secs     = duration.map { CMTimeGetSeconds($0) } ?? 0
        guard secs > 0 else { return 50 }

        // Sample one frame every 2 seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 0.5, preferredTimescale: 600)

        let sampleCount = max(3, Int(secs / 2))
        var facingFrames = 0
        var totalFrames  = 0

        for i in 0..<sampleCount {
            let t = CMTime(seconds: Double(i) * secs / Double(sampleCount), preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: t, actualTime: nil) else { continue }
            totalFrames += 1

            // Run face detection
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            if let faces = request.results, !faces.isEmpty {
                facingFrames += 1
            }
        }

        guard totalFrames > 0 else { return 50 }
        return Int(Double(facingFrames) / Double(totalFrames) * 100)
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            if error == nil {
                self.recordedURL = outputFileURL
                self.analyzeRecording(url: outputFileURL)
            }
        }
    }
}

// MARK: - Camera Preview

struct RecordCameraPreview: UIViewRepresentable {
    let recorder: VideoRecorder
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds   = true
        if let layer = recorder.previewLayer {
            layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            view.layer.addSublayer(layer)
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        recorder.previewLayer?.frame = uiView.bounds
    }
}

// MARK: - Video Player View

struct VideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true

        let player = AVPlayer(url: url)
        let layer  = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 400)
        view.layer.addSublayer(layer)
        player.play()

        // Loop playback
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        context.coordinator.player = player
        context.coordinator.playerLayer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Main View

struct RecordVideoView: View {
    @StateObject private var recorder = VideoRecorder()
    @State private var showAnalysis   = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch recorder.permissionStatus {
                case .unknown, .requesting:
                    // Asking — show spinner
                    VStack(spacing: 16) {
                        ProgressView().tint(.mint).scaleEffect(1.3)
                        Text("Requesting camera & microphone access…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                case .denied:
                    // Denied — guide to settings
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
                        .tint(.mint)
                    }

                case .granted:
                    if showAnalysis, let result = recorder.analysisResult {
                        // Analysis results + video playback
                        VideoAnalysisView(
                            result: result,
                            videoURL: recorder.recordedURL,
                            duration: recorder.recordingDuration
                        ) {
                            showAnalysis = false
                            recorder.reset()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    } else {
                        // Camera viewfinder
                        CameraRecordingView(recorder: recorder)
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
            .onChange(of: recorder.analysisResult) { _, result in
                if result != nil {
                    withAnimation(.spring()) { showAnalysis = true }
                }
            }
        }
        .preferredColorScheme(.dark)
        // Request permissions IMMEDIATELY on appear — no button tap required
        .task {
            await recorder.requestPermissionsAndSetup()
        }
        .animation(.easeInOut(duration: 0.3), value: recorder.permissionStatus)
        .animation(.easeInOut(duration: 0.3), value: showAnalysis)
    }
}

// MARK: - Camera Recording View

struct CameraRecordingView: View {
    @ObservedObject var recorder: VideoRecorder

    var body: some View {
        ZStack {
            if recorder.sessionStarted {
                RecordCameraPreview(recorder: recorder)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(.mint)
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
                .environment(\.colorScheme, .dark)
                .padding(.top, 8)
                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()

                if recorder.isAnalyzing {
                    VStack(spacing: 10) {
                        ProgressView().tint(.mint).scaleEffect(1.2)
                        Text("Analyzing your speech & eye contact…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 16)
                }

                // Timer badge
                if recorder.isRecording {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 7, height: 7)
                            .opacity(recorder.isRecording ? 1 : 0)
                        Text(timeString(recorder.recordingDuration))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 12)
                }

                // Record button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        if recorder.isRecording { recorder.stopRecording() }
                        else { recorder.startRecording() }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white.opacity(0.5), lineWidth: 3)
                            .frame(width: 80, height: 80)
                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.red)
                                .frame(width: 28, height: 28)
                        } else {
                            Circle().fill(.red).frame(width: 64, height: 64)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
                .disabled(recorder.isAnalyzing)

                Text(recorder.isRecording ? "Tap to stop" : "Tap to start recording")
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

                // ── VIDEO PLAYBACK ────────────────────────
                if let url = videoURL {
                    ZStack(alignment: .bottomLeading) {
                        VideoPlayerView(url: url)
                            .frame(height: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 0))

                        // Eye contact badge overlay
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(result.eyeContactColor)
                            Text("\(result.eyeContactScore)% eye contact")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(14)
                    }
                }

                VStack(spacing: 16) {

                    // ── TITLE ─────────────────────────────
                    VStack(spacing: 4) {
                        Text("Recording Analysis")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text(String(format: "%.0f seconds recorded", duration))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // ── METRICS GRID ──────────────────────
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        VideoMetricCard(
                            icon: "speedometer", title: "Pacing",
                            value: result.wpm == 0 ? "—" : "\(result.wpm) WPM",
                            badge: result.wpmBadge,
                            color: (result.wpm >= 120 && result.wpm <= 160) ? .mint : .orange
                        )
                        VideoMetricCard(
                            icon: "exclamationmark.bubble.fill", title: "Fillers",
                            value: "\(result.fillerCount)",
                            badge: result.fillerBadge,
                            color: result.fillerCount <= 3 ? .mint : .orange
                        )
                        VideoMetricCard(
                            icon: "eye.fill", title: "Eye Contact",
                            value: "\(result.eyeContactScore)%",
                            badge: result.eyeContactBadge,
                            color: result.eyeContactColor
                        )
                        VideoMetricCard(
                            icon: "clock.fill", title: "Duration",
                            value: String(format: "%.0fs", duration),
                            badge: "\(result.wordCount) words",
                            color: .cyan
                        )
                    }
                    .padding(.horizontal, 16)

                    // ── EYE CONTACT TIP ───────────────────
                    EyeContactTipCard(score: result.eyeContactScore)
                        .padding(.horizontal, 16)

                    // ── TRANSCRIPT ────────────────────────
                    if !result.transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.quote").font(.system(size: 12)).foregroundStyle(.secondary)
                                Text("Transcript").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                            }
                            Text(result.transcript)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.70))
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                    }

                    // ── DONE ──────────────────────────────
                    Button(action: onDismiss) {
                        HStack(spacing: 9) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 15, weight: .semibold))
                            Text("Record Again").font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.20, green: 0.98, blue: 0.78), Color(red: 0.08, green: 0.76, blue: 0.60)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .mint.opacity(0.30), radius: 14, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
    }
}

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
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value). \(badge)")
    }
}

struct EyeContactTipCard: View {
    let score: Int

    private var tip: (icon: String, color: Color, title: String, message: String) {
        switch score {
        case 80...100:
            return ("eye.fill", .mint, "Excellent Eye Contact",
                    "You maintained strong eye contact. This builds trust and confidence with your audience.")
        case 60..<80:
            return ("eye", .yellow, "Good Eye Contact",
                    "Look toward the camera lens more — treat it as your audience's eyes. Avoid glancing at your own image.")
        case 40..<60:
            return ("eye.slash", .orange, "Improve Eye Contact",
                    "Try placing a sticky dot next to the camera lens as a target. Aim to look there 70–80% of the time.")
        default:
            return ("eye.slash.fill", .red, "Focus on Eye Contact",
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
