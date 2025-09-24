//
//  ScanAnalysisDependencies.swift
//  SafeSnap
//
//  Created by ChatGPT on 14/03/2026.
//

import Foundation
import UIKit

/// Stores metadata for a persisted scan image so collaborators can avoid touching the file system in tests.
struct PersistedScanImage: Equatable {
    enum Format: Equatable { case jpg, png }
    let imageURL: URL
    let thumbnailURL: URL
    let pixelSize: CGSize
    let format: Format
}

protocol SafetyAnalyzing {
    func analyzeSafetyWithExtras(
        image: UIImage,
        options: SafetyOptions,
        streamToken: @escaping (String) -> Void,
        visionLabels: [String],
        ocrHits: [String]
    ) async throws -> AnalyzedSafety
    func cancelAnalysis()
}

@MainActor
protocol ScanHistoryRecording: AnyObject {
    func add(_ item: ScanHistoryItem)
}

protocol ScanImageStoring {
    func persist(image: UIImage, data: Data?) async throws -> PersistedScanImage
}
