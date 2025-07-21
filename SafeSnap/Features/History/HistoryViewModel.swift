//
//  HistoryViewModel.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//


import Foundation

@MainActor
class HistoryViewModel: ObservableObject {
    @Published private(set) var records: [ScanHistoryItem] = []

    private let fileURL: URL = {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("scan_history.json")
    }()

    init() {
        load()
    }

    /// Add & persist a new record
    func add(_ item: ScanHistoryItem) {
        records.insert(item, at: 0)         // newest first
        save()
    }

    /// Delete at offsets & persist
    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    /// Load from disk (or start empty)
    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ScanHistoryItem].self, from: data)
        else {
            records = []
            return
        }
        records = decoded
    }

    /// Save current records to disk
    private func save() {
        DispatchQueue.global(qos: .background).async {
            guard let data = try? JSONEncoder().encode(self.records) else { return }
            try? data.write(to: self.fileURL, options: .atomic)
        }
    }
}