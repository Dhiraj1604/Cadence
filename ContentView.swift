// ContentView.swift
// Cadence — SSC Edition
// KEY CHANGE: .preferredColorScheme(.dark) at root ZStack level
// This prevents ANY light-mode flash from List, NavigationStack, or sheets.

import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()
    @AppStorage("cadence_onboarding_v3") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        hasSeenOnboarding = true
                    }
                }
                .zIndex(10)
                .transition(.opacity)
            } else {
                switch session.state {
                case .idle:
                    HomeHubView()
                        .environmentObject(session)
                        .transition(.opacity)

                case .practicing:
                    PracticeView()
                        .environmentObject(session)
                        .ignoresSafeArea()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.02)),
                            removal: .opacity
                        ))

                case .summary:
                    SummaryView()
                        .environmentObject(session)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom),
                            removal: .opacity
                        ))
                }
            }
        }
        // GLOBAL DARK MODE — prevents all white/gray flashes from List, NavigationStack, sheets
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.45), value: hasSeenOnboarding)
        .animation(.easeInOut(duration: 0.35), value: session.state)
    }
}

// MARK: - Home Hub

struct HomeHubView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        TabView {
            Tab("Practice", systemImage: "mic.fill") {
                IdleView()
                    .environmentObject(session)
            }
            Tab("Read", systemImage: "text.page.fill") {
                ReadPracticeView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                InsightsView()
                    .environmentObject(session)
            }
        }
        .tint(.mint)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
