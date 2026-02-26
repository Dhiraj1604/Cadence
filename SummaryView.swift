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
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Practice Complete")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .padding(.top, 40)
            
            // Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                SummaryCard(title: "Pacing", value: "\(session.finalWPM)", unit: "Words / Min", valueColor: .teal)
                SummaryCard(title: "Filler Words", value: "\(session.finalFillers)", unit: "Total Count", valueColor: .orange)
                SummaryCard(title: "Eye Contact", value: "\(session.eyeContactPercentage)%", unit: "Of Total Time", valueColor: .green)
                SummaryCard(title: "Duration", value: timeString(from: session.duration), unit: "Minutes", valueColor: .blue)
            }
            
            Text("Your Transcript")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 10)
            
            // Transcript Box
            ScrollView {
                Text(session.finalTranscript)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Practice Again Button
            Button(action: {
                withAnimation {
                    session.resetSession()
                }
            }) {
                Text("Practice Again")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal.opacity(0.8))
                    .cornerRadius(15)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal)
        .background(Color.black.ignoresSafeArea())
    }
    
    private func timeString(from duration: TimeInterval) -> String {
        let seconds = Int(duration)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// Reusable Card Component
struct SummaryCard: View {
    var title: String
    var value: String
    var unit: String
    var valueColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(valueColor)
            Text(unit)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .cornerRadius(12)
    }
}
