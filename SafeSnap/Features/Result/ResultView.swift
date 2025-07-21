//
//  ResultView.swift
//  SafeSnap
//

import SwiftUI
import UIKit

// MARK: — ViewModel
struct RecognitionResultViewModel {
    let image: UIImage?
    let productName, category: String
    let score: Int
    let safetyLabel: String
    let safeBenefits, safetyConcerns, dataSources: [String]
    let date: Date
}

struct ResultView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false
    let vm: RecognitionResultViewModel

    var body: some View {
        VStack(spacing: 0) {
            Button { showingShare = true } label: {
                Label("Share Results", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            ScrollView { content }
        }
        .sheet(isPresented: $showingShare) { shareSheet }
    }

    // MARK: — Nav Bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            
        }
        .padding()
    }

    // MARK: — Content
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 24) {
            imageCard()
            headerBar()
            safetyBadge()
            kidSafetySection()
            dataSourcesSection()
            timestampFooter()
        }
        .padding(.top, 16)
    }

    // MARK: — Image Card
    private func imageCard() -> some View {
        Group {
            if let ui = vm.image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(width: 200, height: 200)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    Button { /* zoom */ } label: {
                        Image(systemName: "eye.fill")
                            .padding(8)
                            .background(.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding(6)
                }
            }
        }
    }

    // MARK: — Header Bar
    private func headerBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.productName)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(vm.category)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(vm.score)/10")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Safety Score")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(LinearGradient(
            gradient: Gradient(colors: [.green.opacity(0.8), .green]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: — Safety Badge
    private func safetyBadge() -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text(vm.safetyLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.15))
        .foregroundColor(.green)
        .cornerRadius(12)
    }

    // MARK: — Kid Safety
    private func kidSafetySection() -> some View {
        VStack(spacing: 0) {
            kidSafetyHeader()
            kidSafetyList(title: "Kid-Safe Benefits", items: vm.safeBenefits, color: .green)
            kidSafetyList(title: "Kid Safety Concerns", items: vm.safetyConcerns, color: .red)
        }
        .padding(.horizontal)
    }

    private func kidSafetyHeader() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.3.fill")
                Text("Kid Safety").font(.headline)
            }
            Text("Safety analysis focused on children and family use")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    private func kidSafetyList(title: String, items: [String], color: Color) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(title) (\(items.count))")
                        .font(.headline).foregroundColor(color)
                    ForEach(items, id: \.self) { text in
                        Text(text)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(color.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: — Data Sources
    private func dataSourcesSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                Text("Data Sources").font(.headline)
            }
            
            ForEach(vm.dataSources, id: \.self) { source in
                Text(source)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: — Timestamp Footer
    private func timestampFooter() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
            Text("Analysis completed at " +
                 vm.date.formatted(.dateTime.hour().minute().second()))
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .padding(.top, 8)
    }

    // MARK: — Share Sheet
    private var shareSheet: some View {
        ShareSheet(activityItems: [
            "Check out my SafeSnap result for \(vm.productName)!"
        ])
    }
}

// MARK: — ShareSheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
          activityItems: activityItems,
          applicationActivities: nil
        )
    }
    func updateUIViewController(
      _ uiController: UIActivityViewController,
      context: Context
    ) {}
}

// MARK: — ResultView Previews
struct ResultView_Previews: PreviewProvider {
    /// A sample Product matching your model
    static var sampleProduct: Product {
        Product(
            id: UUID().uuidString,
            name: "Red Apple",
            productType: "Food",
            safetyScore: 9,
            safetyLevel: "Perfectly Safe",
            pros: [
                SafetyPoint(id: "1", label: "No allergens", severity: "low", category: "Regulatory")
            ],
            cons: [
                SafetyPoint(id: "2", label: "Wash before use", severity: "medium", category: "Hygiene")
            ],
            certifications: ["FDA Approved", "Consumer Product Safety Commission", "International Safety Standards"],
            hygieneWarnings: [
                HygieneWarning(type: "Wash", message: "Rinse under cold water before eating")
            ]
        )
    }

    static var previews: some View {
        // Build the RecognitionResultViewModel from that product
        let vm = RecognitionResultViewModel(
            image: UIImage(systemName: "applelogo"),
            productName: sampleProduct.name,
            category: sampleProduct.productType,
            score: sampleProduct.safetyScore,
            safetyLabel: sampleProduct.safetyLevel,
            safeBenefits: sampleProduct.pros.map(\.label),
            safetyConcerns: sampleProduct.cons.map(\.label),
            dataSources: sampleProduct.certifications,
            date: Date()
        )

        Group {
            ResultView(vm: vm)
                .previewDisplayName("Light Mode")
            ResultView(vm: vm)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
