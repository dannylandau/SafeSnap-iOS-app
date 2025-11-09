//
//  PetSafetyCard.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI

struct PetSafetyCard: View {
    @Binding var includeDog: Bool
    @Binding var includeCat: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("Pet Safety Analysis")
                .font(.headline)

            ToggleRow(
                icon: "pawprint.fill",
                title: "Dog Safety",
                subtitle: "Include dog safety warning",
                isOn: $includeDog,
                tint: Color.orange
            )

            ToggleRow(
                icon: "pawprint",
                title: "Cat Safety",
                subtitle: "Include cat safety warnings",
                isOn: $includeCat,
                tint: Color.green
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
        )
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: tint))
        }
    }
}

#if DEBUG
struct PetSafetyCard_Previews: PreviewProvider {
    static var previews: some View {
        PetSafetyCard(includeDog: .constant(true), includeCat: .constant(false))
            .padding()
            .background(Color(uiColor: .systemGray6))
    }
}
#endif
