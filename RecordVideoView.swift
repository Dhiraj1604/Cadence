//
//  RecordVideoView.swift
//  Cadence
//
//  Created by Dhiraj on 26/02/26.
// RecordVideoView.swift
// Cadence — SSC Edition
// Tab 3: Record yourself, watch back, get analysis

import SwiftUI
@preconcurrency import AVFoundation
import Speech

// MARK: - Analysis Result (Equatable for onChange)
struct VideoAnalysisResult: Equatable {
    let transcript: String
    let wordCount: Int
    let wpm: Int
    let fillerCount: Int
    let duration: TimeInterval

    static let empty = VideoAnalysisResult(
        transcript: "", wordCount: 0, wpm: 0, fillerCount: 0, duration: 0
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
        case 0:    return "Flawless"
        case 1...3: return "Great"
        case 4...7: return "Noticeable"
        default:   return "Needs Work"
        }
    }
}

// MARK: - Video Recorder Engine
@MainActor
class VideoRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordedURL: URL? = nil
    @Published var recordingDuration: TimeInterval = 0
    @Published var analysisResult: VideoAnalysisResult? = nil
    @Published var isAnalyzing = false
    @Published var permissionsGranted = false
    @Published var sessionStarted = false

    private var captureSession: AVCaptureSession?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private var movieOutput = AVCaptureMovieFileOutput()
    private var timerTask: Task<Void, Never>?

    private var outputURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("cadence_rec.mov")
    }

    func requestPermissions() async {
        let cam = await AVCaptureDevice.requestAccess(for: .video)
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        permissionsGranted = cam && mic
        if permissionsGranted { setupSession() }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard
            let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
            session.canAddInput(videoInput)
        else { return }
        session.addInput(videoInput)

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.isVideoMirrored = true
        previewLayer = layer

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        sessionStarted = true
    }

    func startRecording() {
        guard let session = captureSession, session.isRunning else { return }
        try? FileManager.default.removeItem(at: outputURL)
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        recordingDuration = 0
        analysisResult = nil
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
        recordedURL = nil
        analysisResult = nil
        recordingDuration = 0
    }

    private func analyzeRecording(url: URL) {
        isAnalyzing = true
        Task {
            let result = await runSpeechAnalysis(on: url)
            analysisResult = result
            isAnalyzing = false
        }
    }

    private func runSpeechAnalysis(on url: URL) async -> VideoAnalysisResult {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            var didResume = false
            recognizer?.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                guard let result = result, result.isFinal else {
                    if error != nil {
                        didResume = true
                        continuation.resume(returning: .empty)
                    }
                    return
                }
                didResume = true
                let text = result.bestTranscription.formattedString
                let words = text.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                let fillerSet: Set<String> = ["um", "uh", "like", "so", "actually", "basically"]
                let fillers = words.filter { fillerSet.contains($0) }.count
                let duration = result.bestTranscription.segments.last?.timestamp ?? 1.0
                let wpm = duration > 0 ? Int(Double(words.count) / (duration / 60.0)) : 0
                continuation.resume(returning: VideoAnalysisResult(
                    transcript: text,
                    wordCount: words.count,
                    wpm: wpm,
                    fillerCount: fillers,
                    duration: duration
                ))
            }
        }
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
        view.clipsToBounds = true
        if let layer = recorder.previewLayer {
            layer.frame = UIScreen.main.bounds
            view.layer.addSublayer(layer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        recorder.previewLayer?.frame = uiView.bounds
    }
}

// MARK: - Main View
struct RecordVideoView: View {
    @StateObject private var recorder = VideoRecorder()
    @State private var showAnalysis = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !recorder.permissionsGranted {
                PermissionRequestView {
                    Task { await recorder.requestPermissions() }
                }
            } else if showAnalysis, let result = recorder.analysisResult {
                VideoAnalysisView(
                    result: result,
                    duration: recorder.recordingDuration
                ) {
                    showAnalysis = false
                    recorder.reset()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))

            } else {
                ZStack {
                    if recorder.sessionStarted {
                        RecordCameraPreview(recorder: recorder)
                            .ignoresSafeArea()
                    }

                    // Gradient overlays
                    VStack {
                        LinearGradient(
                            colors: [.black.opacity(0.65), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 160)
                        Spacer()
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 260)
                    }
                    .ignoresSafeArea()

                    VStack {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Record & Review")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Film yourself — get full speech analysis")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.55))
                            }
                            Spacer()
                            if recorder.isRecording {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(timeString(recorder.recordingDuration))
                                        .font(.system(size: 15, design: .monospaced).bold())
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 52)

                        Spacer()

                        // Analyzing indicator
                        if recorder.isAnalyzing {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: .mint)
                                    )
                                    .scaleEffect(1.2)
                                Text("Analyzing your speech…")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.6))
                            }
                            .padding(20)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(16)
                            .padding(.bottom, 20)
                        }

                        // Record button
                        VStack(spacing: 14) {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    if recorder.isRecording { recorder.stopRecording() }
                                    else { recorder.startRecording() }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                    if recorder.isRecording {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.red)
                                            .frame(width: 30, height: 30)
                                    } else {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 64, height: 64)
                                    }
                                }
                            }
                            Text(recorder.isRecording ? "Tap to stop" : "Tap to record")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.55))
                        }
                        .padding(.bottom, 60)
                    }
                }
                .onChange(of: recorder.analysisResult) { result in
                    if result != nil {
                        withAnimation(.spring()) { showAnalysis = true }
                    }
                }
            }
        }
        .task {
            if !recorder.permissionsGranted {
                await recorder.requestPermissions()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showAnalysis)
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Permission Request
struct PermissionRequestView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.fill")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.mint)
            VStack(spacing: 8) {
                Text("Camera & Microphone")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text("Cadence needs access to record\nyour practice sessions.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Button(action: onRequest) {
                Text("Grant Access")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 200, height: 50)
                    .background(Color.mint)
                    .cornerRadius(14)
            }
        }
    }
}

// MARK: - Video Analysis Results
struct VideoAnalysisView: View {
    let result: VideoAnalysisResult
    let duration: TimeInterval
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.06, blue: 0.05), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text("Recording Analysis")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(String(format: "%.0fs · %d words", duration, result.wordCount))
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.4))
                    }
                    .padding(.top, 52)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        MetricCard(
                            icon: "speedometer",
                            title: "Pacing",
                            value: result.wpm == 0 ? "—" : "\(result.wpm)",
                            unit: "Words / Min",
                            badge: result.wpmBadge,
                            color: (result.wpm >= 120 && result.wpm <= 160) ? .mint : .orange
                        )
                        MetricCard(
                            icon: "exclamationmark.bubble",
                            title: "Fillers",
                            value: "\(result.fillerCount)",
                            unit: "Total Used",
                            badge: result.fillerBadge,
                            color: result.fillerCount <= 3 ? .mint : .orange
                        )
                    }
                    .padding(.horizontal, 20)

                    if !result.transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.4))
                                Text("Transcript")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(result.transcript)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.62))
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }

                    Button(action: onDismiss) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Record Again")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [.mint, Color(red: 0.2, green: 0.85, blue: 0.68)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}
