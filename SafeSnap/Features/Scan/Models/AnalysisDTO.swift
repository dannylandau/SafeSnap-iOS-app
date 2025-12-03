//
//  AnalysisDTO.swift
//  SafeSnap
//
//  UI-focused data transfer objects for analysis results
//

import Foundation

// MARK: - Analysis Stage

/// Stages of the analysis pipeline (for UI progress indication)
public enum AnalysisStage: String {
    case vision = "Vision"
    case fast = "FAST (LLM)"
    case smart = "SMART (LLM)"
}

// MARK: - Legacy Namespace

/// Backward compatibility - prefer AnalysisStage directly
public enum SafetyAnalyzer {
    public typealias Stage = AnalysisStage
}

// MARK: - Safety Evidence

/// Evidence gathered during analysis (labels, OCR)
public struct SafetyEvidence: Sendable {
    public var labels: [String]
    public var ocrHits: [String]
    
    public init(labels: [String], ocrHits: [String]) {
        self.labels = labels
        self.ocrHits = ocrHits
    }
}

// MARK: - Policy Outcome

/// Policy evaluation results
public struct PolicyOutcome: Sendable {
    public var canonicalCategory: String?
    public var rulesTriggered: [String]
    
    public init(canonicalCategory: String?, rulesTriggered: [String]) {
        self.canonicalCategory = canonicalCategory
        self.rulesTriggered = rulesTriggered
    }
}

// MARK: - Analysis Extras

/// Additional analysis metadata for explainability
public struct AnalysisExtras: Sendable {
    public var evidence: SafetyEvidence
    public var policy: PolicyOutcome
    
    public init(evidence: SafetyEvidence, policy: PolicyOutcome) {
        self.evidence = evidence
        self.policy = policy
    }
}

// MARK: - Safety DTO

/// UI-friendly container for ResultView/ViewModel
public struct SafetyDTO: Sendable {
    
    public struct PetWarning: Sendable {
        public let severity: String
        public let title: String
        public let reason: String
        
        public init(severity: String, title: String, reason: String) {
            self.severity = severity
            self.title = title
            self.reason = reason
        }
    }
    
    public let productName: String
    public let canonicalCategory: String?
    public let childScore: Int
    public let dogScore: Int?
    public let catScore: Int?
    public let childConfidence: Int?
    public let dogConfidence: Int?
    public let catConfidence: Int?
    public let kidPros: [String]
    public let kidCons: [String]
    public let kidNarrative: String?
    public let dogPros: [String]
    public let dogCons: [String]
    public let dogNarrative: String?
    public let catPros: [String]
    public let catCons: [String]
    public let catNarrative: String?
    public let dogWarnings: [PetWarning]
    public let catWarnings: [PetWarning]
    public let labels: [String]
    public let ocrHits: [String]
    public let rulesTriggered: [String]
    public let dataSources: [String]
    
    public init(
        productName: String,
        canonicalCategory: String?,
        childScore: Int,
        dogScore: Int?,
        catScore: Int?,
        childConfidence: Int?,
        dogConfidence: Int?,
        catConfidence: Int?,
        kidPros: [String],
        kidCons: [String],
        kidNarrative: String?,
        dogPros: [String],
        dogCons: [String],
        dogNarrative: String?,
        catPros: [String],
        catCons: [String],
        catNarrative: String?,
        dogWarnings: [PetWarning],
        catWarnings: [PetWarning],
        labels: [String],
        ocrHits: [String],
        rulesTriggered: [String],
        dataSources: [String]
    ) {
        self.productName = productName
        self.canonicalCategory = canonicalCategory
        self.childScore = childScore
        self.dogScore = dogScore
        self.catScore = catScore
        self.childConfidence = childConfidence
        self.dogConfidence = dogConfidence
        self.catConfidence = catConfidence
        self.kidPros = kidPros
        self.kidCons = kidCons
        self.kidNarrative = kidNarrative
        self.dogPros = dogPros
        self.dogCons = dogCons
        self.dogNarrative = dogNarrative
        self.catPros = catPros
        self.catCons = catCons
        self.catNarrative = catNarrative
        self.dogWarnings = dogWarnings
        self.catWarnings = catWarnings
        self.labels = labels
        self.ocrHits = ocrHits
        self.rulesTriggered = rulesTriggered
        self.dataSources = dataSources
    }
}

// MARK: - Analyzed Safety Result

/// Combined result of safety analysis with extras
public struct AnalyzedSafety: Sendable {
    public let response: SafetyAnalysisResponse
    public let extras: AnalysisExtras
    
    public init(response: SafetyAnalysisResponse, extras: AnalysisExtras) {
        self.response = response
        self.extras = extras
    }
}

// MARK: - Legacy Type Aliases

/// Backward compatibility alias - prefer SafetyDTO for new code
public typealias GeminiSafetyDTO = SafetyDTO

