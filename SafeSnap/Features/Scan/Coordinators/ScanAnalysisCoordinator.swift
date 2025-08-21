//
//  ScanAnalysisCoordinator.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import Foundation
import SwiftUI

enum ScanError: Identifiable, Error {
    case visionFailed
    case openAIFailed(reason: String)
    case missingDetectionData
    case missingClassification
    case missingOpenAIResult

    var id: String { localizedDescription }

    var localizedDescription: String {
        switch self {
        case .visionFailed:
            return "We couldn’t recognize anything in the image. Try a clearer photo."
        case .openAIFailed(let reason):
            return "Analysis failed: \(reason)"
        case .missingDetectionData:
            return "Detection data is missing."
        case .missingClassification:
            return "Classification data is missing."
        case .missingOpenAIResult:
            return "OpenAI result is missing."
        }
    }
}

@MainActor
final class ScanAnalysisCoordinator: ObservableObject {
    @Published var currentPhase: ScanStepPhase = .preparing
    @Published var isComplete: Bool = false

    private let visionService: VisionService
    private let openAIService: OpenAIService
    private let historyService: ScanHistoryService

    private var productId: ProductIdentification?
    private var detectionData: Data?
    private var safetyAnalysis: SafetyAnalysisResponse?
    private var thumbnail: UIImage?
    
    private var includeDog: Bool = false
    private var includeCat: Bool = false
    private var includeChildren: Bool = false
    
    @Published var latestHistoryItem: ScanHistoryItem?

    init(visionService: VisionService, openAIService: OpenAIService, historyService: ScanHistoryService) {
        self.visionService = visionService
        self.openAIService = openAIService
        self.historyService = historyService
    }

    func start(with imageData: Data, thumbnail: UIImage?, includeDog: Bool, includeCat: Bool, includeChildren: Bool) async throws {
        self.thumbnail = thumbnail
        self.includeDog = includeDog
        self.includeCat = includeCat
        self.includeChildren = includeChildren

        let pipeline: [ScanStepPhase] = [.preparing, .vision, .openAI, .report]
        for phase in pipeline {
            guard !Task.isCancelled else {
                print("⚠️ Task was cancelled — exiting coordinator early")
                return
            }

            currentPhase = phase
            do {
                try await perform(phase, imageData: imageData)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw error
            }
        }

        isComplete = true
    }

    func perform(_ phase: ScanStepPhase, imageData: Data) async throws {
        switch phase {
        case .preparing:
            break
        case .vision:
            detectionData = try await visionService.detectProducts(in: imageData)
            
            guard let detectionData else { throw ScanError.missingDetectionData }
            
            let id = try VisionLabelResult(labelAnnotations: nil).classifyProduct(from: detectionData)
            self.productId = id
        case .detecting:
            break
        case .openAI:
            guard let detectionData = detectionData else { throw ScanError.missingDetectionData }
            guard let id = productId else { throw ScanError.missingClassification }
            do {
                let compact = try visionService.sanitizedOpenAIData(from: detectionData)
                
                let req = SafetyAnalysisRequest(
                    productName: id.productName,
                    productType: id.productType,
                    includeDogs: includeDog,
                    includeCats: includeCat,
                    includeChildren: includeChildren
                )
                
                let analysis = try await openAIService.generateSafetyAnalysis(req, context: compact)
                self.safetyAnalysis = analysis
            } catch {
                throw ScanError.openAIFailed(reason: error.localizedDescription)
            }
        case .identify, .databases, .openAISafety, .petSafety:
            break // future implementation
        case .report:
            guard let analysis = safetyAnalysis else { throw ScanError.missingOpenAIResult }
            guard let id = productId else { throw ScanError.missingClassification }

            // Build compact signals summary (from classification)
            let signals = ScanHistoryItem.SignalsSummary(
                labels: Array(id.labels.prefix(5)),
                objects: Array((id.objects ?? []).prefix(3)),
                webEntities: Array((id.webEntities ?? []).prefix(5)),
                bestGuess: nil,
                detectedTextExcerpt: {
                    if let t = id.detectedText, !t.isEmpty { return t.count > 200 ? String(t.prefix(200)) + "…" : t }
                    return nil
                }()
            )

            // User toggles snapshot
            let toggles = ScanHistoryItem.UserToggles(
                includeDogs: includeDog,
                includeCats: includeCat,
                includeChildren: includeChildren
            )

            // Persist image to disk so history can load it
            let imageURL = try? persistScanImage(imageData)

            // Persist canonical snapshot
            let item = ScanHistoryBuilder.build(
                product: id,
                analysis: analysis,
                imageRef: imageURL,
                imageData: imageData,
                userToggles: toggles,
                signals: signals,
                visionContextRef: nil,
                model: "gpt-4o",
                promptVersion: "v1"
            )
            historyService.add(item)
            self.latestHistoryItem = item
        }
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
