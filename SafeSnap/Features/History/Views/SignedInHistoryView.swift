//
//  SignedInHistoryView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI
import UIKit

struct SignedInHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: HistoryViewModel
    @State private var searchText = ""
    @State private var isSearching = false

    private var filteredRecords: [ScanHistoryItem] {
        vm.records
            .filter {
                searchText.isEmpty ||
                $0.productName.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
       
            VStack {
                headerCard
                
                ScrollView(showsIndicators: false) {
                    historyListCard
                }
            }
    }

    private var headerCard: some View {
        VStack {
            HStack {
                Spacer()
                
                Text("History")
                    .font(.headline.bold())
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSearching.toggle()
                        if !isSearching { searchText = "" }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
            }

            

            if isSearching {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 48)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search products…", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
    }

    private var historyListCard: some View {
        VStack(spacing: 16) {
            ForEach(filteredRecords) { item in
                NavigationLink {
                    let uiImage = loadHistoryImage(from: item.imageRef)
                    let vm = RecognitionResultViewModel(image: uiImage, from: item)
                    ResultView(vm: vm)
                } label: {
                    HistoryListRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 20)
        )
    }

    private func loadHistoryImage(from url: URL?) -> UIImage? {
        guard let url else { return nil }
        if let img = UIImage(contentsOfFile: url.path) { return img }
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }
}

private struct HistoryListRow: View {
    let item: ScanHistoryItem

    var body: some View {
        HStack(spacing: 16) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                Text(item.createdAt.formatted(.dateTime.day().month().year()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.productName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(formattedScore)/10 Safety Score")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(scoreColor)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 0)
        )
    }

    private var formattedScore: String {
        let normalized = max(0, min(100, item.analysis.childSafetyScore))
        return String(format: "%.0f", Double(normalized))
    }

    private var scoreColor: Color {
        switch item.analysis.childSafetyScore {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.imageRef,
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 100, height: 130)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(.secondary)
                )
        }
    }
}

#if DEBUG
struct SignedInHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = HistoryViewModel(service: ScanHistoryService())
        SignedInHistoryView()
            .environmentObject(vm)
    }
}
#endif
