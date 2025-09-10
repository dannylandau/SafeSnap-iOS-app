//
//  HistoryView.swift
//  SafeSnap
//
//  Created by [You] on [Date].
//

import SwiftUI

struct SignedInHistoryView: View {
    @EnvironmentObject private var vm: HistoryViewModel
    @State private var searchText = ""
    @State private var sortBy: SortOption = .recent
    @State private var categoryFilter: String = "All"
    @State private var showFilters = false
    @State private var sharePayload: SharePayload?

    struct SharePayload: Identifiable { let id = UUID(); let items: [Any] }

    enum SortOption: String, CaseIterable {
        case recent = "Recent", safety = "Safety", name = "Name"
    }

    private let allCategories: [(emoji: String, label: String)] = [
        ("📦","All"),
        ("🍎","Food"),
        ("💄","Cosmetic"),
        ("🧸","Toy"),
        ("💻","Electronic"),
        ("🏠","Household"),
        ("👕","Clothing"),
        ("🐶","Animal"),
        ("💍","Jewelry"),
        ("💊","Pharmaceutical"),
        ("🚗","Automotive"),
        ("❓","Other")
    ]

    private var filteredRecords: [ScanHistoryItem] {
        vm.records
            .filter { categoryFilter == "All" || $0.categoryName == categoryFilter }
            .filter { searchText.isEmpty ||
                       $0.productName.localizedCaseInsensitiveContains(searchText) }
            .sorted { a, b in
                switch sortBy {
                case .recent:  return a.createdAt > b.createdAt
                case .safety:  return a.analysis.overallSafetyScore > b.analysis.overallSafetyScore
                case .name:    return a.productName < b.productName
                }
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                headerSection
                searchBar
                if showFilters { filterSection }
                statsCards
                recordsList
            }
            .padding(.horizontal)
            .padding(.top)
            .animation(.easeInOut, value: showFilters)
            .navigationBarHidden(true)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("History").font(.largeTitle.bold())
                Text("\(vm.records.count) scans")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { showFilters.toggle() } label: {
                Image(systemName: showFilters
                      ? "xmark.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.title2).foregroundColor(.green)
            }
            .buttonStyle(.plain)
            Button {
                guard let url = exportAllAsJSON() else { return }
                let title = "Shared from SafeSnap — \(filteredRecords.count) scans"
                sharePayload = SharePayload(items: [title, url])
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
    }

    private var searchBar: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 44)
            .overlay(
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search products…", text: $searchText)
                        .autocapitalization(.none)
                }
                .padding(.horizontal, 12)
                .foregroundColor(.secondary)
            )
    }

    private var filterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filters").font(.headline)
                Spacer()
                Button("Clear All") {
                    sortBy = .recent
                    categoryFilter = "All"
                }
                .foregroundColor(.green)
            }

            // Sort by
            VStack(alignment: .leading, spacing: 8) {
                Text("Sort by").font(.subheadline)
                HStack(spacing: 8) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(sortBy == option
                                        ? Color.green
                                        : Color.secondary.opacity(0.1))
                            .foregroundColor(sortBy == option ? .white : .primary)
                            .cornerRadius(8)
                            .onTapGesture { sortBy = option }
                    }
                }
            }

            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category").font(.subheadline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 220), spacing: 12)], spacing: 12) {
                    ForEach(allCategories, id: \.label) { emoji, label in
                        let isSel = label == categoryFilter
                        Text("\(emoji) \(label)")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSel
                                        ? Color.green
                                        : Color.secondary.opacity(0.1))
                            .foregroundColor(isSel ? .white : .primary)
                            .cornerRadius(10)
                            .onTapGesture { categoryFilter = label }
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private var statsCards: some View {
        HStack(spacing: 12) {
            statCard(title: "Total Scans", value: "\(vm.records.count)")
            statCard(title: "Avg Score",
                     value: String(format: "%.1f", vm.records.map(\.analysis.overallSafetyScore).average()/10))
            statCard(title: "Safe Items",
                     value: "\(vm.records.filter { $0.analysis.overallSafetyScore >= 70 }.count * 100 / max(1, vm.records.count))%")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack {
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private var recordsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(filteredRecords) { item in
                    NavigationLink {
                        // Load image if available
                        let uiImage = loadHistoryImage(from: item.imageRef)
                        let vm = RecognitionResultViewModel(image: uiImage, from: item)
                        ResultView(vm: vm)
                    } label: {
                        recordRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            if let url = exportItemAsJSON(item) {
                                let title = "Shared from SafeSnap — 1 scan"
                                sharePayload = SharePayload(items: [title, url])
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .tint(.green)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private func thumbnailURL(for url: URL?) -> URL? {
        guard let url = url else { return nil }
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let thumbName = stem + "_thumb.jpg"
        return dir.appendingPathComponent(thumbName)
    }
    
    private func loadImage(from url: URL?) -> UIImage? {
        guard let url = url else { return nil }
        if let img = UIImage(contentsOfFile: url.path) { return img }
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }

    private func loadHistoryImage(from url: URL?) -> UIImage? {
        guard let url else { return nil }
        if let img = UIImage(contentsOfFile: url.path) { return img }
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }

    private func recordRow(item: ScanHistoryItem) -> some View {
        HStack(spacing: 12) {
            let thumbURL = thumbnailURL(for: item.imageRef)
            if let url = thumbURL, let img = loadImage(from: url) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    .clipped()
            } else if let fullURL = item.imageRef, let img = loadImage(from: fullURL) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName).font(.headline)
                Text(item.createdAt, format: .dateTime.day().month().year())
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(Int(Double(item.analysis.overallSafetyScore)/10))/10")
                .font(.subheadline.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .foregroundColor(.green)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: — Array Average

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

// MARK: — Export helpers
private extension SignedInHistoryView {
    func exportAllAsJSON() -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(filteredRecords)
            let url = try writeTemp(data: data, filename: "SafeSnap-History-\(Date().ISO8601Format()).json")
            return url
        } catch {
            print("Export all failed:", error)
            return nil
        }
    }

    func exportItemAsJSON(_ item: ScanHistoryItem) -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(item)
            let safeName = item.productName.replacingOccurrences(of: "/", with: "-")
            let url = try writeTemp(data: data, filename: "SafeSnap-\(safeName)-\(item.createdAt.ISO8601Format()).json")
            return url
        } catch {
            print("Export item failed:", error)
            return nil
        }
    }

    func writeTemp(data: Data, filename: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: — Preview

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = HistoryViewModel(service: ScanHistoryService())
//        let product = Product(
//            id: UUID().uuidString,
//            name: "Red Apple",
//            productType: "Food",
//            safetyScore: 9,
//            safetyLevel: "Perfectly Safe",
//            pros: [ SafetyPoint(id: "1", label: "No allergens", severity: "low", category: "Regulatory") ],
//            cons: [ SafetyPoint(id: "2", label: "Wash before use", severity: "medium", category: "Hygiene") ],
//            certifications: ["FDA Approved"],
//            hygieneWarnings: [ HygieneWarning(type: "Wash", message: "Rinse under cold water") ]
//        )
//        let item = ScanHistoryItem(
//            product: product,
//            labels: ["apple","fruit"],
//            score: product.safetyScore,
//            thumbnail: UIImage(systemName: "applelogo")
//        )
//        vm.add(item)

        return Group {
            SignedInHistoryView()
                .environmentObject(vm)
                .previewDisplayName("Light Mode")
            SignedInHistoryView()
                .environmentObject(vm)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
