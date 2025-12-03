//
//  BackendAnalysisService.swift
//  SafeSnap
//
//  Analysis service that uses the SafeSnap backend API
//  Replaces direct Gemini/Vision API calls
//

import Foundation
import UIKit

// MARK: - Backend Analysis Service

/// Analysis service that delegates to the SafeSnap backend API
/// This replaces direct client-side Gemini/Vision API calls
final class BackendAnalysisService: SafetyAnalyzing {
    
    // MARK: - Properties
    
    private let apiService: SafeSnapAPIService
    private let storageService: ImageStorageService
    private let userSession: UserSession?
    private var currentTask: Task<AnalyzedSafety, Error>?
    private var isCancelled = false
    
    // MARK: - Init
    
    init(
        apiService: SafeSnapAPIService = .shared,
        storageService: ImageStorageService = FirebaseStorageService.shared,
        userSession: UserSession? = nil
    ) {
        self.apiService = apiService
        self.storageService = storageService
        self.userSession = userSession
    }
    
    // MARK: - SafetyAnalyzing Protocol
    
    func analyzeSafetyWithExtras(
        image: UIImage,
        options: SafetyOptions,
        streamToken: @escaping (String) -> Void,
        visionLabels: [String],
        ocrHits: [String],
        visionContext: VisionContextPayload?
    ) async throws -> AnalyzedSafety {
        isCancelled = false
        streamToken("Uploading image for analysis…")
        
        // Check for cancellation
        if isCancelled || Task.isCancelled { throw CancellationError() }
        
        streamToken("Analyzing product safety…")
        
        // Call backend API
        let productAnalysis: ProductAnalysis
        do {
            productAnalysis = try await apiService.analyze(
                image: image,
                includeDogs: options.includeDogs,
                includeCats: options.includeCats,
                includeChildren: options.includeChildren
            )
        } catch {
            if isCancelled { throw CancellationError() }
            throw error
        }
        
        if isCancelled || Task.isCancelled { throw CancellationError() }
        
        streamToken("Processing results…")
        
        // Convert ProductAnalysis to SafetyAnalysisResponse for backward compatibility
        let response = convertToSafetyAnalysisResponse(productAnalysis, options: options)
        
        // Build extras from analysis metadata
        let extras = buildExtras(from: productAnalysis, visionLabels: visionLabels, ocrHits: ocrHits)
        
        return AnalyzedSafety(response: response, extras: extras)
    }
    
    func cancelAnalysis() {
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - Conversion Helpers
    
    /// Convert ProductAnalysis (API model) to SafetyAnalysisResponse (legacy model)
    /// This maintains backward compatibility with existing UI code
    private func convertToSafetyAnalysisResponse(_ analysis: ProductAnalysis, options: SafetyOptions) -> SafetyAnalysisResponse {
        let kidSafety = analysis.analysis.kidSafety
        let petSafety = analysis.analysis.petSafety
        
        // Extract dog warnings as PetWarning array
        let dogWarnings: [SafetyAnalysisResponse.PetWarning] = petSafety.dogs?.details?.map { detail in
            SafetyAnalysisResponse.PetWarning(
                severity: Severity(rawValue: detail.severity.rawValue) ?? .medium,
                warning: detail.warning,
                reason: detail.reason
            )
        } ?? []
        
        // Extract cat warnings as PetWarning array
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
    
    /// Build AnalysisExtras from ProductAnalysis metadata
    private func buildExtras(from analysis: ProductAnalysis, visionLabels: [String], ocrHits: [String]) -> AnalysisExtras {
        let metadata = analysis.analysisMetadata
        
        return AnalysisExtras(
            evidence: SafetyEvidence(
                labels: visionLabels,
                ocrHits: ocrHits
            ),
            policy: PolicyOutcome(
                canonicalCategory: metadata?.canonicalCategory ?? analysis.category,
                rulesTriggered: metadata?.rulesTriggered ?? []
            )
        )
    }
}

// MARK: - API History Item Conversion

extension BackendAnalysisService {
    
    /// Convert ProductAnalysis to APIHistoryItem for saving to backend
    static func makeHistoryItem(
        from analysis: ProductAnalysis,
        imageUrl: String?,
        options: SafetyOptions
    ) -> SafeSnapAPIService.APIHistoryItem {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return SafeSnapAPIService.APIHistoryItem(
            id: analysis.id,
            createdAt: dateFormatter.string(from: Date()),
            name: analysis.name,
            score: analysis.safetyScore.overall,
            maxScore: analysis.safetyScore.maxScore,
            preview: nil,
            imageUrl: imageUrl,
            labels: [],  // Labels are already embedded in the analysis
            category: analysis.category,
            petSafetyOptions: PetSafetyOptions(
                includeDogs: options.includeDogs,
                includeCats: options.includeCats,
                includeChildren: options.includeChildren
            ),
            fullAnalysis: analysis
        )
    }
}

