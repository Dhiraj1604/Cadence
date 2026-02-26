// CameraManager.swift
// Cadence — SSC Edition
//
// FIXED: ARSCNView is now created lazily only when start() is called.
// This prevents the black-screen crash on devices where ARKit
// initialisation fails before camera permission is granted.

@preconcurrency import ARKit
import SwiftUI
import SceneKit

@MainActor
class CameraManager: ObservableObject {
    @Published var isMakingEyeContact: Bool = true
    @Published var eyeContactDuration: TimeInterval = 0
    @Published var isARSupported: Bool = false

    // Lazily created — nil until start() is called successfully.
    private(set) var sceneView: ARSCNView? = nil

    private var delegateHelper: ARHelper?
    private var isRunning = false
    private var lastUpdate = Date()

    init() {
        // Do NOT touch ARKit here — just check support flag.
        isARSupported = ARFaceTrackingConfiguration.isSupported
    }

    // MARK: - Public API

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            isARSupported = false
            return
        }
        isARSupported = true

        // Build the ARSCNView here, safely, after we know the device supports it.
        if sceneView == nil {
            let v = ARSCNView()
            v.automaticallyUpdatesLighting = false
            v.rendersContinuously = false
            v.scene = SCNScene()
            v.backgroundColor = .black

            let helper = ARHelper { [weak self] isLooking in
                self?.handleEyeContact(isLooking)
            }
            v.session.delegate = helper
            delegateHelper = helper
            sceneView = v
        }

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        sceneView?.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        lastUpdate = Date()
    }

    func stop() {
        isRunning = false
        sceneView?.session.pause()
    }

    // MARK: - Eye contact tracking

    private func handleEyeContact(_ isLooking: Bool) {
        isMakingEyeContact = isLooking
        if isLooking && isRunning {
            let now = Date()
            eyeContactDuration += now.timeIntervalSince(lastUpdate)
            lastUpdate = now
        } else {
            lastUpdate = Date()
        }
    }
}

// MARK: - SwiftUI wrapper for the AR camera preview
struct CameraPreviewView: UIViewRepresentable {
    let sceneView: ARSCNView

    func makeUIView(context: Context) -> ARSCNView { sceneView }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

// MARK: - Camera Mirror Card (used inside PracticeView)
struct CameraMirrorCard: View {
    @ObservedObject var cameraManager: CameraManager

    private var borderColor: Color {
        cameraManager.isMakingEyeContact ? .mint : .red
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if cameraManager.isARSupported, let sv = cameraManager.sceneView {
                // Mirror horizontally so it looks like a selfie
                CameraPreviewView(sceneView: sv)
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: 88, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                // Fallback for non-TrueDepth devices (older iPhones)
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 88, height: 118)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 20, weight: .thin))
                                .foregroundColor(Color(white: 0.3))
                            Text("Front camera\nnot available")
                                .font(.system(size: 8))
                                .foregroundColor(Color(white: 0.28))
                                .multilineTextAlignment(.center)
                        }
                    }
            }

            // Eye contact status badge
            Label(
                cameraManager.isMakingEyeContact ? "Eye ✓" : "Look up",
                systemImage: cameraManager.isMakingEyeContact ? "eye.fill" : "eye.slash.fill"
            )
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(cameraManager.isMakingEyeContact ? .mint : .red)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.72))
            .cornerRadius(7)
            .padding(.bottom, 7)
        }
        .frame(width: 88, height: 118)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor.opacity(0.8), lineWidth: 1.5)
        )
        .shadow(color: borderColor.opacity(0.3), radius: 8)
        .animation(.easeInOut(duration: 0.3), value: cameraManager.isMakingEyeContact)
        .animation(.easeInOut(duration: 0.3), value: cameraManager.isARSupported)
    }
}

// MARK: - ARKit delegate helper
class ARHelper: NSObject, ARSessionDelegate, @unchecked Sendable {
    private let onUpdate: (Bool) -> Void
    init(onUpdate: @escaping (Bool) -> Void) { self.onUpdate = onUpdate }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let isTracked = anchors
            .compactMap { $0 as? ARFaceAnchor }
            .first?.isTracked ?? false
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate(isTracked)
        }
    }
}
