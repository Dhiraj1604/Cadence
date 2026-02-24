//
//  SummaryView.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//

import SwiftUI

struct SummaryView: View {
    
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        
        VStack(spacing: 20) {
            
            Text("Session Complete")
                .font(.title)
                .foregroundColor(.white)
            
            Button("Practice Again") {
                session.resetSession()
            }
        }
    }
}
