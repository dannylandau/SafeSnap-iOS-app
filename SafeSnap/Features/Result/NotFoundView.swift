//
//  NotFoundView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI

struct NotFoundView: View {
    var productName: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Product Not Found")
                .font(.title2.bold())

            if let name = productName {
                Text("We couldn't find a safety record for \"\(name)\".")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text("Try scanning a different angle, product, or lighting.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Scan Again") {
                // Just dismiss the view
                UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: true)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
}