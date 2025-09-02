//
//  ResultView.swift
//  SafeSnap
//

import SwiftUI
import UIKit

struct ResultView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: SharePayload?
    struct SharePayload: Identifiable { let id = UUID(); let items: [Any] }
    let vm: RecognitionResultViewModel

    var body: some View {
        ScrollView { content }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(activityItems: payload.items)
            }
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
            shareButton()
            imageCard()
            headerBar()
            scoresRow()
//            safetyBadge()
            kidSafetySection()
            if vm.includeCats || vm.includeDogs {
                petSafetySection()
            }
            dataSourcesSection()
            timestampFooter()
        }
        .padding(.top, 16)
    }
    
    private func shareButton() -> some View {
        HStack {
            Spacer()
            Button { prepareShare() } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .padding()
        }
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

    // MARK: — Score Ring
    private struct ScoreRing: View {
        enum LabelPlacement { case below, beside }
        let title: String
        let score10: Int  // 0–10
        let labelPlacement: LabelPlacement
        private var progress: Double { min(1.0, max(0.0, Double(score10) / 10.0)) }

        var body: some View {
            Group {
                switch labelPlacement {
                case .below:
                    VStack(spacing: 6) {
                        ring
                        Text("Safety Score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(title)
                            .font(.footnote).bold()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("\(title) safety score \(score10) out of 10"))

                case .beside:
                    HStack(spacing: 10) {
                        ring
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Safety Score")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(title)
                                .font(.footnote).bold()
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("\(title) safety score \(score10) out of 10"))
                }
            }
        }

        private var ring: some View {
            ZStack {
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(scoreColor(score10), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)
                Text("\(score10)/10")
                    .font(.footnote).bold()
                    .monospacedDigit()
                    .foregroundColor(scoreColor(score10))
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
            // Scores moved to dedicated row below
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [scoreColor(score10(fromHundred: vm.analysis.childSafetyScore)).opacity(0.8),
                                             scoreColor(score10(fromHundred: vm.analysis.childSafetyScore))]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: — Scores Row (Kids / Dogs / Cats)
    private func scoresRow() -> some View {
        // Pull scores from the analysis (0–100) and convert to /10
        let analysis = vm.analysis
        let child10 = score10(fromHundred: analysis.childSafetyScore)
        let dog10: Int? = analysis.dogSafetyScore.map { score10(fromHundred: $0) }
        let cat10: Int? = analysis.catSafetyScore.map { score10(fromHundred: $0) }

        // Show dog/cat rings if present in analysis OR toggled by the user
        let showDog = vm.includeDogs
        let showCat = vm.includeCats

        // Build items tuple array (title, score)
        var items: [(String, Int, ScoreRing.LabelPlacement)] = [("Kids", child10, .below)]
        if showDog { items.append(("Dogs", dog10 ?? 0, .below)) }
        if showCat { items.append(("Cats", cat10 ?? 0, .below)) }

        // With 2 items, place labels beside rings for a tighter layout
        if items.count == 2 {
            items = items.map { ($0.0, $0.1, .beside) }
        }

        // Equal-width columns: each item takes the same horizontal space, centered.
        return HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                ScoreRing(title: item.0, score10: item.1, labelPlacement: item.2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

//    // MARK: — Safety Badge
//    private func safetyBadge() -> some View {
//        HStack {
//            Image(systemName: "checkmark.circle.fill")
//            Text(vm.safetyLabel)
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 8)
//        .background(Color.green.opacity(0.15))
//        .foregroundColor(.green)
//        .cornerRadius(12)
//    }

    // MARK: — Pet Safety
    private func petSafetySection() -> some View {
        VStack(spacing: 8) {
            // Header
            VStack(alignment: .center, spacing: 4) {
                HStack {
                    Image(systemName: "pawprint.fill")
                    Text("Pet Safety").font(.headline)
                }
                Text("Dog and/or cat specific warnings based on the analysis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)

            // Body
            VStack(alignment: .leading, spacing: 12) {
                // Dogs
                if vm.includeDogs {
                    petColumn(title: "Dogs", warnings: vm.dogWarnings)
                }
                // Cats
                if vm.includeCats {
                    petColumn(title: "Cats", warnings: vm.catWarnings)
                }
            }
            .padding([.horizontal, .bottom])
        }
        .padding(.horizontal)
    }

    /// Renders a list of pet warnings with a severity badge.
    /// Expects `vm.dogWarnings` / `vm.catWarnings` to be `[(severity: String, warning: String, reason: String)]`.
    @ViewBuilder
    private func petColumn(title: String, warnings: [(severity: String, warning: String, reason: String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: title == "Dogs" ? "dog.fill" : "cat.fill")
                Text(title).font(.headline)
                if let maxSeverity = warnings.map({ $0.severity.lowercased() }).max(by: severityLess) {
                    PetRiskBadge(severity: maxSeverity)
                }
                Spacer()
            }

            if warnings.isEmpty {
                Text("No specific warnings")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(severityColor(item.severity)).frame(width: 8, height: 8)
                            Text(item.warning).font(.subheadline).bold()
                        }
                        Text(item.reason).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(severityColor(item.severity).opacity(0.08))
                    .cornerRadius(8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private struct PetRiskBadge: View {
        let severity: String
        var body: some View {
            Text(severity.capitalized)
                .font(.caption).bold()
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(severityColor(severity).opacity(0.15))
                .foregroundStyle(severityColor(severity))
                .clipShape(Capsule())
        }
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

    // MARK: — Share helpers
    private func prepareShare() {
        var items: [Any] = []

        let child10 = score10(fromHundred: vm.analysis.childSafetyScore)
        let summary = "SafeSnap — \(vm.productName) (\(vm.category)) — Safety: \(child10)/10 (Kids)"
        items.append(summary)

        if let ui = vm.image { items.append(ui) }
        if let url = exportCurrentResultAsJSON() { items.append(url) }

        // Present only when we actually have something
        sharePayload = SharePayload(items: items)
    }

    private func exportCurrentResultAsJSON() -> URL? {
        struct Payload: Codable {
            let productName: String
            let category: String
            let score: Int
            let date: Date
            let analysis: SafetyAnalysisResponse
        }
        let payload = Payload(
            productName: vm.productName,
            category: vm.category,
            score: vm.score,
            date: vm.date,
            analysis: vm.analysis
        )
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(payload)
            let safeName = vm.productName.replacingOccurrences(of: "/", with: "-")
            return try writeTemp(data: data, filename: "SafeSnap-\(safeName)-\(vm.date.ISO8601Format()).json")
        } catch {
            print("Share export failed:", error)
            return nil
        }
    }

    private func writeTemp(data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
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

// MARK: - File-scoped helpers (usable by nested views)
fileprivate func severityLess(_ a: String, _ b: String) -> Bool {
    func rank(_ s: String) -> Int {
        switch s.lowercased() {
        case "low": return 0
        case "medium": return 1
        case "high": return 2
        default: return -1
        }
    }
    return rank(a) < rank(b)
}

fileprivate func severityColor(_ s: String) -> Color {
    switch s.lowercased() {
    case "high": return .red
    case "medium": return .orange
    default: return .green
    }
}

fileprivate func scoreColor(_ score10: Int) -> Color {
    // >7 green, <4 red, otherwise orange
    if score10 > 7 { return .green }
    if score10 < 4 { return .red }
    return .orange
}

fileprivate func score10(fromHundred value: Int) -> Int {
    // Convert 0–100 → 0–10 with rounding
    let clamped = max(0, min(100, value))
    return Int(round(Double(clamped) / 10.0))
}

// TODO: Fix the preview once the Product model is defined
//// MARK: — ResultView Previews
//struct ResultView_Previews: PreviewProvider {
//    /// A sample Product matching your model
//    static var sampleProduct: Product {
//        Product(
//            id: UUID().uuidString,
//            name: "Red Apple",
//            productType: "Food",
//            safetyScore: 9,
//            safetyLevel: "Perfectly Safe",
//            pros: [
//                SafetyPoint(id: "1", label: "No allergens", severity: "low", category: "Regulatory")
//            ],
//            cons: [
//                SafetyPoint(id: "2", label: "Wash before use", severity: "medium", category: "Hygiene")
//            ],
//            certifications: ["FDA Approved", "Consumer Product Safety Commission", "International Safety Standards"],
//            hygieneWarnings: [
//                HygieneWarning(type: "Wash", message: "Rinse under cold water before eating")
//            ]
//        )
//    }
//
//    static var previews: some View {
//        // Build the RecognitionResultViewModel from that product
//        let vm = RecognitionResultViewModel(
//            image: UIImage(systemName: "applelogo"),
//            productName: sampleProduct.name,
//            category: sampleProduct.productType,
//            score: sampleProduct.safetyScore,
//            safetyLabel: sampleProduct.safetyLevel,
//            safeBenefits: sampleProduct.pros.map(\.label),
//            safetyConcerns: sampleProduct.cons.map(\.label),
//            dataSources: sampleProduct.certifications,
//            date: Date()
//        )
//
//        Group {
//            ResultView(vm: vm)
//                .previewDisplayName("Light Mode")
//            ResultView(vm: vm)
//                .preferredColorScheme(.dark)
//                .previewDisplayName("Dark Mode")
//        }
//    }
//}
