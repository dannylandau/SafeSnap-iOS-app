//
//  ResultView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI

struct ResultView: View {
    @State private var recalls: [RecallRecord] = []
    let product: Product
    let scanLabels: [String]?

    var body: some View {
        let sources = SourceService.shared.sources(for: product.productType)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(product.name)
                    .font(.largeTitle.bold())
                
                if let scanLabels = scanLabels, !scanLabels.isEmpty {
                    Text("🧠 Vision Labels")
                        .font(.headline)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.5), value: scanLabels)

                    ForEach(scanLabels.enumerated().map({ $0 }), id: \.element) { index, label in
                        HStack {
                            Text("• \(label.capitalized)")
                                .font(.subheadline)
                                .foregroundColor(index == 0 ? .green : .secondary)
                                .transition(.opacity)
                                .animation(.easeOut.delay(Double(index) * 0.05), value: scanLabels)
                        }
                    }
                }

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
                
                if !recalls.isEmpty {
                    Text("⚠️ Recall Alerts")
                        .font(.headline)
                        .foregroundColor(.red)

                    ForEach(recalls.prefix(3)) { recall in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recall.productName)
                                .bold()
                            Text(recall.description)
                                .font(.subheadline)
                            Link("View Recall →", destination: URL(string: recall.url)!)
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 8)
                    }
                }
                
                if !product.hygieneWarnings.isEmpty {
                    Text("🧼 Hygiene Warnings")
                        .font(.headline)

                    ForEach(product.hygieneWarnings) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(warning.message)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                if !sources.isEmpty {
                    Text("🔗 Trusted Sources")
                        .font(.headline)

                    ForEach(sources, id: \.self) { source in
                        Text("• \(source)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .onAppear {
                RecallService.fetchRecalls(for: product.name) { found in
                    recalls = found
                }
            }
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
        productType: "food",
        safetyScore: 9,
        safetyLevel: "safe",
        pros: [
            SafetyPoint(id: "1", label: "High in nutrients", severity: "low", category: "nutrition")
        ],
        cons: [
            SafetyPoint(id: "2", label: "Requires washing", severity: "medium", category: "biological")
        ],
        certifications: ["USDA Organic"], hygieneWarnings: [
            HygieneWarning(type: "washing", message: "Wash before consumption to remove pesticides.")
        ]
    )

    ResultView(product: sample, scanLabels: ["scanLAbel1", "scanLabel2"])
        
}
