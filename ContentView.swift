import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch session.state {
            case .idle:
                IdleView()
                    .environmentObject(session)
            case .practicing:
                PracticeView()           // ← was PracticeSessionView (deleted)
                    .environmentObject(session)
            case .summary:
                SummaryView()
                    .environmentObject(session)
            }
        }
    }
}
