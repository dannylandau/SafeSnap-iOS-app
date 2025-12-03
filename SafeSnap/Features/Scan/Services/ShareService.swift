//
//  ShareService.swift
//  SafeSnap
//
//  Handles sharing analysis results via the SafeSnap API
//

import Foundation
import UIKit

// MARK: - Share Service Error

enum ShareServiceError: LocalizedError {
    case noImage
    case uploadFailed(underlying: Error)
    case cacheFailed(underlying: Error)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No image available to share"
        case .uploadFailed(let error):
            return "Failed to upload image: \(error.localizedDescription)"
        case .cacheFailed(let error):
            return "Failed to prepare share link: \(error.localizedDescription)"
        case .invalidURL:
            return "Failed to generate share URL"
        }
    }
}

// MARK: - Share Result

struct ShareResult {
    let shareURL: URL
    let analysis: ProductAnalysis
}

// MARK: - Share Service

@MainActor
final class ShareService: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isSharing: Bool = false
    @Published var shareError: ShareServiceError?
    
    private let apiService: SafeSnapAPIService
    private let storageService: ImageStorageService
    
    // MARK: - Init
    
    init(
        apiService: SafeSnapAPIService = .shared,
        storageService: ImageStorageService = FirebaseStorageService.shared
    ) {
        self.apiService = apiService
        self.storageService = storageService
    }
    
    // MARK: - Public Methods
    
    /// Share an analysis result
    /// - Parameters:
    ///   - analysis: The SafetyAnalysisResponse to share
    ///   - image: Optional UIImage to include
    ///   - productName: Product name
    ///   - category: Product category
    /// - Returns: ShareResult containing the share URL
    func shareAnalysis(
        analysis: SafetyAnalysisResponse,
        image: UIImage?,
        productName: String,
        category: String
    ) async throws -> ShareResult {
        isSharing = true
        shareError = nil
        
        defer { isSharing = false }
        
        // Generate unique ID for this share
        let analysisId = "analysis_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
        
        // Upload image if available
        var imageUrl: String? = nil
        if let image = image {
            do {
                imageUrl = try await storageService.uploadAnalysisImage(image: image, analysisId: analysisId)
            } catch {
                throw ShareServiceError.uploadFailed(underlying: error)
            }
        }
        
        // Create ProductAnalysis from SafetyAnalysisResponse
        let productAnalysis = createProductAnalysis(
            id: analysisId,
            from: analysis,
            productName: productName,
            category: category,
            imageUrl: imageUrl
        )
        
        // Cache for sharing via API
        do {
            _ = try await apiService.cacheForSharing(analysis: productAnalysis)
        } catch {
            throw ShareServiceError.cacheFailed(underlying: error)
        }
        
        // Generate share URL
        guard let shareURL = apiService.generateShareURL(for: analysisId) else {
            throw ShareServiceError.invalidURL
        }
        
        return ShareResult(shareURL: shareURL, analysis: productAnalysis)
    }
    
    /// Share a ProductAnalysis directly (useful when we already have one from the API)
    func shareProductAnalysis(
        _ analysis: ProductAnalysis,
        image: UIImage?
    ) async throws -> ShareResult {
        isSharing = true
        shareError = nil
        
        defer { isSharing = false }
        
        // Upload image if provided and analysis doesn't have imageUrl
        var analysisToShare = analysis
        if let image = image, analysis.imageUrl == nil {
            do {
                let imageUrl = try await storageService.uploadAnalysisImage(image: image, analysisId: analysis.id)
                analysisToShare = analysis.withImageUrl(imageUrl)
            } catch {
                throw ShareServiceError.uploadFailed(underlying: error)
            }
        }
        
        // Cache for sharing
        do {
            _ = try await apiService.cacheForSharing(analysis: analysisToShare)
        } catch {
            throw ShareServiceError.cacheFailed(underlying: error)
        }
        
        // Generate share URL
        guard let shareURL = apiService.generateShareURL(for: analysis.id) else {
            throw ShareServiceError.invalidURL
        }
        
        return ShareResult(shareURL: shareURL, analysis: analysisToShare)
    }
    
    // MARK: - Private Helpers
    
    private func createProductAnalysis(
        id: String,
        from response: SafetyAnalysisResponse,
        productName: String,
        category: String,
        imageUrl: String?
    ) -> ProductAnalysis {
        // Convert SafetyAnalysisResponse to ProductAnalysis
        let kidSafety = KidSafety(
            status: safetyStatus(from: response.childSafetyScore),
            score: response.childSafetyScore,
            benefits: response.kidPros,
            concerns: response.kidCons,
            narrative: response.kidNarrative.isEmpty ? nil : response.kidNarrative
        )
        
        let dogs: PetSafetyItem? = response.dogSafetyScore.map { score in
            PetSafetyItem(
                status: safetyStatus(from: score),
                score: score,
                warnings: response.petSafety.dogs.map { $0.warning },
                pros: response.dogPros,
                cons: response.dogCons,
                narrative: response.dogNarrative,
                details: response.petSafety.dogs.map { warning in
                    PetSafetyDetail(
                        severity: SeverityLevel(rawValue: warning.severity.rawValue) ?? .medium,
                        warning: warning.warning,
                        reason: warning.reason
                    )
                }
            )
        }
        
        let cats: PetSafetyItem? = response.catSafetyScore.map { score in
            PetSafetyItem(
                status: safetyStatus(from: score),
                score: score,
                warnings: response.petSafety.cats.map { $0.warning },
                pros: response.catPros,
                cons: response.catCons,
                narrative: response.catNarrative,
                details: response.petSafety.cats.map { warning in
                    PetSafetyDetail(
                        severity: SeverityLevel(rawValue: warning.severity.rawValue) ?? .medium,
                        warning: warning.warning,
                        reason: warning.reason
                    )
                }
            )
        }
        
        let hygieneWarnings = response.hygieneWarnings.map { warning in
            HygieneWarning(type: warning.type, message: warning.message)
        }
        
        let recalls = response.recalls.map { recall in
            RecallInfo(
                date: recall.date,
                reason: recall.reason,
                severity: recall.severity.rawValue,
                source: recall.source
            )
        }
        
        let generalSafety = GeneralSafetyAnalysis(
            pros: response.generalSafety.pros.map { item in
                SafetyPoint(label: item.label, severity: item.severity.rawValue, category: item.category)
            },
            cons: response.generalSafety.cons.map { item in
                SafetyPoint(label: item.label, severity: item.severity.rawValue, category: item.category)
            }
        )
        
        return ProductAnalysis(
            id: id,
            name: productName,
            image: "",  // Empty for shared analysis
            imageUrl: imageUrl,
            safetyScore: SafetyScore(overall: response.overallSafetyScore),
            category: category,
            recognitionStatus: .success,
            analysis: SafetyAnalysis(
                kidSafety: kidSafety,
                petSafety: PetSafetyAnalysis(dogs: dogs, cats: cats),
                hygiene: HygieneAnalysis(recommendations: [], warnings: hygieneWarnings),
                generalSafety: generalSafety,
                recalls: recalls
            ),
            petSafetyOptions: PetSafetyOptions(
                includeDogs: response.dogSafetyScore != nil,
                includeCats: response.catSafetyScore != nil,
                includeChildren: true
            ),
            analysisMetadata: AnalysisMetadata(
                modelConfidence: response.modelConfidence,
                recognitionConfidence: response.recognitionConfidence
            )
        )
    }
    
    private func safetyStatus(from score: Int) -> SafetyStatus {
        switch score {
        case 70...100: return .safe
        case 40..<70: return .warning
        default: return .danger
        }
    }
}

