//
//  SwiftUIView.swift
//  Cadence
//
//  Created by Dhiraj on 26/02/26.
//
import SwiftUI
import AVFoundation
import Vision

struct CameraPreviewView: UIViewRepresentable {
    @Binding var isLooking: Bool // Passes eye contact state up to the UI

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraPreviewView
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Vision request to detect face bounding box
            let request = VNDetectFaceRectanglesRequest { req, err in
                if let results = req.results as? [VNFaceObservation], !results.isEmpty {
                    // Face detected = Making Eye Contact
                    DispatchQueue.main.async { self.parent.isLooking = true }
                } else {
                    // No face detected = Looking Away
                    DispatchQueue.main.async { self.parent.isLooking = false }
                }
            }
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return view }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Add Video Output for Vision tracking
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
