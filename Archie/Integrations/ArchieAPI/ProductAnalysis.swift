//
//  ProductAnalysis.swift
//  Archie
//
//  API response model for product safety analysis
//  Matches the backend API specification
//

import Foundation

// MARK: - Main Analysis Response

/// Main response from POST /api/analyze
/// Also used for sharing and history
public struct ProductAnalysis: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let image: String  // Base64 image or URL from backend
    public let imageUrl: String?  // Firebase Storage URL (legacy)
    public let safetyScore: SafetyScore
    public let category: String
    public let recognitionStatus: RecognitionStatus?
    public let analysis: SafetyAnalysis
    public let petSafetyOptions: PetSafetyOptions?
    public let analysisMetadata: AnalysisMetadata?
    
    /// When true, this is a "Vibe Check" (humor mode) analysis for non-safety items
    /// like rugs, curtains, selfies, pets, etc. UI should show playful labels instead of safety warnings.
    /// Derived from analysisMetadata.isHumorMode
    public var isHumorMode: Bool {
        analysisMetadata?.isHumorMode ?? false
    }
    
    public init(
        id: String,
        name: String,
        image: String = "",
        imageUrl: String? = nil,
        safetyScore: SafetyScore,
        category: String,
        recognitionStatus: RecognitionStatus? = .success,
        analysis: SafetyAnalysis,
        petSafetyOptions: PetSafetyOptions? = nil,
        analysisMetadata: AnalysisMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.imageUrl = imageUrl
        self.safetyScore = safetyScore
        self.category = category
        self.recognitionStatus = recognitionStatus
        self.analysis = analysis
        self.petSafetyOptions = petSafetyOptions
        self.analysisMetadata = analysisMetadata
    }
}

// MARK: - Safety Score

public struct SafetyScore: Codable, Equatable {
    public let overall: Int  // 0-100
    public let maxScore: Int  // Always 100
    
    public init(overall: Int, maxScore: Int = 100) {
        self.overall = overall
        self.maxScore = maxScore
    }
}

// MARK: - Recognition Status

public enum RecognitionStatus: String, Codable, Equatable {
    case success
    case failed
}

// MARK: - Safety Analysis

public struct SafetyAnalysis: Codable, Equatable {
    public let kidSafety: KidSafety
    public let petSafety: PetSafetyAnalysis
    public let hygiene: HygieneAnalysis
    public let generalSafety: GeneralSafetyAnalysis?
    public let recalls: [RecallInfo]
    
    public init(
        kidSafety: KidSafety,
        petSafety: PetSafetyAnalysis,
        hygiene: HygieneAnalysis,
        generalSafety: GeneralSafetyAnalysis? = nil,
        recalls: [RecallInfo] = []
    ) {
        self.kidSafety = kidSafety
        self.petSafety = petSafety
        self.hygiene = hygiene
        self.generalSafety = generalSafety
        self.recalls = recalls
    }
}

// MARK: - Kid Safety

public struct KidSafety: Codable, Equatable {
    public let status: SafetyStatus
    public let score: Int?  // 0-100
    public let benefits: [String]
    public let concerns: [String]
    public let narrative: String?
    
    public init(
        status: SafetyStatus,
        score: Int? = nil,
        benefits: [String] = [],
        concerns: [String] = [],
        narrative: String? = nil
    ) {
        self.status = status
        self.score = score
        self.benefits = benefits
        self.concerns = concerns
        self.narrative = narrative
    }
}

// MARK: - Pet Safety Analysis

public struct PetSafetyAnalysis: Codable, Equatable {
    public let dogs: PetSafetyItem?
    public let cats: PetSafetyItem?
    
    public init(dogs: PetSafetyItem? = nil, cats: PetSafetyItem? = nil) {
        self.dogs = dogs
        self.cats = cats
    }
}

public struct PetSafetyItem: Codable, Equatable {
    public let status: SafetyStatus
    public let score: Int?  // 0-100
    public let warnings: [String]
    public let pros: [String]?
    public let cons: [String]?
    public let narrative: String?
    public let details: [PetSafetyDetail]?
    
    public init(
        status: SafetyStatus,
        score: Int? = nil,
        warnings: [String] = [],
        pros: [String]? = nil,
        cons: [String]? = nil,
        narrative: String? = nil,
        details: [PetSafetyDetail]? = nil
    ) {
        self.status = status
        self.score = score
        self.warnings = warnings
        self.pros = pros
        self.cons = cons
        self.narrative = narrative
        self.details = details
    }
}

public struct PetSafetyDetail: Codable, Equatable {
    public let severity: SeverityLevel
    public let warning: String
    public let reason: String
    
    public init(severity: SeverityLevel, warning: String, reason: String) {
        self.severity = severity
        self.warning = warning
        self.reason = reason
    }
}

// MARK: - Safety Status

public enum SafetyStatus: String, Codable, Equatable {
    case safe
    case warning
    case danger
    case info  // Used when analysis was not performed (e.g., pet safety skipped)
}

