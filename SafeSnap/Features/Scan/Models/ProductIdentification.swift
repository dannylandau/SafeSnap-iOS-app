//
//  ProductIdentification.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 26/08/2025.
//


// OpenAI Models
struct ProductIdentification: Codable {
    let productType: String              // e.g., "food", "toy", "cosmetics", "electronics", "household"
    let productName: String              // canonical name user would recognize
    let brandCandidates: [String]        // ["Lego", "Duplo", ...]
    let labels: [String]                 // high-level tags the model "saw"
    let objects: [String]                // localized objects ("bottle", "power cord")
    let detectedText: String?            // OCR-like text block
    let confidence: Double               // 0.0 - 1.0
    let bestGuess: String?               // Google Vision best guess label
}
