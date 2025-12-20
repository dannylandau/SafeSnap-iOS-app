//
//  ScanAnalysisCoordinator.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import Foundation
import SwiftUI
import CoreGraphics
import UIKit
import Combine

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
                throw NSError(domain: "Archie", code: -11, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image to JPEG"])
            }
            try jpg.write(to: jpgURL, options: .atomic)
            format = .jpg
            fullURL = jpgURL
        }

        guard UIImage(contentsOfFile: fullURL.path) != nil else {
                throw NSError(domain: "Archie", code: -12, userInfo: [NSLocalizedDescriptionKey: "Written image is unreadable at \(fullURL.lastPathComponent)"])
        }

        let pixelSize = CGSize(width: Int(image.size.width * image.scale), height: Int(image.size.height * image.scale))

        let thumbURL = imagesDir.appendingPathComponent("IMG_\(id)_thumb.jpg")
        let thumb = try await makeThumbnail(from: image, maxEdge: 600)
        guard let thumbData = thumb.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "Archie", code: -13, userInfo: [NSLocalizedDescriptionKey: "Unable to encode thumbnail jpeg"])
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

/// Analysis phase enumeration
enum AnalysisPhase: Equatable {
    case preparing
    case analyzing
    case uploading
    case savingHistory
    case report
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
    
    // MARK: - Published State
    
    @Published var currentPhase: AnalysisPhase = .preparing
    @Published var isComplete: Bool = false
    @Published var stage: AnalysisStage = .vision
    @Published var fastDuration: Double? = nil
    @Published var smartDuration: Double? = nil
    @Published var modelconfidence: Double? = nil
    @Published var partial: String? = nil
    @Published var scanError: ScanError?
    
    @Published var latestHistoryItem: ScanHistoryItem?
    @Published var latestProductAnalysis: ProductAnalysis?
    @Published var resultDTO: SafetyDTO? = nil
    @Published var explainability: AnalysisExtras? = nil
    @Published var visionBestGuess: String? = nil
    @Published var visionWebEntities: [String] = []

    // MARK: - Dependencies
    
    private let apiService: ProductAnalyzing
    private let storageService: ImageStorageService
    private let historyService: ScanHistoryRecording
    private let imageStore: ScanImageStoring
    private let userSession: UserSession?
    
    private var safetyAnalysis: SafetyAnalysisResponse?
    
    // MARK: - Publishers
    
    var stagePublisher: AnyPublisher<AnalysisStage, Never> {
        $stage.eraseToAnyPublisher()
    }

    var partialPublisher: AnyPublisher<String?, Never> {
        $partial.eraseToAnyPublisher()
    }

    var visionBestGuessPublisher: AnyPublisher<String?, Never> {
        $visionBestGuess.eraseToAnyPublisher()
    }

    var visionWebEntitiesPublisher: AnyPublisher<[String], Never> {
        $visionWebEntities.eraseToAnyPublisher()
    }
    
    // MARK: - Init

    init(
        apiService: ProductAnalyzing = ArchieAPIService.shared,
        storageService: ImageStorageService = FirebaseStorageService.shared,
        historyService: ScanHistoryRecording,
        imageStore: ScanImageStoring = FileScanImageStore(),
        userSession: UserSession? = nil
    ) {
        self.apiService = apiService
        self.storageService = storageService
        self.historyService = historyService
        self.imageStore = imageStore
        self.userSession = userSession
    }
    
    // MARK: - Main Analysis Flow
    
