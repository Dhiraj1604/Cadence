import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()
    
    var body: some View {
        ZStack {
            // Acts as the base background for Idle and Summary
            Color.black
                .ignoresSafeArea()
            
            switch session.state {
            case .idle:
                IdleView()
                    .environmentObject(session)
                
            case .practicing:
                // Our new Camera + Glass UI
                PracticeSessionView()
                    .environmentObject(session)
                
            case .summary:
                SummaryView()
                    .environmentObject(session)
            }
        }
    }
}
