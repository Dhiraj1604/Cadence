// ContentView.swift

// ContentView.swift
// Cadence — SSC Edition
//
// ── App Flow ─────────────────────────────────────────────────
//
//   LAUNCH → HomeHubView  (tab bar: Practice | Read | Record | Progress)
//               │
//               ├─ Practice tab → IdleView → [Begin Practice]
//               │                                   │
//               │                              PracticeView (full screen, NO tab bar)
//               │                                   │
//               │                              SummaryView (full screen, NO tab bar)
//               │                                   │
//               │                              [Practice Again] → HomeHubView ✓
//               │
//               ├─ Read tab → ReadPracticeView
//               ├─ Record tab → RecordVideoView
//               └─ Progress tab → InsightsView

import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch session.state {
            case .idle:
                // Home hub — owns the tab bar
                HomeHubView()
                    .environmentObject(session)
                    .transition(.opacity)

            case .practicing:
                // Full screen — tab bar hidden completely
                PracticeView()
                    .environmentObject(session)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity
                    ))

            case .summary:
                // Full screen — tab bar hidden completely
                SummaryView()
                    .environmentObject(session)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.32), value: session.state)
    }
}

// MARK: - Home Hub
// The tab bar lives here only — never bleeds into full-screen flows.
struct HomeHubView: View {
    @EnvironmentObject var session: SessionManager
    @State private var selectedTab: HomeTab = .practice

    enum HomeTab: Int, CaseIterable {
        case practice, read, record, progress

        var title: String {
            switch self {
            case .practice: return "Practice"
            case .read:     return "Read"
            case .record:   return "Record"
            case .progress: return "Progress"
            }
        }
        var icon: String {
            switch self {
            case .practice: return "mic.fill"
            case .read:     return "doc.text.magnifyingglass"
            case .record:   return "video.circle.fill"
            case .progress: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Page content ─────────────────────────────────
            Group {
                switch selectedTab {
                case .practice:
                    IdleView()
                        .environmentObject(session)
                case .read:
                    ReadPracticeView()
                case .record:
                    RecordVideoView()
                case .progress:
                    InsightsView()
                        .environmentObject(session)
                }
            }
            // Give content breathing room above the tab bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 82)
            }
            .animation(.easeInOut(duration: 0.20), value: selectedTab)

            // ── Floating Tab Bar ──────────────────────────────
            CadenceTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Cadence Tab Bar
// Apple HIG compliance:
// • Each icon area is ≥44pt tall
// • Active tab uses tint colour clearly
// • Uses system materials for background (adapts to light/dark)
// • Labels are always visible (not hidden on selection)
struct CadenceTabBar: View {
    @Binding var selected: HomeHubView.HomeTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeHubView.HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        // Icon container — 44pt touch target
                        ZStack {
                            if selected == tab {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.mint.opacity(0.16))
                                    .frame(width: 46, height: 30)
                                    .matchedGeometryEffect(id: "tab_bg", in: tabNS)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(
                                    size: selected == tab ? 18 : 16,
                                    weight: selected == tab ? .semibold : .regular
                                ))
                                .foregroundColor(selected == tab ? .mint : Color(white: 0.38))
                        }
                        .frame(height: 30)
                        // Label
                        Text(tab.title)
                            .font(.system(
                                size: 10,
                                weight: selected == tab ? .semibold : .regular
                            ))
                            .foregroundColor(selected == tab ? .mint : Color(white: 0.32))
                    }
                    .frame(maxWidth: .infinity)
                    // Full 44pt tap area
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 28)   // safe area bottom
        .background(
            ZStack {
                // Frosted glass base
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                // Extra darkening layer to match Cadence palette
                Rectangle()
                    .fill(Color.black.opacity(0.50))
            }
        )
        .overlay(
            // Hairline separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    @Namespace private var tabNS
}