    /// Start analysis using backend API
    /// The backend handles both vision recognition and safety analysis in one call
    @MainActor
    func startGeminiScan(image: UIImage, options: SafetyOptions) async throws {
        resetState()
        
        let analysisStart = ContinuousClock.now
        
        // Phase 1: Call backend API for analysis
        currentPhase = .analyzing
        stage = .fast
        partial = "Analyzing product safety…"
        
        let productAnalysis: ProductAnalysis
        do {
            productAnalysis = try await apiService.analyze(
            image: image,
                includeDogs: options.includeDogs,
                includeCats: options.includeCats,
                includeChildren: options.includeChildren
            )
        } catch {
            throw ScanError.openAIFailed(reason: error.localizedDescription, underlying: error)
        }
        
        // Store the product analysis
        self.latestProductAnalysis = productAnalysis
        
        // Update timing
        fastDuration = seconds(analysisStart.duration(to: ContinuousClock.now))
        smartDuration = fastDuration
        
        // Update UI state from analysis
        visionBestGuess = productAnalysis.name
        modelconfidence = productAnalysis.analysisMetadata?.modelConfidence
        
        // Convert to legacy SafetyAnalysisResponse for backward compatibility
        let result = convertToSafetyAnalysisResponse(productAnalysis, options: options)
        self.safetyAnalysis = result

        // Build explainability extras
        self.explainability = buildExtras(from: productAnalysis)
        
        // Build DTO for ResultView
        self.resultDTO = buildDTO(from: result, productAnalysis: productAnalysis, options: options)
        
        self.stage = .smart
        
        // Phase 2: Save locally
        partial = "Saving to history…"
        let imageData = image.jpegData(compressionQuality: 0.9) ?? Data()
        
        // Persist image locally
        let storeResult = try await imageStore.persist(image: image, data: imageData)
        
        // Build local history item
        let toggles = ScanHistoryItem.UserToggles(
            includeDogs: options.includeDogs,
            includeCats: options.includeCats,
            includeChildren: options.includeChildren
        )

        let product = ProductIdentification(
            productType: productAnalysis.category,
            productName: productAnalysis.name,
            brandCandidates: [],
            labels: [],
            objects: [],
            detectedText: nil,
            confidence: productAnalysis.analysisMetadata?.recognitionConfidence ?? 0.85,
            bestGuess: productAnalysis.name,
            webEntities: []
        )

        let item = ScanHistoryBuilder.build(
            product: product,
            analysis: result,
            imageRef: storeResult.imageURL,
            imageData: imageData,
            userToggles: toggles,
            visionContextRef: nil,
            model: "archie-backend",
            promptVersion: "v1-api"
        )
        
        self.historyService.add(item)
        self.latestHistoryItem = item
        
        // Phase 3: Sync to backend if user is signed in (background)
        if userSession?.isSignedIn == true {
            Task {
                await syncToBackend(productAnalysis: productAnalysis, image: image, options: options)
            }
        }
        
        // Complete
        self.isComplete = true
        self.currentPhase = .report
        self.partial = nil
    }

    func cancelAnalysis() {
        // API calls can't be cancelled easily, but we can reset state
        resetState()
    }
    
    // MARK: - Private Helpers
    
    private func resetState() {
        stage = .vision
        partial = nil
        visionBestGuess = nil
        visionWebEntities = []
        fastDuration = nil
        smartDuration = nil
        isComplete = false
        currentPhase = .preparing
    }

    /// Sync analysis to backend (upload image + save history) - runs in background
    private func syncToBackend(productAnalysis: ProductAnalysis, image: UIImage, options: SafetyOptions) async {
        do {
            // Upload image to Firebase Storage
            let imageUrl = try await storageService.uploadAnalysisImage(image: image, analysisId: productAnalysis.id)
            
            // Create API history item with image URL
            let historyItem = makeAPIHistoryItem(from: productAnalysis, imageUrl: imageUrl, options: options)
            
            // Save to backend history
            _ = try await apiService.saveToHistory(item: historyItem)
            
            #if DEBUG
            print("✅ Successfully synced analysis \(productAnalysis.id) to backend")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Failed to sync to backend: \(error.localizedDescription)")
            #endif
            // Don't throw - this is background sync, local history is already saved
        }
    }
    
    /// Create API history item from ProductAnalysis
    private func makeAPIHistoryItem(
        from analysis: ProductAnalysis,
        imageUrl: String?,
        options: SafetyOptions
    ) -> APIHistoryItem {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return APIHistoryItem(
            id: analysis.id,
            createdAt: dateFormatter.string(from: Date()),
            name: analysis.name,
            score: analysis.safetyScore.overall,
            maxScore: analysis.safetyScore.maxScore,
            preview: nil,
            imageUrl: imageUrl,
            labels: [],
            category: analysis.category,
            petSafetyOptions: PetSafetyOptions(
                includeDogs: options.includeDogs,
                includeCats: options.includeCats,
                includeChildren: options.includeChildren
            ),
            fullAnalysis: analysis
        )
    }
    
