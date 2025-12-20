//
//  GoogleSignInButton.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI

struct GoogleSignInButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("google_logo")
                    .font(.title3)

                Text(isLoading ? "Signing in…" : title)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        GoogleSignInButton(title: "Continue with Google", isLoading: false) { }
        GoogleSignInButton(title: "Continue with Google", isLoading: true) { }
    }
    .padding()
    .background(Color(uiColor: .systemGray6))
}
#endif
