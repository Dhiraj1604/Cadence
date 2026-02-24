//
//  IdleView.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//
import SwiftUI

struct IdleView: View {
    
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        
        VStack(spacing: 20) {
            
            Spacer()
            
            Text("Cadence")
                .font(.system(size: 42,
                              weight: .semibold))
                .foregroundColor(.white)
            
            Text("Practice your speaking rhythm")
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Button {
                session.startSession()
            } label: {
                
                Text("Start Practice")
                    .font(.headline)
                    .padding()
                    .frame(width: 200)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
    }
}
