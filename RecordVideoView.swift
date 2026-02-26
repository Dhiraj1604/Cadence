// RecordVideoView.swift
// Cadence — iOS 26 Native
// FIX: Added @Environment(\.dismiss) and an xmark.circle.fill toolbar button
//      so user can always go back. Without this, fullScreenCover had no exit.

import SwiftUI
@preconcurrency import AVFoundation
import Speech

// MARK: - Analysis Result
struct VideoAnalysisResult: Equatable {
    let transcript:  String
    let wordCount:   Int
    let wpm:         Int
    let fillerCount: Int
    let duration:    TimeInterval

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
        case 0:     return "Flawless"
        case 1...3: return "Great"
        case 4...7: return "Noticeable"
        default:    return "Needs Work"
        }
    }
}

// MARK: - Video Recorder Engine
@MainActor
class VideoRecorder: NSObject, ObservableObject {
    @Published var isRecording       = false
    @Published var recordedURL:       URL?              = nil
    @Published var recordingDuration: TimeInterval      = 0
    @Published var analysisResult:    VideoAnalysisResult? = nil
    @Published var isAnalyzing        = false
    @Published var permissionsGranted = false
    @Published var sessionStarted     = false

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
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video, position: .front),
            let videoInput  = try? AVCaptureDeviceInput(device: videoDevice),
            session.canAddInput(videoInput)
        else { return }
        session.addInput(videoInput)

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput  = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let conn = layer.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }

        previewLayer   = layer
        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        sessionStarted = true
    }

    func startRecording() {
        guard let s = captureSession, s.isRunning else { return }
        try? FileManager.default.removeItem(at: outputURL)
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording      = true
        recordingDuration = 0
        analysisResult   = nil
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

    private func analyzeRecording(url: URL) {
        isAnalyzing = true
        Task {
            let result = await runSpeechAnalysis(on: url)
            analysisResult = result
            isAnalyzing    = false
        }
    }

    private func runSpeechAnalysis(on url: URL) async -> VideoAnalysisResult {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        let request    = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            var done = false
            recognizer?.recognitionTask(with: request) { result, error in
                guard !done else { return }
                guard let result, result.isFinal else {
                    if error != nil { done = true; continuation.resume(returning: .empty) }
                    return
                }
                done = true
                let text   = result.bestTranscription.formattedString
                let words  = text.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                let fillers = words.filter {
                    ["um","uh","like","so","actually","basically"].contains($0)
                }.count
                let dur = result.bestTranscription.segments.last?.timestamp ?? 1.0
                let wpm = dur > 0 ? Int(Double(words.count) / (dur / 60.0)) : 0
                continuation.resume(returning: VideoAnalysisResult(
                    transcript: text, wordCount: words.count,
                    wpm: wpm, fillerCount: fillers, duration: dur
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
        view.clipsToBounds   = true
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
    @State private var showAnalysis   = false

    // FIX: dismiss environment — lets the X button close the fullScreenCover
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if !recorder.permissionsGranted {
                    ContentUnavailableView {
                        Label("Camera Access Needed", systemImage: "video.slash.fill")
                    } description: {
                        Text("Cadence needs camera and microphone access to record practice sessions.")
                    } actions: {
                        Button("Grant Access") {
                            Task { await recorder.requestPermissions() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                    }

                } else if showAnalysis, let result = recorder.analysisResult {
                    VideoAnalysisView(
                        result:    result,
                        duration:  recorder.recordingDuration
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
                                colors: [.black.opacity(0.55), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 160)
                            Spacer()
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.75)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 240)
                        }
                        .ignoresSafeArea()

                        VStack {
                            Spacer()

                            if recorder.isAnalyzing {
                                VStack(spacing: 12) {
                                    ProgressView().tint(.mint).scaleEffect(1.3)
                                    Text("Analyzing speech…")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(24)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                .padding(.bottom, 20)
                            }

                            VStack(spacing: 16) {
                                if recorder.isRecording {
                                    Label(timeString(recorder.recordingDuration),
                                          systemImage: "circle.fill")
                                        .font(.system(size: 14, weight: .semibold,
                                                      design: .monospaced))
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.multicolor)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(.regularMaterial, in: Capsule())
                                }

                                Button {
                                    withAnimation(.spring(response: 0.35,
                                                         dampingFraction: 0.7)) {
                                        if recorder.isRecording { recorder.stopRecording() }
                                        else { recorder.startRecording() }
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(.white.opacity(0.4), lineWidth: 3)
                                            .frame(width: 78, height: 78)
                                        if recorder.isRecording {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.red)
                                                .frame(width: 28, height: 28)
                                        } else {
                                            Circle()
                                                .fill(.red)
                                                .frame(width: 62, height: 62)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    recorder.isRecording ? "Stop recording" : "Start recording"
                                )

                                Text(recorder.isRecording ? "Tap to stop" : "Tap to record")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 48)
                        }
                    }
                }
            }
            .navigationTitle("Record & Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                // FIX: Close button — top left, always visible
                // This was completely missing, leaving users trapped in fullScreenCover
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityLabel("Close Record and Review")
                }
            }
            .onChange(of: recorder.analysisResult) { _, result in
                if result != nil {
                    withAnimation(.spring()) { showAnalysis = true }
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

// MARK: - Analysis Results
struct VideoAnalysisView: View {
    let result:    VideoAnalysisResult
    let duration:  TimeInterval
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AnalysisMetricRow(
                        symbol: "speedometer",
                        label:  "Pacing",
                        value:  result.wpm == 0 ? "—" : "\(result.wpm) WPM",
                        badge:  result.wpmBadge,
                        color:  (result.wpm >= 120 && result.wpm <= 160) ? .mint : .orange
                    )
                    AnalysisMetricRow(
                        symbol: "exclamationmark.bubble.fill",
                        label:  "Filler Words",
                        value:  "\(result.fillerCount)",
                        badge:  result.fillerBadge,
                        color:  result.fillerCount <= 3 ? .mint : .orange
                    )
                    AnalysisMetricRow(
                        symbol: "clock.fill",
                        label:  "Duration",
                        value:  String(format: "%.0f sec", duration),
                        badge:  "\(result.wordCount) words",
                        color:  .blue
                    )
                } header: { Text("Results") }

                if !result.transcript.isEmpty {
                    Section("Transcript") {
                        Text(result.transcript)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .lineSpacing(4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recording Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.mint)
                    }
                    .accessibilityLabel("Done")
                }
            }
        }
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
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value). \(badge)")
    }
}
