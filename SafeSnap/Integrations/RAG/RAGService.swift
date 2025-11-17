//
//  RAGService.swift
//  SafeSnap
//

import Foundation
import UIKit

/// Lightweight toxicity lookup that feeds the backend best-guess label from Google Vision
/// and converts the response into a SafetyAnalysisResponse for the UI.
final class RAGService: SafetyAnalyzing {
    private struct BackendInterpretation {
        var summary: String
        var warnings: [String]
        var recommendation: String?
        var severityLabel: String?
        var score: Double?
        var canonicalCategory: String?
    }

    private let endpoint: URL
    private let session: URLSession
    private var currentTask: URLSessionDataTask?

    init(
        endpoint: URL = URL(string: "https://checktoxicity-l3eu4oj46a-uc.a.run.app")!,
        configuration: URLSessionConfiguration = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 45
            config.timeoutIntervalForResource = 60
            return config
        }()
    ) {
        self.endpoint = endpoint
        self.session = URLSession(configuration: configuration)
    }

    func analyzeSafetyWithExtras(
        image: UIImage,
        options: SafetyOptions,
        streamToken: @escaping (String) -> Void,
        visionLabels: [String],
        ocrHits: [String],
        visionContext: VisionContextPayload?
    ) async throws -> AnalyzedSafety {
        let rawBestGuess = visionContext?.bestGuess?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackGuess = visionContext?.guessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let substance = (rawBestGuess?.isEmpty == false ? rawBestGuess! : fallbackGuess?.isEmpty == false ? fallbackGuess! : "unknown substance")

        streamToken("Checking \(substance) toxicity…")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["substance": substance]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let interpretation = interpretResponse(
            data: data,
            fallbackSummary: "No additional guidance was returned for \(substance)."
        )

        let responseModel = buildSafetyResponse(
            guessName: substance.capitalized,
            guessType: visionContext?.guessType ?? "Product",
            recognitionConfidence: visionContext?.confidence ?? 0.5,
            interpretation: interpretation,
            options: options
        )

        let extras = AnalysisExtras(
            evidence: SafetyEvidence(labels: visionLabels, ocrHits: ocrHits),
            policy: PolicyOutcome(
                canonicalCategory: interpretation.canonicalCategory ?? visionContext?.guessType,
                rulesTriggered: []
            )
        )

        return AnalyzedSafety(response: responseModel, extras: extras)
    }

    func cancelAnalysis() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Networking helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { [weak self] data, response, error in
                self?.currentTask = nil
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            currentTask = task
            task.resume()
        }
    }

    // MARK: - Response shaping

    private func interpretResponse(data: Data, fallbackSummary: String) -> BackendInterpretation {
        var summary = fallbackSummary
        var severity: String?
        var warnings: [String] = []
        var recommendation: String?
        var score: Double?
        var canonicalCategory: String?

        if
            let jsonObject = try? JSONSerialization.jsonObject(with: data),
            let dict = jsonObject as? [String: Any]
        {
            summary = stringValue(in: dict, keys: ["summary", "message", "response", "description"]) ?? summary
            recommendation = stringValue(in: dict, keys: ["recommendation", "advice", "guidance"])
            canonicalCategory = stringValue(in: dict, keys: ["category", "canonicalCategory", "substance"]) ?? canonicalCategory
            severity = stringValue(in: dict, keys: ["severity", "risk", "toxicity", "level"])
            score = doubleValue(in: dict, keys: ["score", "toxicity_score", "risk_score", "confidence"])
            if let arr = dict["warnings"] as? [String] {
                warnings = arr
            } else if let arr = dict["warnings"] as? [Any] {
                warnings = arr.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            } else if let warn = stringValue(in: dict, keys: ["warning", "note"]) {
                warnings = [warn]
            }
        } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            summary = text
        }

        warnings = warnings.filter { !$0.isEmpty }

        return BackendInterpretation(
            summary: summary.isEmpty ? fallbackSummary : summary,
            warnings: warnings,
            recommendation: recommendation,
            severityLabel: severity,
            score: score,
            canonicalCategory: canonicalCategory
        )
    }

    private func buildSafetyResponse(
        guessName: String,
        guessType: String,
        recognitionConfidence: Double,
        interpretation: BackendInterpretation,
        options: SafetyOptions
    ) -> SafetyAnalysisResponse {
        let childScore = safetyScore(from: interpretation)
        let warnings = interpretation.warnings.isEmpty
            ? ["Keep \(guessName.lowercased()) out of reach of unsupervised children."]
            : interpretation.warnings
        let pros = interpretation.recommendation ?? "No severe toxicity indicators detected for \(guessName)."
        let summary = interpretation.summary

        let generalPros = [
            SafetyAnalysisResponse.LabeledItem(
                label: pros,
                severity: .low,
                category: "guidance"
            )
        ]
        let generalCons = warnings.map {
            SafetyAnalysisResponse.LabeledItem(
                label: $0,
                severity: severity(from: interpretation.severityLabel),
                category: "toxicity"
            )
        }

        let dogWarnings: [SafetyAnalysisResponse.PetWarning] =
            options.includeDogs ? warnings.map { .init(severity: .medium, warning: $0, reason: "Flagged by toxicity service.") } : []
        let catWarnings: [SafetyAnalysisResponse.PetWarning] =
            options.includeCats ? warnings.map { .init(severity: .medium, warning: $0, reason: "Flagged by toxicity service.") } : []

        return SafetyAnalysisResponse(
            productName: guessName,
            productType: interpretation.canonicalCategory ?? guessType,
            overallSafetyScore: childScore,
            childSafetyScore: childScore,
            dogSafetyScore: options.includeDogs ? max(childScore - 5, 0) : nil,
            catSafetyScore: options.includeCats ? max(childScore - 5, 0) : nil,
            modelConfidence: 0.65,
            recognitionConfidence: recognitionConfidence,
            generalSafety: .init(pros: generalPros, cons: generalCons),
            petSafety: .init(dogs: dogWarnings, cats: catWarnings),
            hygieneWarnings: [],
            recalls: [],
            kidPros: [pros],
            kidCons: warnings,
            kidNarrative: summary,
            dogPros: options.includeDogs ? ["Offer only tiny samples after consulting your vet."] : nil,
            dogCons: options.includeDogs ? warnings : nil,
            dogNarrative: options.includeDogs ? summary : nil,
            catPros: options.includeCats ? ["Offer only tiny samples after consulting your vet."] : nil,
            catCons: options.includeCats ? warnings : nil,
            catNarrative: options.includeCats ? summary : nil
        )
    }

    private func safetyScore(from interpretation: BackendInterpretation) -> Int {
        if let score = interpretation.score {
            let normalized: Double
            if score > 1 {
                normalized = min(max(score / 100.0, 0), 1)
            } else {
                normalized = min(max(score, 0), 1)
            }
            let inverted = 1 - normalized
            return Int((inverted * 100).rounded()).clamped(to: 0...100)
        }
        if let severity = interpretation.severityLabel?.lowercased() {
            switch severity {
            case "low":
                return 85
            case "medium", "moderate":
                return 55
            case "high":
                return 25
            default:
                break
            }
        }
        return 60
    }

    private func severity(from label: String?) -> Severity {
        guard let text = label?.lowercased() else { return .medium }
        switch text {
        case "low":
            return .low
        case "high":
            return .high
        default:
            return .medium
        }
    }

    private func stringValue(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func doubleValue(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dict[key] as? Double {
                return value
            }
            if let value = dict[key] as? Int {
                return Double(value)
            }
            if let string = dict[key] as? String, let value = Double(string) {
                return value
            }
        }
        return nil
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
