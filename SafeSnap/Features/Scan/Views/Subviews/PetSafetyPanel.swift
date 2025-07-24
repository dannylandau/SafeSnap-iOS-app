//
//  PetSafetyPanel.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//

import SwiftUI

struct PetSafetyPanel: View {
    @AppStorage("includeDogSafety") private var includeDogSafety = false
    @AppStorage("includeCatSafety") private var includeCatSafety = false
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { expanded.toggle() } }) {
                HStack {
                    Image(systemName: "gearshape.fill").foregroundColor(.pink)
                    Text("Pet Safety Analysis").font(.headline)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding().background(Color.secondarySystemBackground).cornerRadius(12)
            }

            if expanded {
                VStack(spacing: 16) {
                    Toggle("Dog Safety", isOn: $includeDogSafety)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                    Toggle("Cat Safety", isOn: $includeCatSafety)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("How it works").font(.subheadline.bold())
                        }
                        Text("When enabled, pet safety warnings will be included ...")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.infoBackground)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.secondarySystemBackground)
                .cornerRadius(12)
            }
        }
    }
}
