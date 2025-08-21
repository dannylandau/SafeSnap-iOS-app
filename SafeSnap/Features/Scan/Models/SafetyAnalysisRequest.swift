//
//  SafetyAnalysisRequest.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 20/08/2025.
//


//  Models/SafetyAnalysis.swift
//  Defines the shared request/response contract used by OpenAIService
//  Generated to align with the web implementation

import Foundation

/// Mirrors the web SafetyAnalysisRequest
public struct SafetyAnalysisRequest: Codable, Equatable {
    public let productName: String
    public let productType: String
    public let includeDogs: Bool
    public let includeCats: Bool
    public let includeChildren: Bool

    public init(productName: String,
                productType: String,
                includeDogs: Bool,
                includeCats: Bool,
                includeChildren: Bool) {
        self.productName = productName
        self.productType = productType
        self.includeDogs = includeDogs
        self.includeCats = includeCats
        self.includeChildren = includeChildren
    }
}

/// Severity levels used across multiple sections
public enum Severity: String, Codable, CaseIterable {
    case low
    case medium
    case high
}