    /// Convert ProductAnalysis (API model) to SafetyAnalysisResponse (legacy model)
    private func convertToSafetyAnalysisResponse(_ analysis: ProductAnalysis, options: SafetyOptions) -> SafetyAnalysisResponse {
        let kidSafety = analysis.analysis.kidSafety
        let petSafety = analysis.analysis.petSafety
        
        // Extract dog warnings
        let dogWarnings: [SafetyAnalysisResponse.PetWarning] = petSafety.dogs?.details?.map { detail in
            SafetyAnalysisResponse.PetWarning(
                severity: Severity(rawValue: detail.severity.rawValue) ?? .medium,
                warning: detail.warning,
                reason: detail.reason
            )
        } ?? []
        
        // Extract cat warnings
        let catWarnings: [SafetyAnalysisResponse.PetWarning] = petSafety.cats?.details?.map { detail in
            SafetyAnalysisResponse.PetWarning(
                severity: Severity(rawValue: detail.severity.rawValue) ?? .medium,
                warning: detail.warning,
                reason: detail.reason
            )
        } ?? []
        
        // Convert general safety
        let generalPros = analysis.analysis.generalSafety?.pros.map { point in
            SafetyAnalysisResponse.LabeledItem(
                label: point.label,
                severity: Severity(rawValue: point.severity) ?? .low,
                category: point.category
            )
        } ?? []
        
        let generalCons = analysis.analysis.generalSafety?.cons.map { point in
            SafetyAnalysisResponse.LabeledItem(
                label: point.label,
                severity: Severity(rawValue: point.severity) ?? .medium,
                category: point.category
            )
        } ?? []
        
        // Convert hygiene warnings
        let hygieneWarnings = analysis.analysis.hygiene.warnings?.map { warning in
            SafetyAnalysisResponse.HygieneWarning(type: warning.type, message: warning.message)
        } ?? []
        
        // Convert recalls
        let recalls = analysis.analysis.recalls.map { recall in
            SafetyAnalysisResponse.Recall(
                date: recall.date,
                reason: recall.reason,
                severity: Severity(rawValue: recall.severity) ?? .medium,
                source: recall.source
            )
        }
        
        return SafetyAnalysisResponse(
            productName: analysis.name,
            productType: analysis.category,
            overallSafetyScore: analysis.safetyScore.overall,
            childSafetyScore: kidSafety.score ?? analysis.safetyScore.overall,
            dogSafetyScore: options.includeDogs ? petSafety.dogs?.score : nil,
            catSafetyScore: options.includeCats ? petSafety.cats?.score : nil,
            modelConfidence: analysis.analysisMetadata?.modelConfidence ?? 0.85,
            recognitionConfidence: analysis.analysisMetadata?.recognitionConfidence ?? 0.90,
            generalSafety: SafetyAnalysisResponse.GeneralSafety(pros: generalPros, cons: generalCons),
            petSafety: SafetyAnalysisResponse.PetSafety(dogs: dogWarnings, cats: catWarnings),
            hygieneWarnings: hygieneWarnings,
            recalls: recalls,
            kidPros: kidSafety.benefits,
            kidCons: kidSafety.concerns,
            kidNarrative: kidSafety.narrative ?? "",
            dogPros: petSafety.dogs?.pros,
            dogCons: petSafety.dogs?.cons,
            dogNarrative: petSafety.dogs?.narrative,
            catPros: petSafety.cats?.pros,
            catCons: petSafety.cats?.cons,
            catNarrative: petSafety.cats?.narrative
        )
    }
    
    /// Build AnalysisExtras from ProductAnalysis
    private func buildExtras(from analysis: ProductAnalysis) -> AnalysisExtras {
        let metadata = analysis.analysisMetadata
        return AnalysisExtras(
            evidence: SafetyEvidence(labels: [], ocrHits: []),
            policy: PolicyOutcome(
                canonicalCategory: metadata?.canonicalCategory ?? analysis.category,
                rulesTriggered: metadata?.rulesTriggered ?? []
            )
        )
    }
    
    /// Build GeminiSafetyDTO for ResultView
    private func buildDTO(from result: SafetyAnalysisResponse, productAnalysis: ProductAnalysis, options: SafetyOptions) -> GeminiSafetyDTO {
        let childConf = Int((result.modelConfidence * 100.0).rounded()).clamped(to: 0...100)
        
        func cleaned(_ values: [String]?) -> [String] {
            guard let values else { return [] }
            return Array(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(3))
        }
        
        let kidNarrative = result.kidNarrative.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let dogWarns = result.petSafety.dogs.map {
            SafetyDTO.PetWarning(severity: $0.severity.rawValue, title: $0.warning, reason: $0.reason)
        }
        let catWarns = result.petSafety.cats.map {
            SafetyDTO.PetWarning(severity: $0.severity.rawValue, title: $0.warning, reason: $0.reason)
        }
        
        return GeminiSafetyDTO(
            productName: result.productName,
            canonicalCategory: productAnalysis.analysisMetadata?.canonicalCategory,
            childScore: result.childSafetyScore,
            dogScore: result.dogSafetyScore,
            catScore: result.catSafetyScore,
            childConfidence: childConf,
            dogConfidence: nil,
            catConfidence: nil,
            kidPros: cleaned(result.kidPros),
            kidCons: cleaned(result.kidCons),
            kidNarrative: kidNarrative.isEmpty ? nil : kidNarrative,
            dogPros: options.includeDogs ? cleaned(result.dogPros) : [],
            dogCons: options.includeDogs ? cleaned(result.dogCons) : [],
            dogNarrative: options.includeDogs ? result.dogNarrative : nil,
            catPros: options.includeCats ? cleaned(result.catPros) : [],
            catCons: options.includeCats ? cleaned(result.catCons) : [],
            catNarrative: options.includeCats ? result.catNarrative : nil,
            dogWarnings: dogWarns,
            catWarnings: catWarns,
            labels: [],
            ocrHits: [],
            rulesTriggered: productAnalysis.analysisMetadata?.rulesTriggered ?? [],
            dataSources: ["Archie Backend API"]
        )
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        let attosecondsPerSecond = 1_000_000_000_000_000_000.0
        return Double(components.seconds) + Double(components.attoseconds) / attosecondsPerSecond
    }
}

// MARK: - Helpers
private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
