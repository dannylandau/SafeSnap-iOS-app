//
//  ResultView.swift
//  SafeSnap
//

import SwiftUI
import UIKit

struct ResultView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: SharePayload?
    @State private var headerHeight: CGFloat = 0
    @State private var isZoomPresented: Bool = false
    @State private var zoomImage: UIImage? = nil

    struct SharePayload: Identifiable { let id = UUID(); let items: [Any] }

    @ObservedObject var vm: RecognitionResultViewModel

    // Measures the overlay header height so we can offset the scroll content
    private struct HeaderHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }


    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { content }
                .coordinateSpace(name: "scroll")
                .onChange(of: vm.selectedSection) { _ in
                    withAnimation(.easeInOut) {
                        switch vm.selectedSection {
                        case .children: proxy.scrollTo("childrenSection", anchor: .top)
                        case .dogs:     proxy.scrollTo("dogsSection", anchor: .top)
                        case .cats:     proxy.scrollTo("catsSection", anchor: .top)
                        }
                    }
                }
        }
        .onPreferenceChange(HeaderHeightKey.self) { h in
            headerHeight = h
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
        .fullScreenCover(isPresented: $isZoomPresented) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let img = zoomImage {
                    ZoomableImageView(image: img)
                        .ignoresSafeArea()
                }
                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isZoomPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(radius: 4)
                        }
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: — Content
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 24) {
            shareButton()
            imageCard()
            headerBar()
            scoresRow()
            kidSafetySection()
                .id("childrenSection")
            if vm.includeCats || vm.includeDogs {
                petSafetySection()
            }
            dataSourcesSection()
            timestampFooter()
        }
        .padding(.top, 8)
    }
    
    private func shareButton() -> some View {
        HStack {
            Spacer()
            Button { prepareShare() } label: {
                Text("Share").font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.trailing)
            .accessibilityLabel("Share")
        }
    }

    // Resolves a stored file URL into the **current** app container if needed
    private func resolveInCurrentContainer(_ url: URL?) -> URL? {
        guard let url = url else { return nil }
        if FileManager.default.fileExists(atPath: url.path) { return url }
        // Container likely changed after reinstall; rebuild path using Documents/Images + filename
        let filename = url.lastPathComponent
        guard let docs = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return url }
        let imagesDir = docs.appendingPathComponent("Images", isDirectory: true)
        let candidate = imagesDir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : url
    }

    // MARK: — Image Loading Helpers
    private func thumbnailURL(for url: URL?) -> URL? {
        guard let base = resolveInCurrentContainer(url) else { return nil }
        let dir = base.deletingLastPathComponent()
        let stem = base.deletingPathExtension().lastPathComponent
        let thumbName = stem + "_thumb.jpg"
        return dir.appendingPathComponent(thumbName)
    }

    private func loadImage(from url: URL?) -> UIImage? {
        guard let url = resolveInCurrentContainer(url) else { return nil }
        if let img = UIImage(contentsOfFile: url.path) { return img }
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }

    private var resolvedImage: UIImage? {
        if let ui = vm.image { return ui }
        let thumbURL = thumbnailURL(for: vm.imageRef)
        if let img = loadImage(from: thumbURL) { return img }
        return loadImage(from: vm.imageRef)
    }

    // MARK: — Image Card
    private func imageCard() -> some View {
        Group {
            if let ui = resolvedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(width: 200, height: 200)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(radius: 4)
                    Button {
                        self.zoomImage = ui
                        self.isZoomPresented = true
                    } label: {
                        Image(systemName: "eye.fill")
                            .padding(8)
                            .background(.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding(6)
                }
            } else {
                // Lightweight placeholder to keep layout stable
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }

    // MARK: — Score Ring
    private struct ScoreRing: View {
        enum LabelPlacement { case below, beside }
        let title: String
        let score10: Int  // 0–10
        let labelPlacement: LabelPlacement
        let onTap: (() -> Void)?
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
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
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

    // MARK: — Selected Color Helpers
    private func selectedScore10() -> Int {
        let a = vm.analysis
        switch vm.selectedSection {
        case .children: return score10(fromHundred: a.childSafetyScore)
        case .dogs:     return score10(fromHundred: a.dogSafetyScore ?? 0)
        case .cats:     return score10(fromHundred: a.catSafetyScore ?? 0)
        }
    }
    private var selectedColor: Color { scoreColor(selectedScore10()) }

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
                gradient: Gradient(colors: [selectedColor.opacity(0.85), selectedColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .animation(.easeInOut(duration: 0.25), value: vm.selectedSection)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: — Scores Row (Kids / Dogs / Cats)
    private func scoresRow() -> some View {
        let a = vm.analysis
        let child10 = score10(fromHundred: a.childSafetyScore)
        let dog10: Int? = a.dogSafetyScore.map { score10(fromHundred: $0) }
        let cat10: Int? = a.catSafetyScore.map { score10(fromHundred: $0) }

        let showDog = vm.includeDogs
        let showCat = vm.includeCats
        let hasMultiple = showDog || showCat

        typealias SectionType = RecognitionResultViewModel.FocusSection
        var items: [(String, Int, ScoreRing.LabelPlacement, SectionType)] = [("Kids", child10, .below, .children)]
        if showDog { items.append(("Dogs", dog10 ?? 0, .below, .dogs)) }
        if showCat { items.append(("Cats", cat10 ?? 0, .below, .cats)) }
        if items.count == 2 { items = items.map { ($0.0, $0.1, .beside, $0.3) } }

        return VStack(spacing: 20) {
            if vm.includeDogs || vm.includeCats {
                Text("Tip: tap a score ring to focus and jump to that section")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ScoreRing(title: item.0, score10: item.1, labelPlacement: item.2,
                              onTap: hasMultiple ? { vm.selectedSection = item.3 } : nil)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }

    // MARK: — Pet Safety
    private func petSafetySection() -> some View {
        VStack(spacing: 8) {
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                if vm.includeDogs {
                    petColumn(title: "Dogs", warnings: vm.dogWarnings)
                        .id("dogsSection")
                }
                if vm.includeCats {
                    petColumn(title: "Cats", warnings: vm.catWarnings)
                        .id("catsSection")
                }
            }
            .padding([.horizontal, .bottom])
        }
        .padding(.horizontal)
    }

    /// Renders a list of pet warnings with a severity badge.
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
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        let selected10 = score10(fromHundred: vm.overallScoreHundred)
        let focusLabel: String = {
            switch vm.selectedSection {
            case .children: return "Kids"
            case .dogs:     return "Dogs"
            case .cats:     return "Cats"
            }
        }()
        let summary = "SafeSnap — \(vm.productName) (\(vm.category)) — Safety: \(selected10)/10 (\(focusLabel))"
        items.append(summary)

        if let ui = vm.image { items.append(ui) }
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
            score: score10(fromHundred: vm.overallScoreHundred),
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

// MARK: - ZoomableImageView (UIScrollView-backed)
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        
        // Pin imageView to scrollView's bounds
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // no-op
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}
