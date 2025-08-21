//
//  ScanHistoryItem.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//


//  Models/ScanHistoryItem.swift
import Foundation

public struct ScanHistoryItem: Codable, Identifiable, Equatable {
    // Identity
    public let id: UUID
    public let createdAt: Date
    public let schemaVersion: Int

    // Input
    public let imageRef: URL?
    public let imageHash: String
    public let userToggles: UserToggles

    // Vision snapshot (distilled)
    public let productName: String
    public let productType: String
    public let categoryName: String
    public let brand: String?
    public let confidence: Double
    public let signalsSummary: SignalsSummary
    public let visionContextRef: URL? // optional externalized sanitized JSON

    // OpenAI snapshot (structured)
    public let analysis: SafetyAnalysisResponse
    public let model: String
    public let promptVersion: String

    // Provenance
    public let appVersion: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        schemaVersion: Int = 1,
        imageRef: URL?,
        imageHash: String,
        userToggles: UserToggles,
        productName: String,
        productType: String,
        categoryName: String,
        brand: String?,
        confidence: Double,
        signalsSummary: SignalsSummary,
        visionContextRef: URL?,
        analysis: SafetyAnalysisResponse,
        model: String,
        promptVersion: String,
        appVersion: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
        self.imageRef = imageRef
        self.imageHash = imageHash
        self.userToggles = userToggles
        self.productName = productName
        self.productType = productType
        self.categoryName = categoryName
        self.brand = brand
        self.confidence = confidence
        self.signalsSummary = signalsSummary
        self.visionContextRef = visionContextRef
        self.analysis = analysis
        self.model = model
        self.promptVersion = promptVersion
        self.appVersion = appVersion
    }

    public struct UserToggles: Codable, Equatable {
        public let includeDogs: Bool
        public let includeCats: Bool
        public let includeChildren: Bool
        public init(includeDogs: Bool, includeCats: Bool, includeChildren: Bool) {
            self.includeDogs = includeDogs
            self.includeCats = includeCats
            self.includeChildren = includeChildren
        }
    }

    public struct SignalsSummary: Codable, Equatable {
        public let labels: [String]      // top 5
        public let objects: [String]     // top 3
        public let webEntities: [String] // top 5
        public let bestGuess: String?
        public let detectedTextExcerpt: String?
        public init(labels: [String], objects: [String], webEntities: [String], bestGuess: String?, detectedTextExcerpt: String?) {
            self.labels = labels
            self.objects = objects
            self.webEntities = webEntities
            self.bestGuess = bestGuess
            self.detectedTextExcerpt = detectedTextExcerpt
        }
    }
}
