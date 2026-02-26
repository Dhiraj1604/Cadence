// ContentView.swift
// Cadence — SSC Edition
//
// App flow:
//   1. First launch  → OnboardingView (full screen, NO tab bar)
//   2. After Begin   → HomeHubView    (3-tab, tab bar visible)
//   3. Let's Start   → PracticeView  (full screen, NO tab bar)
//   4. Stop session  → SummaryView   (full screen, NO tab bar, has Done button)
//   5. Done          → back to HomeHubView
//
// KEY CHANGE: Using "cadence_onboarding_v3" so any device that saw
// the old onboarding key will see the new onboarding fresh.

import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()

    // New key — forces onboarding to show even on devices that saw old versions
    @AppStorage("cadence_onboarding_v3") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            if !hasSeenOnboarding {
                // ── STEP 1: Onboarding ─────────────────────
                // Full screen replacement. TabView does NOT exist yet.
                // Tab bar is physically impossible here.
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        hasSeenOnboarding = true
                    }
                }
                .zIndex(10)
                .transition(.opacity)

            } else {
                // ── STEP 2-5: Main app ─────────────────────
                switch session.state {

                case .idle:
                    // Tab bar visible — correct, this is the home hub
                    HomeHubView()
                        .environmentObject(session)
                        .transition(.opacity)

                case .practicing:
                    // Full screen — tab bar gone
                    PracticeView()
                        .environmentObject(session)
                        .ignoresSafeArea()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.02)),
                            removal: .opacity
                        ))

                case .summary:
                    // Full screen — tab bar gone, has its own Done button
                    SummaryView()
                        .environmentObject(session)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: hasSeenOnboarding)
        .animation(.easeInOut(duration: 0.35), value: session.state)
    }
}

// MARK: - Home Hub — 3 tabs
// Practice | Read | Progress
// (Record is accessed from inside the Practice tab via a card — no redundant tab)
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
