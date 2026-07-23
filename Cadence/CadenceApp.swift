//
//  CadenceApp.swift
//  Cadence
//
//  Created by Dhiraj on 20/07/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - Portrait-only lock
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
#endif

@main
struct CadenceApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
