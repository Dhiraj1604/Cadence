// ContentView.swift
// Cadence — Dark Green Mint Theme

import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()
    // Always show onboarding on every launch (State resets on app start)
    @State private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            // ── MAIN TAB SHELL ─────────────────────────────────────────
            TabView {
                IdleView()
                    .environmentObject(session)
                    .tabItem { Label("Practice", systemImage: "mic.fill") }
                    .tag(0)

                ReadPracticeView()
                    .tabItem { Label("Read", systemImage: "doc.text.fill") }
                    .tag(1)

                InsightsView()
                    .environmentObject(session)
                    .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                    .tag(2)
            }
            .tint(Color.cadenceAccent)

            // ── PRACTICE SESSION OVERLAY ───────────────────────────────
            if session.state == .practicing {
                PracticeView()
                    .environmentObject(session)
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }

            // ── SUMMARY OVERLAY ────────────────────────────────────────
            if session.state == .summary {
                SummaryView()
                    .environmentObject(session)
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }

            // ── ONBOARDING (first launch only) ─────────────────────────
            if !hasSeenOnboarding {
                OnboardingView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        hasSeenOnboarding = true
                    }
                })
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: session.state)
        .animation(.easeInOut(duration: 0.5), value: hasSeenOnboarding)
        .preferredColorScheme(.dark)
    }
}
