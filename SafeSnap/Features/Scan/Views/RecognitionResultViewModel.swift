//
//  RecognitionResultViewModel.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import SwiftUI
import UIKit

// MARK: — ViewModel
struct RecognitionResultViewModel: Identifiable {
    let id = UUID()
    let image: UIImage?
    let productName, category: String
    let score: Int
    let safetyLabel: String
    let safeBenefits, safetyConcerns, dataSources: [String]
    let date: Date
    // Keep the structured response
    let analysis: SafetyAnalysisResponse
    let includeDogs: Bool
    let includeCats: Bool
    
    // ResultView needs these:
    var dogWarnings: [(severity: String, warning: String, reason: String)] {
        analysis.petSafety.dogs.map { ($0.severity.rawValue, $0.warning, $0.reason) }
    }
    var catWarnings: [(severity: String, warning: String, reason: String)] {
        analysis.petSafety.cats.map { ($0.severity.rawValue, $0.warning, $0.reason) }
    }
}

extension RecognitionResultViewModel {
    init(image: UIImage?, from item: ScanHistoryItem) {
        self.init(
            image: image,
            productName: item.productName,
            category: item.categoryName,
            score: item.analysis.overallSafetyScore,
            safetyLabel: RecognitionResultViewModel.label(for: item.analysis.overallSafetyScore),
            safeBenefits: item.analysis.generalSafety.pros.map { $0.label },
            safetyConcerns: item.analysis.generalSafety.cons.map { $0.label },
            dataSources: item.analysis.recalls.map { $0.source },
            date: item.createdAt,
            analysis: item.analysis,
            includeDogs: item.userToggles.includeDogs,
            includeCats: item.userToggles.includeCats
        )
    }

    static func label(for score: Int) -> String {
        switch score {
        case 9...10: return "Very Safe"
        case 7...8:  return "Safe"
        case 5...6:  return "Use with Care"
        case 3...4:  return "Risky"
        default:     return "Dangerous"
        }
    }
}
