// ContentView.swift
// Cadence — SSC Edition
// iOS 26 — native TabView with Liquid Glass
// Tab bar appears ONLY on the home hub, never on Practice/Summary full-screen flows

import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()

    var body: some View {
        ZStack {
            switch session.state {
            case .idle:
                HomeHubView()
                    .environmentObject(session)
                    .transition(.opacity)

            case .practicing:
                // Full screen — no tab bar
                PracticeView()
                    .environmentObject(session)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity
                    ))

            case .summary:
                // Full screen — no tab bar
                SummaryView()
                    .environmentObject(session)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.state)
    }
}

// MARK: - Home Hub — iOS 26 native TabView
// The Liquid Glass tab bar is rendered automatically by the system
struct HomeHubView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        TabView {
            Tab("Practice", systemImage: "mic.fill") {
                IdleView()
                    .environmentObject(session)
            }

            Tab("Record", systemImage: "video.fill") {
                RecordVideoView()
            }

            Tab("Read", systemImage: "text.page.fill") {
                ReadPracticeView()
            }
        }
        .tint(.mint)
        // iOS 26 Liquid Glass tab bar style
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
