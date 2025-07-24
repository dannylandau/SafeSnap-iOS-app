//
//  ScanProgressView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI

struct ScanProgressView: View {
    var phase: ScanPhase

    var body: some View {
        ZStack {
            BlurView(style: .systemUltraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.8)

                Text(phase.text)
                    .font(.title3.bold())
                    .transition(.opacity)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }
}
