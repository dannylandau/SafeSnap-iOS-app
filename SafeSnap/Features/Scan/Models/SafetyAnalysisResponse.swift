//
//  SafetyAnalysisResponse.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 20/08/2025.
//

import SwiftUI

/// Mirrors the web SafetyAnalysisResponse
public struct SafetyAnalysisResponse: Codable, Equatable {
    public var overallSafetyScore: Int
    public var generalSafety: GeneralSafety
    public var petSafety: PetSafety
    public var hygieneWarnings: [HygieneWarning]
    public var recalls: [Recall]

    public init(
        overallSafetyScore: Int,
        generalSafety: GeneralSafety,
        petSafety: PetSafety,
        hygieneWarnings: [HygieneWarning],
        recalls: [Recall]
    ) {
        self.overallSafetyScore = overallSafetyScore
        self.generalSafety = generalSafety
        self.petSafety = petSafety
        self.hygieneWarnings = hygieneWarnings
        self.recalls = recalls
    }

    // MARK: - Nested Types

    public struct GeneralSafety: Codable, Equatable {
        public let pros: [LabeledItem]
        public let cons: [LabeledItem]

        public init(pros: [LabeledItem], cons: [LabeledItem]) {
            self.pros = pros
            self.cons = cons
        }
    }

    public struct LabeledItem: Codable, Equatable {
        public let label: String
        public let severity: Severity
        public let category: String

        public init(label: String, severity: Severity, category: String) {
            self.label = label
            self.severity = severity
            self.category = category
        }
    }

    public struct PetSafety: Codable, Equatable {
        public let dogs: [PetWarning]
        public let cats: [PetWarning]

        public init(dogs: [PetWarning], cats: [PetWarning]) {
            self.dogs = dogs
            self.cats = cats
        }
    }

    public struct PetWarning: Codable, Equatable {
        public let severity: Severity
        public let warning: String
        public let reason: String

        public init(severity: Severity, warning: String, reason: String) {
            self.severity = severity
            self.warning = warning
            self.reason = reason
        }
    }

    public struct HygieneWarning: Codable, Equatable {
        public let type: String
        public let message: String

        public init(type: String, message: String) {
            self.type = type
            self.message = message
        }
    }

    public struct Recall: Codable, Equatable {
        public let date: String
        public let reason: String
        public let severity: Severity
        public let source: String

        public init(date: String, reason: String, severity: Severity, source: String) {
            self.date = date
            self.reason = reason
            self.severity = severity
            self.source = source
        }
    }
}

extension SafetyAnalysisResponse.PetSafety {
    var dogMaxSeverity: Severity? { dogs.map(\.severity).max(by: severityRank) }
    var catMaxSeverity: Severity? { cats.map(\.severity).max(by: severityRank) }

    var isDogSafe: Bool { dogMaxSeverity == nil || dogMaxSeverity == .low }
    var isCatSafe: Bool { catMaxSeverity == nil || catMaxSeverity == .low }
}

func severityRank(_ a: Severity, _ b: Severity) -> Bool {
    rank(a) < rank(b)
}

func rank(_ s: Severity) -> Int {
    switch s { case .low: return 0; case .medium: return 1; case .high: return 2 }
}

extension Severity {
    var color: Color {
        switch self { case .low: return .green; case .medium: return .orange; case .high: return .red }
    }
    var label: String {
        switch self { case .low: return "Low"; case .medium: return "Medium"; case .high: return "High" }
    }
}
