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
    private let saveQueue = DispatchQueue(label: "scan.history.save.queue")

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

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            do {
                records = try JSONDecoder().decode([ScanHistoryItem].self, from: data)
            } catch {
                // Backup corrupt data
                let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("scan_history_backup.json")
                try? data.write(to: backupURL)
                print("⚠️ Failed to decode scan history, data backed up: \(error.localizedDescription)")
                records = []
                return
            }
        } catch {
            print("⚠️ Failed to load scan history: \(error.localizedDescription)")
            records = []
        }
    }

    private func save() {
        let fileURL = self.fileURL
        let records = self.records
        saveQueue.async {
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
    
    // MARK: - Thumbnail Persistence
    private func thumbnailPath(for id: UUID) -> URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("thumbnails/\(id).jpg")
    }

    private func saveThumbnail(_ image: UIImage, for id: UUID) {
        let path = thumbnailPath(for: id)
        try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? image.jpegData(compressionQuality: 0.5)?.write(to: path)
    }

    private func loadThumbnail(for id: UUID) -> UIImage? {
        let path = thumbnailPath(for: id)
        if let data = try? Data(contentsOf: path) {
            return UIImage(data: data)
        }
        return nil
    }
}

extension ScanHistoryService: ScanHistoryRecording {}
