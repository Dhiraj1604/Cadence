// RecordVideoViewModel.swift
// Cadence

import SwiftUI
import Combine
@preconcurrency import AVFoundation
import Speech
import Vision

@MainActor
class RecordVideoViewModel: NSObject, ObservableObject {
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var isRecording       = false
    @Published var recordedURL:       URL?                 = nil
    @Published var recordingDuration: TimeInterval         = 0
    @Published var analysisResult:    VideoAnalysisResult? = nil
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

    // MARK: Permissions

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

        guard
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let videoInput  = try? AVCaptureDeviceInput(device: videoDevice),
            session.canAddInput(videoInput)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoInput)

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput  = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let conn = layer.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }

        session.commitConfiguration()

        previewLayer   = layer
        captureSession = session

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
        recordedURL       = nil
        analysisResult    = nil
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
                let text    = result.bestTranscription.formattedString
                let words   = text.lowercased()
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

    private func estimateEyeContact(from url: URL) async -> Int {
        let asset    = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        let secs     = duration.map { CMTimeGetSeconds($0) } ?? 0
        guard secs > 0 else { return 50 }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 0.5, preferredTimescale: 600)

        let sampleCount = max(3, Int(secs / 2))
        let times: [NSValue] = (0..<sampleCount).map { i in
            NSValue(time: CMTime(seconds: Double(i) * secs / Double(sampleCount),
                                 preferredTimescale: 600))
        }

        var facingFrames = 0
        var totalFrames  = 0

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var remaining = times.count
            guard remaining > 0 else { continuation.resume(); return }

            generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, result, _ in
                defer {
                    remaining -= 1
                    if remaining == 0 { continuation.resume() }
                }
                guard result == .succeeded, let cgImage else { return }
                totalFrames += 1
                let request = VNDetectFaceRectanglesRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
                if let faces = request.results, !faces.isEmpty {
                    facingFrames += 1
                }
            }
        }

        guard totalFrames > 0 else { return 50 }
        return Int(Double(facingFrames) / Double(totalFrames) * 100)
    }
}

extension RecordVideoViewModel: AVCaptureFileOutputRecordingDelegate {
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