// MARK: - Severity Level

public enum SeverityLevel: String, Codable, Equatable {
    case low
    case medium
    case high
}

// MARK: - Hygiene Analysis

public struct HygieneAnalysis: Codable, Equatable {
    public let recommendations: [String]
    public let warnings: [HygieneWarning]?
    
    public init(recommendations: [String] = [], warnings: [HygieneWarning]? = nil) {
        self.recommendations = recommendations
        self.warnings = warnings
    }
}

public struct HygieneWarning: Codable, Equatable, Identifiable {
    public let id: String
    public let type: String
    public let message: String
    
    public init(id: String = UUID().uuidString, type: String, message: String) {
        self.id = id
        self.type = type
        self.message = message
    }
}

// MARK: - General Safety Analysis

public struct GeneralSafetyAnalysis: Codable, Equatable {
    public let pros: [SafetyPoint]
    public let cons: [SafetyPoint]
    
    public init(pros: [SafetyPoint] = [], cons: [SafetyPoint] = []) {
        self.pros = pros
        self.cons = cons
    }
}

public struct SafetyPoint: Codable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let severity: String
    public let category: String
    
    public init(id: String = UUID().uuidString, label: String, severity: String, category: String) {
        self.id = id
        self.label = label
        self.severity = severity
        self.category = category
    }
}

// MARK: - Recall Info

public struct RecallInfo: Codable, Equatable, Identifiable {
    public let id: String
    public let date: String
    public let reason: String
    public let severity: String
    public let source: String
    
    public init(id: String = UUID().uuidString, date: String, reason: String, severity: String, source: String) {
        self.id = id
        self.date = date
        self.reason = reason
        self.severity = severity
        self.source = source
    }
}

// MARK: - Pet Safety Options

public struct PetSafetyOptions: Codable, Equatable {
    public let includeDogs: Bool
    public let includeCats: Bool
    public let includeChildren: Bool
    
    public init(includeDogs: Bool = true, includeCats: Bool = true, includeChildren: Bool = true) {
        self.includeDogs = includeDogs
        self.includeCats = includeCats
        self.includeChildren = includeChildren
    }
}

// MARK: - Analysis Metadata

public struct AnalysisMetadata: Codable, Equatable {
    public let scanDuration: Double?
    public let canonicalCategory: String?
    public let rulesTriggered: [String]?
    public let childSafetyScore: Int?
    public let dogSafetyScore: Int?
    public let catSafetyScore: Int?
    public let modelConfidence: Double?
    public let recognitionConfidence: Double?
    public let subjectType: String?
    
    /// When true, this is a "Vibe Check" (humor mode) analysis for non-safety items
    /// like rugs, curtains, selfies, pets, etc.
    public let isHumorMode: Bool?
    
    public init(
        scanDuration: Double? = nil,
        canonicalCategory: String? = nil,
        rulesTriggered: [String]? = nil,
        childSafetyScore: Int? = nil,
        dogSafetyScore: Int? = nil,
        catSafetyScore: Int? = nil,
        modelConfidence: Double? = nil,
        recognitionConfidence: Double? = nil,
        subjectType: String? = nil,
        isHumorMode: Bool? = nil
    ) {
        self.scanDuration = scanDuration
        self.canonicalCategory = canonicalCategory
        self.rulesTriggered = rulesTriggered
        self.childSafetyScore = childSafetyScore
        self.dogSafetyScore = dogSafetyScore
        self.catSafetyScore = catSafetyScore
        self.modelConfidence = modelConfidence
        self.recognitionConfidence = recognitionConfidence
        self.subjectType = subjectType
        self.isHumorMode = isHumorMode
    }
}

// MARK: - Convenience Extensions

extension ProductAnalysis {
    /// Overall safety score as 0-10 scale
    public var overallScore10: Int {
        Int(round(Double(safetyScore.overall) / 10.0))
    }
    
    /// Child safety score from metadata or kid safety analysis
    public var childSafetyScore: Int {
        analysisMetadata?.childSafetyScore ?? analysis.kidSafety.score ?? safetyScore.overall
    }
    
    /// Dog safety score from metadata or pet safety analysis
    public var dogSafetyScore: Int? {
        analysisMetadata?.dogSafetyScore ?? analysis.petSafety.dogs?.score
    }
    
    /// Cat safety score from metadata or pet safety analysis
    public var catSafetyScore: Int? {
        analysisMetadata?.catSafetyScore ?? analysis.petSafety.cats?.score
    }
    
    /// Create a copy with imageUrl updated (for sharing)
    public func withImageUrl(_ url: String) -> ProductAnalysis {
        ProductAnalysis(
            id: id,
            name: name,
            image: "",  // Clear base64 for sharing
            imageUrl: url,
            safetyScore: safetyScore,
            category: category,
            recognitionStatus: recognitionStatus,
            analysis: analysis,
            petSafetyOptions: petSafetyOptions,
            analysisMetadata: analysisMetadata
        )
    }

}
