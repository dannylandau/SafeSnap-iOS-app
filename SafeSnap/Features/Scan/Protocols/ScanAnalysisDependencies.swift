//
//  ScanAnalysisDependencies.swift
//  SafeSnap
//
//  Protocols and types for scan analysis dependencies
//

import Foundation
import UIKit

// MARK: - Persisted Image

/// Stores metadata for a persisted scan image
struct PersistedScanImage: Equatable {
    enum Format: Equatable { case jpg, png }
    let imageURL: URL
    let thumbnailURL: URL
    let pixelSize: CGSize
    let format: Format
}

// MARK: - Protocols

@MainActor
protocol ScanHistoryRecording: AnyObject {
    func add(_ item: ScanHistoryItem)
}

protocol ScanImageStoring {
    func persist(image: UIImage, data: Data?) async throws -> PersistedScanImage
}
