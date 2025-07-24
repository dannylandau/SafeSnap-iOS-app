//
//  MockImageAnalysisService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import SwiftUI

struct MockImageAnalysisService: ImageAnalysisService {
    func analyze(image: UIImage) async -> AnalysisResult {
        let resultVM = RecognitionResultViewModel(
            image: image,
            productName: "Red Apple",
            category: "Food",
            score: 9,
            safetyLabel: "Perfectly Safe",
            safeBenefits: ["No allergens"],
            safetyConcerns: ["Wash before use"],
            dataSources: ["FDA Approved", "CPSC"],
            date: Date()
        )

        let pros = [SafetyPoint(id: UUID().uuidString, label: "No allergens", severity: "low", category: "Regulatory")]
        let cons = [SafetyPoint(id: UUID().uuidString, label: "Wash before use", severity: "medium", category: "Hygiene")]

        let product = Product(
            id: UUID().uuidString,
            name: "Red Apple",
            productType: "Food",
            safetyScore: 9,
            safetyLevel: "Perfectly Safe",
            pros: pros,
            cons: cons,
            certifications: ["FDA Approved", "CPSC"],
            hygieneWarnings: []
        )

        let item = ScanHistoryItem(
            product: product,
            labels: ["Red Apple"],
            score: 9,
            thumbnail: image
        )

        return AnalysisResult(resultVM: resultVM, historyItem: item)
    }
}
