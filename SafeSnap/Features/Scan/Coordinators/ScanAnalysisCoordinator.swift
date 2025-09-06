//
//  ScanAnalysisCoordinator.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import Foundation
import SwiftUI
import CoreGraphics

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

    private let visionService: VisionService
    private let openAIService: OpenAIService
    private let historyService: ScanHistoryService
    private let analyzer: SafetyAnalyzer

    private var safetyAnalysis: SafetyAnalysisResponse?
    private var thumbnail: UIImage?
    private var currentRequest: SafetyAnalysisRequest?
    private var runningTask: Task<SafetyAnalysisResponse, Error>? = nil
    
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
    
    func cancelAnalysis() {
        runningTask?.cancel()
    }

    func perform(_ phase: AnalysisPhase, imageData: Data) async throws {
        switch phase {
        case .preparing:
            break
        case .openAI:
            do {
                // Map UI toggles to analyzer options
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
                runningTask = Task {
                    try await analyzer.run(
                        image: cgImage,
                        options: .init(petPreference: petPreference),
                        visionGuess:  { [weak self] guess in
                            Task { @MainActor in self?.visionGuess = guess }
                        },
                        modelConfidence: { [weak self] confidence in
                            Task { @MainActor in self?.modelconfidence = confidence }
                        },
                        onStageChange: { [weak self] newStage in
                            Task { @MainActor in self?.stage = newStage }
                        },
                        onStageTiming: { [weak self] stage, seconds in
                            Task { @MainActor in
                                switch stage {
                                case .vision: self?.visionDuration = seconds
                                case .fast:   self?.fastDuration = seconds
                                case .smart:  self?.smartDuration = seconds
                                }
                            }
                        }
                    )
                }
                let analysis = try await runningTask!.value
                runningTask = nil

                self.safetyAnalysis = analysis
            } catch {
                throw ScanError.openAIFailed(reason: (error as? LocalizedError)?.localizedDescription ?? "Unknown", underlying: error)
            }
        case .report:
            guard let analysis = safetyAnalysis else { throw ScanError.missingOpenAIResult }

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
