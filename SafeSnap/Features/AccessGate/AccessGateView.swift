//
//  AccessGateView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

struct AccessGateView: View {
    let model: AccessGateViewModel
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: model.iconName)
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
                .shadow(radius: 4)

            Text(model.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(model.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onPrimaryAction) {
                Label(model.primaryButtonTitle, systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Button(model.secondaryButtonTitle, action: onSecondaryAction)
                .font(.subheadline)
                .foregroundColor(.green)

            Spacer()
        }
        .padding()
    }
}