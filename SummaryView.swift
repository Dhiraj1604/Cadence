// Summary View
//  SummaryView.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Practice Complete")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 40)
            
            // Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                MetricCard(title: "Pacing", value: "\(session.finalWPM)", subtitle: "Words / Min", color: .mint)
                MetricCard(title: "Filler Words", value: "\(session.finalFillers)", subtitle: "Total Count", color: .orange)
                MetricCard(title: "Eye Contact", value: "\(session.eyeContactPercentage)%", subtitle: "Of Total Time", color: .green)
                MetricCard(title: "Duration", value: timeString(from: session.duration), subtitle: "Minutes", color: .blue)
            }
            .padding(.horizontal, 20)
            
            // Transcript Box
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Transcript")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ScrollView {
                    Text(session.finalTranscript.isEmpty ? "No speech was detected during this session." : session.finalTranscript)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: {
                session.resetSession()
            }) {
                Text("Practice Again")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.mint)
                    .foregroundColor(.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}
