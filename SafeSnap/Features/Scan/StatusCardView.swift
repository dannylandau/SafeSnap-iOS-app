//
//  StatusCardView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//

import SwiftUI

struct StatusCardView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "eye"); Text("Google Vision Active")
            }
            .font(.headline)
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("API key validated successfully")
            }
            .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondarySystemBackground)
        .cornerRadius(12)
    }
}
