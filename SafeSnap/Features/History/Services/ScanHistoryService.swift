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
    @Published private(set) var isSyncing: Bool = false

    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "scan.history.save.queue")
    private let apiService: SafeSnapAPIService
    private weak var userSession: UserSession?

    // MARK: - Init

    init(
        fileURL: URL? = nil,
        apiService: SafeSnapAPIService = .shared,
        userSession: UserSession? = nil
    ) {
        if let customURL = fileURL {
            self.fileURL = customURL
        } else {
            let fm = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.fileURL = docs.appendingPathComponent("scan_history.json")
        }
        self.apiService = apiService
        self.userSession = userSession
        load()
    }

    // MARK: - Public API

    func add(_ item: ScanHistoryItem) {
        records.insert(item, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        let idsToDelete = offsets.map { records[$0].id.uuidString }
        records.remove(atOffsets: offsets)
        save()
        
        // Delete from backend if signed in (background)
        if userSession?.isSignedIn == true {
            Task {
                for id in idsToDelete {
                    try? await apiService.deleteFromHistory(id: id)
                }
            }
        }
    }
    
    func delete(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records.remove(at: index)
        save()
        
        // Delete from backend if signed in (background)
        if userSession?.isSignedIn == true {
            Task {
                try? await apiService.deleteFromHistory(id: id.uuidString)
            }
        }
    }

    func clearAll() {
        let idsToDelete = records.map { $0.id.uuidString }
        records.removeAll()
        save()
        
        // Delete all from backend if signed in (background)
        if userSession?.isSignedIn == true {
            Task {
                for id in idsToDelete {
                    try? await apiService.deleteFromHistory(id: id)
                }
            }
        }
    }
    
    // MARK: - Backend Sync
    
    /// Sync history with backend (fetch remote history and merge with local)
    func syncWithBackend() async {
        guard userSession?.isSignedIn == true else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let remoteItems = try await apiService.getHistory()
            await mergeRemoteHistory(remoteItems)
        } catch {
            #if DEBUG
            print("⚠️ Failed to sync history: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Merge remote history items with local records
    private func mergeRemoteHistory(_ remoteItems: [SafeSnapAPIService.APIHistoryItem]) async {
        // Create a set of existing local IDs
        let localIds = Set(records.map { $0.id.uuidString })
        
        // Add remote items that don't exist locally
        for remoteItem in remoteItems {
            if !localIds.contains(remoteItem.id) {
                if let localItem = convertToLocalItem(remoteItem) {
                    records.append(localItem)
                }
            }
        }
        
        // Sort by date (newest first)
        records.sort { $0.createdAt > $1.createdAt }
        save()
    }
    
    /// Convert API history item to local ScanHistoryItem
    private func convertToLocalItem(_ apiItem: SafeSnapAPIService.APIHistoryItem) -> ScanHistoryItem? {
        guard let fullAnalysis = apiItem.fullAnalysis else { return nil }
        
        // Convert fullAnalysis to SafetyAnalysisResponse
        let kidSafety = fullAnalysis.analysis.kidSafety
        let petSafety = fullAnalysis.analysis.petSafety
        
        let safetyResponse = SafetyAnalysisResponse(
            productName: fullAnalysis.name,
            productType: fullAnalysis.category,
            overallSafetyScore: fullAnalysis.safetyScore.overall,
            childSafetyScore: kidSafety.score ?? fullAnalysis.safetyScore.overall,
            dogSafetyScore: petSafety.dogs?.score,
            catSafetyScore: petSafety.cats?.score,
            modelConfidence: fullAnalysis.analysisMetadata?.modelConfidence ?? 0.85,
            recognitionConfidence: fullAnalysis.analysisMetadata?.recognitionConfidence ?? 0.90,
            generalSafety: SafetyAnalysisResponse.GeneralSafety(pros: [], cons: []),
            petSafety: SafetyAnalysisResponse.PetSafety(dogs: [], cats: []),
            hygieneWarnings: [],
            recalls: [],
            kidPros: kidSafety.benefits,
            kidCons: kidSafety.concerns,
            kidNarrative: kidSafety.narrative ?? ""
        )
        
        let options = apiItem.petSafetyOptions ?? PetSafetyOptions()
        
        return ScanHistoryItem(
            id: UUID(uuidString: apiItem.id) ?? UUID(),
            createdAt: ISO8601DateFormatter().date(from: apiItem.createdAt) ?? Date(),
            schemaVersion: 2,
            imageFilename: nil,  // Remote items don't have local files
            imageHash: apiItem.id,  // Use ID as hash for remote items
            userToggles: ScanHistoryItem.UserToggles(
                includeDogs: options.includeDogs,
                includeCats: options.includeCats,
                includeChildren: options.includeChildren
            ),
            productName: apiItem.name,
            productType: fullAnalysis.category,
            categoryName: apiItem.category ?? fullAnalysis.category,
            brand: nil,
            confidence: fullAnalysis.analysisMetadata?.recognitionConfidence ?? 0.85,
            visionContextRef: nil,
            visionBestGuess: apiItem.name,
            visionWebEntities: [],
            analysis: safetyResponse,
            model: "safesnap-backend",
            promptVersion: "v1-api",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }

    // MARK: - Local Persistence

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
