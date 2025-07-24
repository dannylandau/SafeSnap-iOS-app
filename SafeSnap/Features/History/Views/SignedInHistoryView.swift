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
    @State private var showingShare = false

    enum SortOption: String, CaseIterable {
        case recent = "Recent", safety = "Safety", name = "Name"
    }

    private let allCategories: [(emoji: String, label: String)] = [
        ("📦","All"), ("🍎","Food"), ("🧸","Toys"),
        ("💄","Beauty"), ("💻","Tech"), ("🟡","Home")
    ]

    private var filteredRecords: [ScanHistoryItem] {
        vm.records
            .filter { categoryFilter == "All" || $0.product.productType == categoryFilter }
            .filter { searchText.isEmpty ||
                       $0.product.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { a, b in
                switch sortBy {
                case .recent:  return a.date > b.date
                case .safety:  return a.score > b.score
                case .name:    return a.product.name < b.product.name
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
        .sheet(isPresented: $showingShare) { shareSheet }
    }
    
    // MARK: — Share Sheet
    private var shareSheet: some View {
        ShareSheet(activityItems: [
            "Check out my SafeSnap history for SafeSnap!"
        ])
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
            Button { showingShare = true } label: {
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(allCategories, id: \.label) { emoji, label in
                        let isSel = label == categoryFilter
                        Text("\(emoji) \(label)")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSel
                                        ? Color.green
                                        : Color.secondary.opacity(0.1))
                            .foregroundColor(isSel ? .white : .primary)
                            .cornerRadius(8)
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
                     value: String(format: "%.1f", vm.records.map(\.score).average()))
            statCard(title: "Safe Items",
                     value: "\(vm.records.filter { $0.score >= 7 }.count * 100 / max(1, vm.records.count))%")
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
                    NavigationLink(value: item) {
                        recordRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical)
        }
        .navigationDestination(for: ScanHistoryItem.self) { item in
            // build a ResultViewVM from the item
            let vm = RecognitionResultViewModel(
                image: item.thumbnail,
                productName: item.product.name,
                category: item.product.productType,
                score: item.score,
                safetyLabel: item.product.safetyLevel,
                safeBenefits: item.product.pros.map(\.label),
                safetyConcerns: item.product.cons.map(\.label),
                dataSources: item.product.certifications,
                date: item.date
            )
            ResultView(vm: vm)
        }
    }

    private func recordRow(item: ScanHistoryItem) -> some View {
        HStack(spacing: 12) {
            if let thumb = item.thumbnail {
                Image(uiImage: thumb)
                    .resizable().scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name).font(.headline)
                Text(item.date, format: .dateTime.day().month().year())
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(Int(item.score))/10")
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
