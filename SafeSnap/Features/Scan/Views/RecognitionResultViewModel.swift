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
}
