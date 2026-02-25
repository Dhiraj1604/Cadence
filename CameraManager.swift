//
//  CameraManager.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//

import SwiftUI
@preconcurrency import ARKit

@MainActor
class CameraManager: ObservableObject {
    @Published var isMakingEyeContact: Bool = true
    @Published var eyeContactDuration: TimeInterval = 0

    // ARSession must run on its own serial queue — NOT main thread
    // Running on main thread causes the libdispatch assertion crash
    private let arQueue = DispatchQueue(label: "cadence.arSession", qos: .userInteractive)
    private var arSession: ARSession?
    private var delegateHelper: ARHelper!

    private var isRunning = false
    private var lastUpdate = Date()

    init() {
        delegateHelper = ARHelper { [weak self] isLooking in
            // ARHelper already hops to main thread before calling this
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
        arQueue.async {
            session?.pause()
        }
        arSession = nil
    }

    private func handleEyeContact(_ isLooking: Bool) {
        self.isMakingEyeContact = isLooking
        if isLooking && isRunning {
            let now = Date()
            self.eyeContactDuration += now.timeIntervalSince(self.lastUpdate)
            self.lastUpdate = now
        } else {
            self.lastUpdate = Date()
        }
    }
}

// Bridges ARKit's background thread → main thread safely
class ARHelper: NSObject, ARSessionDelegate, @unchecked Sendable {
    private let onUpdate: (Bool) -> Void

    init(onUpdate: @escaping (Bool) -> Void) {
        self.onUpdate = onUpdate
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let isLooking = anchors.compactMap { $0 as? ARFaceAnchor }.first?.isTracked ?? false
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate(isLooking)
        }
    }
}
