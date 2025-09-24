//
//  ScanAnalysisCoordinator.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import Foundation
import SwiftUI
import CoreGraphics
import UIKit

private actor FileScanImageStore: ScanImageStoring {
    private enum ImageFormat: String { case jpg, png }
    private let fm = FileManager.default

    func persist(image: UIImage, data: Data?) async throws -> PersistedScanImage {
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let imagesDir = docs.appendingPathComponent("Images", isDirectory: true)
        if !fm.fileExists(atPath: imagesDir.path) {
            try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }

        let id = UUID().uuidString
        var format: ImageFormat = .jpg
        if let d = data, d.count >= 4 {
            let hdr = [UInt8](d.prefix(4))
            if hdr[0] == 0x89 && hdr[1] == 0x50 && hdr[2] == 0x4E && hdr[3] == 0x47 { format = .png }
            else if hdr[0] == 0xFF && hdr[1] == 0xD8 && hdr[2] == 0xFF { format = .jpg }
        }

        let fullURL: URL
        if let d = data, !d.isEmpty {
            fullURL = imagesDir.appendingPathComponent("IMG_\(id).\(format.rawValue)")
            try d.write(to: fullURL, options: .atomic)
        } else {
            let jpgURL = imagesDir.appendingPathComponent("IMG_\(id).jpg")
            guard let jpg = image.jpegData(compressionQuality: 0.9) else {
                throw NSError(domain: "SafeSnap", code: -11, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image to JPEG"])
            }
            try jpg.write(to: jpgURL, options: .atomic)
            format = .jpg
            fullURL = jpgURL
        }

        guard UIImage(contentsOfFile: fullURL.path) != nil else {
            throw NSError(domain: "SafeSnap", code: -12, userInfo: [NSLocalizedDescriptionKey: "Written image is unreadable at \(fullURL.lastPathComponent)"])
        }

        let pixelSize = CGSize(width: Int(image.size.width * image.scale), height: Int(image.size.height * image.scale))

        let thumbURL = imagesDir.appendingPathComponent("IMG_\(id)_thumb.jpg")
        let thumb = try await makeThumbnail(from: image, maxEdge: 600)
        guard let thumbData = thumb.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "SafeSnap", code: -13, userInfo: [NSLocalizedDescriptionKey: "Unable to encode thumbnail jpeg"])
        }
        try thumbData.write(to: thumbURL, options: .atomic)

        let persistedFormat: PersistedScanImage.Format = (format == .png) ? .png : .jpg
        return PersistedScanImage(imageURL: fullURL, thumbnailURL: thumbURL, pixelSize: pixelSize, format: persistedFormat)
    }

    private func makeThumbnail(from image: UIImage, maxEdge: CGFloat) async throws -> UIImage {
        let size = image.size
        let scale = min(1, maxEdge / max(size.width, size.height))
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

enum ScanError: Identifiable, LocalizedError {
    case openAIFailed(reason: String, underlying: Error? = nil)
    case missingOpenAIResult
    
    var id: String { localizedDescription }
    
    // Convenience
    var underlyingError: Error? {
        if case let .openAIFailed(_, underlying) = self {
            return underlying
        }
        return nil
    }
    private var underlyingLE: LocalizedError? { underlyingError as? LocalizedError }
    
    // LocalizedError forwarding
    var errorDescription: String? {
        if let d = underlyingLE?.errorDescription, !d.isEmpty {
            return d
        }
        switch self {
        case .openAIFailed(let reason, _):
            return "Analysis failed: \(reason)"
        case .missingOpenAIResult:
            return "OpenAI result is missing."
        }
    }
    
    var failureReason: String? {
        if let r = underlyingLE?.failureReason, !r.isEmpty {
            return r
        }
        switch self {
        case .openAIFailed(let reason, _):
            return reason
        case .missingOpenAIResult:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        if let s = underlyingLE?.recoverySuggestion, !s.isEmpty {
            return s
        }
        switch self {
        case .openAIFailed:
            return "Check your connection and try again, or run the deeper check."
        case .missingOpenAIResult:
            return "Retry the scan. If it persists, force-quit and reopen the app."
        }
    }
}

public struct SafetyOptions {
    var includeDogs: Bool
    var includeCats: Bool
    var includeChildren: Bool
}
extension SafetyOptions {
    func asPromptFlags() -> String {
        "includeDogs=\(includeDogs), includeCats=\(includeCats), includeChildren=\(includeChildren)"
    }
}

@MainActor
final class ScanAnalysisCoordinator: ObservableObject {
    @Published var currentPhase: AnalysisPhase = .preparing
    @Published var isComplete: Bool = false
    @Published var stage: SafetyAnalyzer.Stage = .vision
    @Published var visionDuration: Double? = nil
    @Published var fastDuration: Double? = nil
    @Published var smartDuration: Double? = nil
    @Published var visionGuess: ProductGuess? = nil
    @Published var modelconfidence: Double? = nil
    @Published var partial: String? = nil
    @Published var scanError: ScanError?
    
    private let analyzer: SafetyAnalyzing
    private let historyService: ScanHistoryRecording
    private let imageStore: ScanImageStoring
    
    private var safetyAnalysis: SafetyAnalysisResponse?
    private var thumbnail: UIImage?
    private var currentRequest: SafetyAnalysisRequest?
    private var runningTask: Task<SafetyAnalysisResponse, Error>? = nil
    
    @Published var latestHistoryItem: ScanHistoryItem?
    @Published var explainability: AnalysisExtras? = nil
    
    convenience init(geminiService: GeminiService, historyService: ScanHistoryService) {
        self.init(analyzer: geminiService, historyService: historyService)
    }

    init(analyzer: SafetyAnalyzing, historyService: ScanHistoryRecording, imageStore: ScanImageStoring = FileScanImageStore()) {
        self.analyzer = analyzer
        self.historyService = historyService
        self.imageStore = imageStore
    }
    
    @MainActor
    func startGeminiScan(image: UIImage, options: SafetyOptions) async throws {
        currentPhase = .openAI
        let analyzed = try await analyzer.analyzeSafetyWithExtras(
            image: image,
            options: options,
            streamToken: { [weak self] _ in
                Task { @MainActor in self?.partial = "Analyzing…" }
            },
            visionLabels: [],
            ocrHits: []
        )
        let result = analyzed.response
        self.explainability = analyzed.extras
        
        // Persist image and build history item
        let imageData: Data = image.jpegData(compressionQuality: 0.9) ?? Data()
        self.safetyAnalysis = result
        
        // Map options to history toggles
        let toggles = ScanHistoryItem.UserToggles(
            includeDogs: options.includeDogs,
            includeCats: options.includeCats,
            includeChildren: options.includeChildren
        )
        
        let storeResult = try await imageStore.persist(image: image, data: imageData)
        let imageURL = storeResult.imageURL
        // Persisted image at: \(imageURL.lastPathComponent), thumb: \(storeResult.thumbnailURL.lastPathComponent) size: \(Int(storeResult.pixelSize.width))x\(Int(storeResult.pixelSize.height))
        
        // Prefer canonical category from policy extras if available
        let canonicalType = analyzed.extras.policy.canonicalCategory ?? result.productType
        let product = ProductIdentification(
            productType: canonicalType,
            productName: result.productName,
            brandCandidates: [],
            labels: analyzed.extras.evidence.labels,
            objects: [],
            detectedText: analyzed.extras.evidence.ocrHits.isEmpty ? nil : analyzed.extras.evidence.ocrHits.joined(separator: ", "),
            confidence: result.recognitionConfidence
        )
        
        let item = ScanHistoryBuilder.build(
            product: product,
            analysis: result,
            imageRef: imageURL,
            imageData: imageData,
            userToggles: toggles,
            visionContextRef: nil,
            model: "gemini-1.5-flash",
            promptVersion: "v1-gemini"
        )
        self.historyService.add(item)
        self.latestHistoryItem = item
        self.isComplete = true
        
        // Advance phase to report for UI to render
        self.currentPhase = .report
    }
    
    func cancelAnalysis() {
        analyzer.cancelAnalysis()
        currentPhase = .preparing
    }
    
}
