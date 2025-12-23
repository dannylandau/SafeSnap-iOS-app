//
//  ShareService.swift
//  Archie
//
//  Handles sharing analysis results via shareable URLs
//

import Foundation
import UIKit

// MARK: - Share Service Error

enum ShareServiceError: LocalizedError {
    case noAnalysisId
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .noAnalysisId:
            return "No analysis ID available for sharing"
        case .invalidURL:
            return "Failed to generate share URL"
        }
    }
}

// MARK: - Share Result

struct ShareResult {
    let shareURL: URL
    let shareText: String
    let analysisId: String
}

// MARK: - Share Service

/// Service for generating shareable URLs and text for Archie analysis results.
/// The backend already stores the analysis when it's created, so we just need
/// to generate the URL from the analysis ID.
@MainActor
final class ShareService: ObservableObject {
    
    // MARK: - Constants
    
    private static let webBaseURL = "https://archieml.com"
    private static let maxScore = 10
    
    // MARK: - Properties
    
    @Published var isSharing: Bool = false
    @Published var shareError: ShareServiceError?
    
    // MARK: - Init
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Generate share URL and text from a ProductAnalysis
    /// - Parameter analysis: The backend-returned ProductAnalysis with human-readable ID
    /// - Returns: ShareResult with URL and formatted text
    func generateShareContent(for analysis: ProductAnalysis) throws -> ShareResult {
        let analysisId = analysis.id
        
        guard !analysisId.isEmpty else {
            throw ShareServiceError.noAnalysisId
        }
        
        guard let shareURL = URL(string: "\(Self.webBaseURL)/share/\(analysisId)") else {
            throw ShareServiceError.invalidURL
        }
        
        // Format: "Archie result for {name}: {score}/10"
        // Convert from 0-100 scale to 0-10 scale (rounded)
        let score = (analysis.safetyScore.overall + 5) / 10
        let shareText = "Archie result for \(analysis.name): \(score)/\(Self.maxScore)"
        
        return ShareResult(
            shareURL: shareURL,
            shareText: shareText,
            analysisId: analysisId
        )
    }
    
    /// Generate share URL from an analysis ID directly
    /// - Parameter analysisId: The human-readable analysis ID (e.g., "apple-1765366977421")
    /// - Returns: The share URL
    func generateShareURL(for analysisId: String) -> URL? {
        guard !analysisId.isEmpty else { return nil }
        return URL(string: "\(Self.webBaseURL)/share/\(analysisId)")
    }
    
    /// Format share text for an analysis
    /// - Parameters:
    ///   - name: Product name
    ///   - score: Overall safety score (0-10)
    /// - Returns: Formatted share text
    func formatShareText(name: String, score: Int) -> String {
        "Archie result for \(name): \(score)/\(Self.maxScore)"
    }
}
