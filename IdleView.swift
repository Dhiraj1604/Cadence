//
//  IdleView.swift
//  Cadence
//
//  Created by Dhiraj on 24/02/26.
//
import SwiftUI

struct IdleView: View {
    @EnvironmentObject var session: SessionManager
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Pulsing mic orb
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.08))
                    .frame(width: pulse ? 200 : 160, height: pulse ? 200 : 160)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: pulse ? 150 : 120, height: pulse ? 150 : 120)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.2), value: pulse)

                Image(systemName: "mic.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.mint)
            }
            .onAppear { pulse = true }

            Spacer().frame(height: 40)

            Text("Cadence")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Your personal speaking coach")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)

            Spacer().frame(height: 20)

            // Feature pills
            VStack(spacing: 10) {
                FeaturePill(icon: "waveform", text: "Live speech flow analysis")
                FeaturePill(icon: "person.3.fill", text: "Audience attention simulation")
                FeaturePill(icon: "eye.fill", text: "Eye contact tracking")
            }

            Spacer()

            Button {
                session.startSession()
            } label: {
                Text("Start Practice")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.mint)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.mint)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}
