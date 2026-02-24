//
//  PractiseView.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//
import SwiftUI

struct PracticeView: View {
    
    @EnvironmentObject var session: SessionManager
    
    @StateObject private var audio = AudioManager()
    
    var body: some View {
        
        VStack {
            
            Text("Speaking...")
                .foregroundColor(.white)
            
            ProgressView(value: session.duration,
                         total: session.maxDuration)
                .padding()
            
            Text("Amplitude: \(audio.amplitude)")
                .foregroundColor(.white)
        }
        .onAppear {
            audio.start()
        }
        .onDisappear {
            audio.stop()
        }
    }
}
