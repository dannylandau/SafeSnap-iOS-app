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

struct VisionContextPayload {
    let guessName: String
    let guessType: String
    let confidence: Double
    let brandCandidates: [String]
    let labels: [String]
    let objects: [String]
    let detectedText: String?
    let sanitizedContext: String?
    let bestGuess: String?
    let webEntities: [String]

    init(
        guessName: String,
        guessType: String,
        confidence: Double,
        brandCandidates: [String],
        labels: [String],
        objects: [String],
        detectedText: String?,
        sanitizedContext: String?,
        bestGuess: String?,
        webEntities: [String]
    ) {
        self.guessName = guessName
        self.guessType = guessType
        self.confidence = confidence
        self.brandCandidates = brandCandidates
        self.labels = labels
        self.objects = objects
        self.detectedText = detectedText
        self.sanitizedContext = sanitizedContext
        self.bestGuess = bestGuess
        self.webEntities = webEntities
    }
}

protocol SafetyAnalyzing {
    func analyzeSafetyWithExtras(
        image: UIImage,
        options: SafetyOptions,
        streamToken: @escaping (String) -> Void,
        visionLabels: [String],
        ocrHits: [String],
        visionContext: VisionContextPayload?
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
