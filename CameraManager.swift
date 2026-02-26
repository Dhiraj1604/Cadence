//CameraManager.swift

@preconcurrency import ARKit
import SwiftUI

@MainActor
class CameraManager: ObservableObject {
    @Published var isMakingEyeContact: Bool = true
    @Published var eyeContactDuration: TimeInterval = 0

    private let arQueue = DispatchQueue(label: "cadence.arkit", qos: .userInteractive)
    private var arSession: ARSession?
    private var delegateHelper: ARHelper!
    private var isRunning = false
    private var lastUpdate = Date()

    init() {
        delegateHelper = ARHelper { [weak self] isLooking in
            self?.handleEyeContact(isLooking)
        }
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        arQueue.async { [weak self] in
            guard let self else { return }
            let session = ARSession()
            session.delegate = self.delegateHelper
            let config = ARFaceTrackingConfiguration()
            session.run(config, options: [.resetTracking, .removeExistingAnchors])
            DispatchQueue.main.async {
                self.arSession = session
                self.isRunning = true
                self.lastUpdate = Date()
            }
        }
    }

    func stop() {
        isRunning = false
        let session = arSession
        arQueue.async { session?.pause() }
        arSession = nil
    }

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

class ARHelper: NSObject, ARSessionDelegate, @unchecked Sendable {
    private let onUpdate: (Bool) -> Void
    init(onUpdate: @escaping (Bool) -> Void) { self.onUpdate = onUpdate }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let isLooking = anchors.compactMap { $0 as? ARFaceAnchor }.first?.isTracked ?? false
        DispatchQueue.main.async { [weak self] in self?.onUpdate(isLooking) }
    }
}
