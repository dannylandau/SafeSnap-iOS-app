//
//  HistoryView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

struct HistoryView: View {
    @State private var isSignedIn = false // for future logic

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
                .shadow(radius: 4)

            Text("View Scan History")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Sign in to access your saved product scans and safety analysis history")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                // TODO: Sign in action
            }) {
                Label("Sign In", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Button("Continue without signing in") {
                // TODO: Continue as guest
            }
            .font(.subheadline)
            .foregroundColor(.green)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    HistoryView()
}
