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
    case visionFailed(reason: String, underlying: Error? = nil)
    case openAIFailed(reason: String, underlying: Error? = nil)
    case missingOpenAIResult
    
    var id: String { localizedDescription }
    
    // Convenience
    var underlyingError: Error? {
        switch self {
        case let .openAIFailed(_, underlying):
            return underlying
        case let .visionFailed(_, underlying):
            return underlying
        case .missingOpenAIResult:
            return nil
        }
    }
    private var underlyingLE: LocalizedError? { underlyingError as? LocalizedError }
    
    // LocalizedError forwarding
    var errorDescription: String? {
        if let d = underlyingLE?.errorDescription, !d.isEmpty {
            return d
        }
        switch self {
        case .visionFailed(let reason, _):
            return "Vision analysis failed: \(reason)"
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
        case .visionFailed(let reason, _):
            return reason
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
        case .visionFailed:
            return "Try retaking the photo with better lighting and ensure the label is readable."
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
    private let visionService: VisionServiceType
    private let historyService: ScanHistoryRecording
    private let imageStore: ScanImageStoring
    
    private var safetyAnalysis: SafetyAnalysisResponse?
    private var thumbnail: UIImage?
    private var currentRequest: SafetyAnalysisRequest?
    private var runningTask: Task<SafetyAnalysisResponse, Error>? = nil
    
    @Published var latestHistoryItem: ScanHistoryItem?
    @Published var resultDTO: GeminiSafetyDTO? = nil
    @Published var explainability: AnalysisExtras? = nil
    
    convenience init(geminiService: GeminiService, visionService: VisionServiceType, historyService: ScanHistoryService) {
        self.init(analyzer: geminiService, visionService: visionService, historyService: historyService)
    }

    init(
        analyzer: SafetyAnalyzing,
        visionService: VisionServiceType,
        historyService: ScanHistoryRecording,
        imageStore: ScanImageStoring = FileScanImageStore()
    ) {
        self.analyzer = analyzer
        self.visionService = visionService
        self.historyService = historyService
        self.imageStore = imageStore
    }
    
    @MainActor
    func startGeminiScan(image: UIImage, options: SafetyOptions) async throws {
        stage = .vision
        visionDuration = nil
        fastDuration = nil
        smartDuration = nil
        let visionStart = ContinuousClock.now
        // Run Vision off-main to avoid blocking UI presentation.
        let vs = visionService
        let visionResult: VisionAnalysisResult = try await offMain {
            try await vs.analyze(image: image)
        }
        visionGuess = visionResult.guess
        visionDuration = seconds(visionStart.duration(to: ContinuousClock.now))

        currentPhase = .openAI
        stage = .fast

        let labels = visionResult.labels
        let ocrHits = extractOCRHits(from: visionResult.detectedText)
        let visionContext = VisionContextPayload(
            guessName: visionResult.guess.name,
            guessType: visionResult.guess.type,
            confidence: visionResult.guess.confidence,
            brandCandidates: visionResult.brandCandidates,
            labels: labels,
            objects: visionResult.objects,
            detectedText: visionResult.detectedText,
            sanitizedContext: visionResult.sanitizedContext,
            bestGuess: visionResult.bestGuess
        )

        let fastStart = ContinuousClock.now
        let analyzed = try await analyzer.analyzeSafetyWithExtras(
            image: image,
            options: options,
            streamToken: { [weak self] _ in
                Task { @MainActor in self?.partial = "Analyzing…" }
            },
            visionLabels: labels,
            ocrHits: ocrHits,
            visionContext: visionContext
        )
        fastDuration = seconds(fastStart.duration(to: ContinuousClock.now))
        let result = analyzed.response
        self.explainability = analyzed.extras
        self.modelconfidence = result.modelConfidence
        self.stage = .smart
        self.smartDuration = fastDuration

        // Build a lightweight DTO for the ResultView/VM
        let childConf = Int((result.modelConfidence * 100.0).rounded()).clamped(to: 0...100)
        if result.kidPros.isEmpty || result.kidCons.isEmpty {
            print("ScanAnalysisCoordinator warning: kidPros/kidCons empty; check Gemini prompt.")
        }
        if result.kidNarrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("ScanAnalysisCoordinator warning: kidNarrative empty; check Gemini prompt.")
        }
        let kidPros = result.kidPros
        let kidCons = result.kidCons
        let kidNarrativeTrimmed = result.kidNarrative.trimmingCharacters(in: .whitespacesAndNewlines)
        let kidNarrative = kidNarrativeTrimmed.isEmpty ? nil : kidNarrativeTrimmed

        func cleaned(_ values: [String]?) -> [String] {
            guard let values else { return [] }
            let trimmed = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return Array(trimmed.prefix(3))
        }

        let dogPros: [String]
        let dogCons: [String]
        let dogNarrative: String?
        if options.includeDogs {
            dogPros = cleaned(result.dogPros)
            dogCons = cleaned(result.dogCons)
            let narrative = result.dogNarrative?.trimmingCharacters(in: .whitespacesAndNewlines)
            dogNarrative = narrative?.isEmpty == true ? nil : narrative
            if dogPros.isEmpty || dogCons.isEmpty || dogNarrative == nil {
                print("ScanAnalysisCoordinator warning: dog explainability incomplete; check Gemini prompt.")
            }
        } else {
            dogPros = []
            dogCons = []
            dogNarrative = nil
        }

        let catPros: [String]
        let catCons: [String]
        let catNarrative: String?
        if options.includeCats {
            catPros = cleaned(result.catPros)
            catCons = cleaned(result.catCons)
            let narrative = result.catNarrative?.trimmingCharacters(in: .whitespacesAndNewlines)
            catNarrative = narrative?.isEmpty == true ? nil : narrative
            if catPros.isEmpty || catCons.isEmpty || catNarrative == nil {
                print("ScanAnalysisCoordinator warning: cat explainability incomplete; check Gemini prompt.")
            }
        } else {
            catPros = []
            catCons = []
            catNarrative = nil
        }
        let dogWarns = result.petSafety.dogs.map { GeminiSafetyDTO.PetWarn(severity: $0.severity.rawValue, title: $0.warning, reason: $0.reason) }
        let catWarns = result.petSafety.cats.map { GeminiSafetyDTO.PetWarn(severity: $0.severity.rawValue, title: $0.warning, reason: $0.reason) }
        let dto = GeminiSafetyDTO(
            productName: result.productName ?? visionResult.guess.name,
            canonicalCategory: analyzed.extras.policy.canonicalCategory,
            childScore: result.childSafetyScore,
            dogScore: result.dogSafetyScore,
            catScore: result.catSafetyScore,
            childConfidence: childConf,
            dogConfidence: nil,
            catConfidence: nil,
            kidPros: kidPros,
            kidCons: kidCons,
            kidNarrative: kidNarrative,
            dogPros: dogPros,
            dogCons: dogCons,
            dogNarrative: dogNarrative,
            catPros: catPros,
            catCons: catCons,
            catNarrative: catNarrative,
            dogWarnings: dogWarns,
            catWarnings: catWarns,
            labels: analyzed.extras.evidence.labels,
            ocrHits: analyzed.extras.evidence.ocrHits,
            rulesTriggered: analyzed.extras.policy.rulesTriggered,
            dataSources: ["Google Vision", "SafeSnap Toxicity Service"]
        )
        self.resultDTO = dto

        // Persist image and build history item
        let imageData: Data = try await offMain {
            image.jpegData(compressionQuality: 0.9) ?? Data()
        }
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
            productName: visionResult.guess.name,
            brandCandidates: visionResult.brandCandidates,
            labels: labels,
            objects: visionResult.objects,
            detectedText: visionResult.detectedText,
            confidence: visionResult.confidence,
            bestGuess: visionResult.bestGuess
        )

        let item = ScanHistoryBuilder.build(
            product: product,
            analysis: result,
            imageRef: imageURL,
            imageData: imageData,
            userToggles: toggles,
            visionContextRef: nil,
            model: "rag-toxic-check",
            promptVersion: "v1-rag"
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

    // Run async work on a detached, background-priority task and return to caller.
    private func offMain<T>(_ work: @escaping () async throws -> T) async throws -> T {
        return try await Task.detached(priority: .userInitiated) {
            try await work()
        }.value
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        let attosecondsPerSecond = 1_000_000_000_000_000_000.0
        return Double(components.seconds) + Double(components.attoseconds) / attosecondsPerSecond
    }

    private func extractOCRHits(from text: String?) -> [String] {
        guard let text = text, !text.isEmpty else { return [] }
        let separators = CharacterSet.newlines.union(.punctuationCharacters)
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Helpers
private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
