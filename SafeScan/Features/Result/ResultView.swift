//
//  ResultView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI

struct ResultView: View {
    let product: Product

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(product.name)
                    .font(.largeTitle.bold())

                Text("Safety Score: \(product.safetyScore)/10")
                    .font(.title2)
                    .foregroundColor(colorForScore(product.safetyScore))

                Text("Level: \(product.safetyLevel.capitalized)")
                    .font(.headline)
                    .padding(.bottom)

                if !product.pros.isEmpty {
                    Text("✅ Pros")
                        .font(.headline)
                    ForEach(product.pros) { point in
                        Text("• \(point.label) [\(point.category)]")
                            .foregroundColor(.green)
                    }
                }

                if !product.cons.isEmpty {
                    Text("⚠️ Cons")
                        .font(.headline)
                    ForEach(product.cons) { point in
                        Text("• \(point.label) [\(point.category)]")
                            .foregroundColor(.red)
                    }
                }

                if !product.certifications.isEmpty {
                    Text("📜 Certifications")
                        .font(.headline)
                    ForEach(product.certifications, id: \.self) { cert in
                        Text("• \(cert)")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
        }
    }

    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 5...7: return .yellow
        default: return .red
        }
    }
}

#Preview {
    let sample = Product(
        name: "Fresh Broccoli",
        safetyScore: 9,
        safetyLevel: "safe",
        pros: [
            SafetyPoint(id: "1", label: "High in nutrients", severity: "low", category: "nutrition")
        ],
        cons: [
            SafetyPoint(id: "2", label: "Requires washing", severity: "medium", category: "biological")
        ],
        certifications: ["USDA Organic"]
    )

    return ResultView(product: sample)
}
