//
//  SafetyAnalyzer.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 01/09/2025.
//

import CoreGraphics

public enum PetPreference: Codable, Equatable {
    case none
    case dog
    case cat
    case both // optional: if UI supports showing “pet overall”
}

public final class SafetyAnalyzer {
    private let vision: VisionServiceType
    private let openAI: OpenAIServiceType

    // Tunables
    private let VISION_HIGH = 0.82
    private let MODEL_CONF_OK = 0.78
    private let FAST_TIMEOUT: Duration = .seconds(6)
    private let SMART_TIMEOUT: Duration = .seconds(15)

    public init(vision: VisionServiceType, openAI: OpenAIServiceType) {
        self.vision = vision
        self.openAI = openAI
    }

    public struct Options {
        public let includePetSafety: Bool
        public let petPreference: PetPreference
        public init(includePetSafety: Bool, petPreference: PetPreference = .none) {
            self.includePetSafety = includePetSafety
            self.petPreference = petPreference
        }
    }

    public enum AnalyzerError: Error { case recognitionFailed, llmFailed(Error) }

    public func run(image: CGImage, options: Options) async throws -> SafetyAnalysisResponse {
        // 1) Recognize with Vision
        let guess = try await vision.recognizeProduct(from: image)
        guard !guess.name.isEmpty else { throw AnalyzerError.recognitionFailed }

        // 2) First pass with FAST model (with a single retry)
        let fastResult = try await Self.withRetry(times: 1) {
            try await self.openAI.analyzeSafety(
                input: .init(guess: guess, includePetSafety: options.includePetSafety, petPreference: options.petPreference),
                tier: .fast,
                timeout: self.FAST_TIMEOUT
            )
        }

        var (resp, modelConf) = fastResult

        // 3) Decide whether to escalate
        let shouldEscalate = (guess.confidence < VISION_HIGH) || (modelConf < MODEL_CONF_OK)

        if shouldEscalate {
            let (betterResp, betterConf) = try await openAI.analyzeSafety(
                input: .init(guess: guess, includePetSafety: options.includePetSafety, petPreference: options.petPreference),
                tier: .smart,
                timeout: SMART_TIMEOUT
            )
            resp = betterResp
            modelConf = betterConf
        }

        var enriched = resp
        enriched.recognitionConfidence = guess.confidence
        enriched.modelConfidence = modelConf

        return enriched
    }

    // MARK: - Small retry helper with exponential backoff
    private static func withRetry<T>(
        times: Int,
        delayBaseMs: UInt64 = 250,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 0
        while true {
            do { return try await operation() }
            catch {
                if attempt >= times { throw error }
                let backoff = UInt64(pow(2.0, Double(attempt))) * delayBaseMs
                try? await Task.sleep(nanoseconds: backoff * 1_000_000)
                attempt += 1
            }
        }
    }
}
