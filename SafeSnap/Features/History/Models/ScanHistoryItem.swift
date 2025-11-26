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
    /// We store only the filename (e.g., "IMG_xxx.jpg") to survive container changes across reinstalls.
    public let imageFilename: String?
    public let imageHash: String

    /// Backward-compatible computed URL built in the **current** container.
    public var imageRef: URL? {
        guard let name = imageFilename else { return nil }
        let fm = FileManager.default
        if let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let imagesDir = docs.appendingPathComponent("Images", isDirectory: true)
            return imagesDir.appendingPathComponent(name)
        }
        return nil
    }
    public let userToggles: UserToggles

    // Vision snapshot (distilled)
    public let productName: String
    public let productType: String
    public let categoryName: String
    public let brand: String?
    public let confidence: Double
    public let visionContextRef: URL? // optional externalized sanitized JSON
    public let visionBestGuess: String?
    public let visionWebEntities: [String]

    // OpenAI snapshot (structured)
    public let analysis: SafetyAnalysisResponse
    public let model: String
    public let promptVersion: String

    // Provenance
    public let appVersion: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        schemaVersion: Int = 2,
        imageFilename: String?,
        imageHash: String,
        userToggles: UserToggles,
        productName: String,
        productType: String,
        categoryName: String,
        brand: String?,
        confidence: Double,
        visionContextRef: URL?,
        visionBestGuess: String?,
        visionWebEntities: [String],
        analysis: SafetyAnalysisResponse,
        model: String,
        promptVersion: String,
        appVersion: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
        self.imageFilename = imageFilename
        self.imageHash = imageHash
        self.userToggles = userToggles
        self.productName = productName
        self.productType = productType
        self.categoryName = categoryName
        self.brand = brand
        self.confidence = confidence
        self.visionContextRef = visionContextRef
        self.visionBestGuess = visionBestGuess
        self.visionWebEntities = visionWebEntities
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
    private enum CodingKeys: String, CodingKey {
        case id, createdAt, schemaVersion
        case imageFilename
        case imageHash
        case userToggles
        case productName, productType, categoryName, brand, confidence, visionContextRef
        case visionBestGuess, visionWebEntities
        case analysis, model, promptVersion, appVersion
        // Legacy key kept for decoding only
        case imageRef
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1

        if let filename = try c.decodeIfPresent(String.self, forKey: .imageFilename) {
            self.imageFilename = filename
        } else if let legacyURL = try c.decodeIfPresent(URL.self, forKey: .imageRef) {
            self.imageFilename = legacyURL.lastPathComponent
        } else {
            self.imageFilename = nil
        }

        self.imageHash = try c.decode(String.self, forKey: .imageHash)
        self.userToggles = try c.decode(UserToggles.self, forKey: .userToggles)
        self.productName = try c.decode(String.self, forKey: .productName)
        self.productType = try c.decode(String.self, forKey: .productType)
        self.categoryName = try c.decode(String.self, forKey: .categoryName)
        self.brand = try c.decodeIfPresent(String.self, forKey: .brand)
        self.confidence = try c.decode(Double.self, forKey: .confidence)
        self.visionContextRef = try c.decodeIfPresent(URL.self, forKey: .visionContextRef)
        self.visionBestGuess = try c.decodeIfPresent(String.self, forKey: .visionBestGuess)
        self.visionWebEntities = try c.decodeIfPresent([String].self, forKey: .visionWebEntities) ?? []
        self.analysis = try c.decode(SafetyAnalysisResponse.self, forKey: .analysis)
        self.model = try c.decode(String.self, forKey: .model)
        self.promptVersion = try c.decode(String.self, forKey: .promptVersion)
        self.appVersion = try c.decode(String.self, forKey: .appVersion)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encodeIfPresent(imageFilename, forKey: .imageFilename)
        try c.encode(imageHash, forKey: .imageHash)
        try c.encode(userToggles, forKey: .userToggles)
        try c.encode(productName, forKey: .productName)
        try c.encode(productType, forKey: .productType)
        try c.encode(categoryName, forKey: .categoryName)
        try c.encodeIfPresent(brand, forKey: .brand)
        try c.encode(confidence, forKey: .confidence)
        try c.encodeIfPresent(visionContextRef, forKey: .visionContextRef)
        try c.encodeIfPresent(visionBestGuess, forKey: .visionBestGuess)
        if !visionWebEntities.isEmpty {
            try c.encode(visionWebEntities, forKey: .visionWebEntities)
        }
        try c.encode(analysis, forKey: .analysis)
        try c.encode(model, forKey: .model)
        try c.encode(promptVersion, forKey: .promptVersion)
        try c.encode(appVersion, forKey: .appVersion)
    }
}
