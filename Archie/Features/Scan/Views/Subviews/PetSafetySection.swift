//
//  PetSafetySection.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 20/08/2025.
//

import SwiftUI

struct PetSafetySection: View {
    let petSafety: SafetyAnalysisResponse.PetSafety
    let showDogs: Bool
    let showCats: Bool

    var body: some View {
        Section(header: Text("Pet Safety")) {
            if showDogs { petColumn(title: "Dogs", warnings: petSafety.dogs) }
            if showCats { petColumn(title: "Cats", warnings: petSafety.cats) }
            if (!showDogs && !showCats) || (petSafety.dogs.isEmpty && petSafety.cats.isEmpty) {
                Text("No pet-specific warnings available for this analysis.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func petColumn(title: String, warnings: [SafetyAnalysisResponse.PetWarning]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: title == "Dogs" ? "pawprint.fill" : "pawprint")
                Text(title).font(.headline)
                if let max = warnings.map(\.severity).max(by: severityRank) {
                    PetRiskBadge(severity: max)
                } else {
                    PetRiskBadge(severity: .low) // treat none as low risk
                }
                Spacer()
            }
            if warnings.isEmpty {
                Text("No specific warnings").foregroundStyle(.secondary)
            } else {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, w in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(w.severity.color).frame(width: 8, height: 8)
                            Text(w.warning).font(.subheadline).bold()
                        }
                        Text(w.reason).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PetRiskBadge: View {
    let severity: Severity
    var body: some View {
        Text(severity.label)
            .font(.caption).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(severity.color.opacity(0.15))
            .foregroundStyle(severity.color)
            .clipShape(Capsule())
    }
}
