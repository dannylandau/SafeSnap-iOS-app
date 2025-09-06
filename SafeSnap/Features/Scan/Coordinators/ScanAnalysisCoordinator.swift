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
}
extension SafetyOptions {
    func asPromptFlags() -> String {
        "includeDogs=\(includeDogs), includeCats=\(includeCats)"
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

    private let geminiService: GeminiService
    private let historyService: ScanHistoryService

    private var safetyAnalysis: SafetyAnalysisResponse?
    private var thumbnail: UIImage?
    private var currentRequest: SafetyAnalysisRequest?
    private var runningTask: Task<SafetyAnalysisResponse, Error>? = nil
    
    private var includeDog: Bool = false
    private var includeCat: Bool = false
    private var includeChildren: Bool = false
    
    @Published var latestHistoryItem: ScanHistoryItem?

    init(geminiService: GeminiService, historyService: ScanHistoryService) {
        self.geminiService = geminiService
        self.historyService = historyService
    }
    
    @MainActor
    func startGeminiScan(image: UIImage, options: SafetyOptions) async throws {
        currentPhase = .preparing
                let result = try await geminiService.analyzeSafety(
                    image: image,
                    options: options,
                    streamToken: { [weak self] _ in
                        Task { @MainActor in self?.partial = "Analyzing…" }
                    }
                )
                // Persist image and build history item
                let imageData: Data = image.jpegData(compressionQuality: 0.9) ?? Data()
                self.safetyAnalysis = result

                // Map options to history toggles
                let toggles = ScanHistoryItem.UserToggles(
                    includeDogs: options.includeDogs,
                    includeCats: options.includeCats,
                    includeChildren: true
                )

                let imageURL = try? self.persistScanImage(imageData)

                // Build a minimal ProductIdentification from Gemini result
                let product = ProductIdentification(
                    productType: result.productType,
                    productName: result.productName,
                    brandCandidates: [],
                    labels: [],
                    objects: [],
                    detectedText: nil,
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
        geminiService.cancelAnalysis()
        currentPhase = .preparing
    }

    private func persistScanImage(_ data: Data) throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let imagesDir = docs.appendingPathComponent("Images", isDirectory: true)
        if !fm.fileExists(atPath: imagesDir.path) {
            try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }

        // Decode input bytes -> UIImage
        guard let uiImage = UIImage(data: data) else {
            throw NSError(domain: "SafeSnap", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Persist image: input data is not a valid image"])
        }

        // Prefer JPEG, fallback to PNG
        let jpegURL = imagesDir.appendingPathComponent(UUID().uuidString + ".jpg")
        if let jpeg = uiImage.jpegData(compressionQuality: 0.9) {
            try jpeg.write(to: jpegURL, options: .atomic)
            // Validate readable
            if UIImage(contentsOfFile: jpegURL.path) != nil { return jpegURL }
        }

        let pngURL = imagesDir.appendingPathComponent(UUID().uuidString + ".png")
        if let png = uiImage.pngData() {
            try png.write(to: pngURL, options: .atomic)
            if UIImage(contentsOfFile: pngURL.path) != nil { return pngURL }
        }

        // Last resort: write raw bytes with a neutral extension
        let rawURL = imagesDir.appendingPathComponent(UUID().uuidString + ".img")
        try data.write(to: rawURL, options: .atomic)
        return rawURL
    }
    
}
