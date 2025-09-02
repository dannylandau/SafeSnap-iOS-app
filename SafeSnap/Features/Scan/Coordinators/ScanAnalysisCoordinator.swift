//
//  ScanAnalysisCoordinator.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import Foundation
import SwiftUI
import CoreGraphics

enum ScanError: Identifiable, Error {
    case openAIFailed(reason: String)
    case missingOpenAIResult

    var id: String { localizedDescription }

    var localizedDescription: String {
        switch self {
        case .openAIFailed(let reason):
            return "Analysis failed: \(reason)"
        case .missingOpenAIResult:
            return "OpenAI result is missing."
        }
    }
}

@MainActor
final class ScanAnalysisCoordinator: ObservableObject {
    @Published var currentPhase: AnalysisPhase = .preparing
    @Published var isComplete: Bool = false

    private let visionService: VisionService
    private let openAIService: OpenAIService
    private let historyService: ScanHistoryService
    private let analyzer: SafetyAnalyzer

    private var safetyAnalysis: SafetyAnalysisResponse?
    private var thumbnail: UIImage?
    private var currentRequest: SafetyAnalysisRequest?
    
    private var includeDog: Bool = false
    private var includeCat: Bool = false
    private var includeChildren: Bool = false
    
    @Published var latestHistoryItem: ScanHistoryItem?

    init(visionService: VisionService, openAIService: OpenAIService, historyService: ScanHistoryService) {
        self.visionService = visionService
        self.openAIService = openAIService
        self.historyService = historyService
        self.analyzer = SafetyAnalyzer(vision: visionService, openAI: openAIService)
    }

    func start(with imageData: Data, thumbnail: UIImage?, includeDog: Bool, includeCat: Bool, includeChildren: Bool) async throws {
        self.thumbnail = thumbnail
        self.includeDog = includeDog
        self.includeCat = includeCat
        self.includeChildren = includeChildren

        // Build a request snapshot for history toggles; analyzer handles Vision + OpenAI orchestration
        self.currentRequest = SafetyAnalysisRequest(
            includeDogs: includeDog,
            includeCats: includeCat,
            includeChildren: includeChildren
        )

        let pipeline: [AnalysisPhase] = [.preparing, .openAI, .report]
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

    func perform(_ phase: AnalysisPhase, imageData: Data) async throws {
        switch phase {
        case .preparing:
            break
        case .openAI:
            do {
                let req = currentRequest ?? SafetyAnalysisRequest(
                    includeDogs: includeDog,
                    includeCats: includeCat,
                    includeChildren: includeChildren
                )

                // Map UI toggles to analyzer options
                let includePetSafety = includeDog || includeCat
                let petPreference: PetPreference = {
                    switch (includeDog, includeCat) {
                    case (true, true): return .both
                    case (true, false): return .dog
                    case (false, true): return .cat
                    default: return .none
                    }
                }()

                // Convert image bytes -> CGImage
                guard let uiImage = UIImage(data: imageData), let cgImage = uiImage.cgImage else {
                    throw NSError(domain: "SafeSnap", code: -11, userInfo: [NSLocalizedDescriptionKey: "Input data is not a valid image"])
                }

                // Run analyzer: Vision recognition -> fast model -> optional smart model
                let analysis = try await analyzer.run(
                    image: cgImage,
                    options: .init(includePetSafety: includePetSafety, petPreference: petPreference)
                )

                self.safetyAnalysis = analysis
            } catch {
                throw ScanError.openAIFailed(reason: error.localizedDescription)
            }
        case .report:
            guard let analysis = safetyAnalysis else { throw ScanError.missingOpenAIResult }
            let req = currentRequest ?? SafetyAnalysisRequest(
                includeDogs: includeDog,
                includeCats: includeCat,
                includeChildren: includeChildren
            )

            // Signals are empty for now (Vision removed). Consider extending analysis to fill these later.
            let signals = ScanHistoryItem.SignalsSummary(
                labels: [],
                objects: [],
                webEntities: [],
                bestGuess: nil,
                detectedTextExcerpt: nil
            )

            let toggles = ScanHistoryItem.UserToggles(
                includeDogs: includeDog,
                includeCats: includeCat,
                includeChildren: includeChildren
            )

            let imageURL = try? persistScanImage(imageData)

            // Minimal ProductIdentification synthesized from the analysis (Vision confidence now available)
            let product = ProductIdentification(
                productType: analysis.productType,
                productName: analysis.productName,
                brandCandidates: [],
                labels: [],
                objects: [],
                detectedText: nil,
                confidence: analysis.recognitionConfidence
            )

            let item = ScanHistoryBuilder.build(
                product: product,
                analysis: analysis,
                imageRef: imageURL,
                imageData: imageData,
                userToggles: toggles,
                signals: signals,
                visionContextRef: nil,
                model: "gpt-5",
                promptVersion: "v2"
            )
            historyService.add(item)
            self.latestHistoryItem = item
        default:
            break
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
