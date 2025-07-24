//
//  ScanHistoryService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


//
//  ScanHistoryService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import Foundation
import SwiftUI

@MainActor
class ScanHistoryService: ObservableObject {
    // MARK: - Properties

    @Published private(set) var records: [ScanHistoryItem] = []

    private let fileURL: URL

    // MARK: - Init

    init(fileURL: URL? = nil) {
        if let customURL = fileURL {
            self.fileURL = customURL
        } else {
            let fm = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.fileURL = docs.appendingPathComponent("scan_history.json")
        }
        load()
    }

    // MARK: - Public API

    func add(_ item: ScanHistoryItem) {
        records.insert(item, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    func clearAll() {
        records.removeAll()
        save()
    }

    // MARK: - Private Persistence

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([ScanHistoryItem].self, from: data)
        } catch {
            print("⚠️ Failed to load scan history: \(error.localizedDescription)")
            records = []
        }
    }

    private func save() {
        let fileURL = self.fileURL
        DispatchQueue.global(qos: .background).async { [records] in
            do {
                let data = try JSONEncoder().encode(records)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                print("⚠️ Failed to save scan history: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    /// Saves the scan history synchronously on a background thread. Only for testing purposes.
    func saveSynchronously() async {
        let records = self.records
        let fileURL = self.fileURL

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let data = try JSONEncoder().encode(records)
                    try data.write(to: fileURL, options: [.atomic])
                } catch {
                    print("❌ Failed to save synchronously: \(error)")
                }
                continuation.resume()
            }
        }
    }
}
