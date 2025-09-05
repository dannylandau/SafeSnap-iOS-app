//
//  ModelTier.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 01/09/2025.
//

import CoreGraphics

public enum ModelTier { case fast, smart }

public struct SafetyAnalysisInput: Codable, Equatable {
    public let guess: ProductGuess
    public let petPreference: PetPreference
}

public struct ProductGuess: Codable, Equatable {
    public let name: String
    public let type: String
    public let confidence: Double // 0.0–1.0
    public let brand: String?
}
