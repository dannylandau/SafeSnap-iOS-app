//
//  WelcomeView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI

struct WelcomeView: View {
    @AppStorage("hasLaunched") private var hasLaunched = false

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "shield.checkerboard")
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .padding()

            Text("Welcome to SafeScan")
                .font(.largeTitle.bold())

            Text("Scan food, toys, and household products to check their safety using AI.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Start Scanning") {
                hasLaunched = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
