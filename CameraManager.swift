// CameraManager.swift
// Cadence — Apple Native Redesign
// ARSCNView created lazily only when start() is called.

@preconcurrency import ARKit
import SwiftUI
import SceneKit

@MainActor
class CameraManager: ObservableObject {
    @Published var isMakingEyeContact: Bool = false   // false until a face is actually tracked
    @Published var faceDetected: Bool = false          // true once ARKit finds a face
    @Published var eyeContactDuration: TimeInterval = 0
    @Published var isARSupported: Bool = false

    private(set) var sceneView: ARSCNView? = nil
    private var delegateHelper: ARHelper?
    private var isRunning = false
    private var lastUpdate = Date()

    init() {
        isARSupported = ARFaceTrackingConfiguration.isSupported
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            isARSupported = false
            return
        }
        isARSupported = true

        if sceneView == nil {
            let v = ARSCNView()
            v.automaticallyUpdatesLighting = false
            v.rendersContinuously = false
            v.scene = SCNScene()
            v.backgroundColor = .black

            let helper = ARHelper { [weak self] isLooking, facePresent in
                self?.handleEyeContact(isLooking, facePresent: facePresent)
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
        faceDetected = false        // reset on every new session
        isMakingEyeContact = false  // start neutral until face is found
    }

    func stop() {
        isRunning = false
        sceneView?.session.pause()
    }

    private func handleEyeContact(_ isLooking: Bool, facePresent: Bool) {
        faceDetected       = facePresent
        isMakingEyeContact = facePresent ? isLooking : false
        if isLooking && facePresent && isRunning {
            let now = Date()
            eyeContactDuration += now.timeIntervalSince(lastUpdate)
            lastUpdate = now
        } else {
            lastUpdate = Date()
        }
    }
}

// MARK: - SwiftUI wrapper
struct CameraPreviewView: UIViewRepresentable {
    let sceneView: ARSCNView
    func makeUIView(context: Context) -> ARSCNView { sceneView }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

// MARK: - ARKit delegate helper
class ARHelper: NSObject, ARSessionDelegate, @unchecked Sendable {
    private let onUpdate: (Bool, Bool) -> Void   // (isLooking, facePresent)
    init(onUpdate: @escaping (Bool, Bool) -> Void) { self.onUpdate = onUpdate }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let faceAnchor = anchors.compactMap { $0 as? ARFaceAnchor }.first
        let facePresent = faceAnchor != nil
        let isTracked   = faceAnchor?.isTracked ?? false
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate(isTracked, facePresent)
        }
    }

    // Called when a face anchor is removed (face leaves frame)
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let hadFace = anchors.contains { $0 is ARFaceAnchor }
        if hadFace {
            DispatchQueue.main.async { [weak self] in
                self?.onUpdate(false, false)
            }
        }
    }
}
