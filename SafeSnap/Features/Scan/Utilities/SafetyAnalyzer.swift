//
//  SafetyAnalyzer.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 01/09/2025.
//

import CoreGraphics
import Foundation

public enum PetPreference: Codable, Equatable {
    case none
    case dog
    case cat
    case both
}

public final class SafetyAnalyzer {
    private let vision: VisionServiceType
    private let openAI: OpenAIServiceType

    // Tunables
    private let VISION_OK = 0.60
    private let MODEL_CONF_OK = 0.60
    private let HYSTERESIS = 0.05
    private let CONF_FLOOR = 0.45
    private let FAST_TIMEOUT: Duration = .seconds(10)
    private let SMART_TIMEOUT: Duration = .seconds(60)
    private let OVERALL_HARD_SLA: Duration = .seconds(70)

    public init(vision: VisionServiceType, openAI: OpenAIServiceType) {
        self.vision = vision
        self.openAI = openAI
    }

    public struct Options {
        public let petPreference: PetPreference
        public init(petPreference: PetPreference = .none) {
            self.petPreference = petPreference
        }
    }

    // MARK: - Errors

    public enum Stage: String {
        case vision = "Vision"
        case fast = "FAST (LLM)"
        case smart = "SMART (LLM)"
    }

    public enum AnalyzerError: LocalizedError {
        case recognitionFailed(reason: String)
        case timedOut(stage: Stage, seconds: Int)
        case cancelled(stage: Stage)
        case network(stage: Stage, underlying: Error)
        case rateLimited(stage: Stage, retryAfterSeconds: Int?, underlying: Error)
        case server(stage: Stage, status: Int, underlying: Error)
        case invalidModelResponse(stage: Stage, reason: String)
        case other(stage: Stage, underlying: Error)

        public var errorDescription: String? {
            switch self {
            case .recognitionFailed:
                return "Couldn’t recognize the product"
            case .timedOut(let stage, let seconds):
                if stage == .smart {
                    return "Timeout reached (\(seconds)s, global SLA)"
                } else {
                    return "Timeout reached (\(seconds)s)"
                }
            case .cancelled:
                return "Operation cancelled"
            case .network:
                return "Network problem"
            case .rateLimited:
                return "Too many requests"
            case .server:
                return "Service error"
            case .invalidModelResponse:
                return "We got an unexpected answer"
            case .other:
                return "Something went wrong"
            }
        }

        public var failureReason: String? {
            switch self {
            case .recognitionFailed(let reason):
                return reason
            case .timedOut(let stage, let seconds):
                if stage == .smart {
                    return "Global analysis budget (\(seconds)s) was exhausted before SMART could complete."
                } else {
                    return "\(stage.rawValue) stage exceeded the time limit."
                }
            case .cancelled(let stage):
                return "\(stage.rawValue) stage was cancelled."
            case .network(let stage, let err):
                return "\(stage.rawValue) failed due to a network issue: \(err.localizedDescription)."
            case .rateLimited(let stage, _, _):
                return "\(stage.rawValue) was rate limited."
            case .server(let stage, let status, _):
                return "\(stage.rawValue) returned status \(status)."
            case .invalidModelResponse(let stage, let reason):
                return "\(stage.rawValue) returned invalid data: \(reason)."
            case .other(let stage, let err):
                return "\(stage.rawValue) failed: \(err.localizedDescription)."
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .recognitionFailed:
                return "Try a clearer photo with the label centered."
            case .timedOut(let stage, let seconds):
                if stage == .smart {
                    return "Try again on a faster connection or avoid escalating to SMART. You can also retry; the global \(seconds)s SLA may be enough next time if the FAST stage is stronger."
                } else {
                    return "Check your connection or try again."
                }
            case .cancelled:
                return "Tap Retry to run the analysis again."
            case .network:
                return "Check internet connectivity and retry."
            case .rateLimited:
                return "Wait a moment and try again."
            case .server:
                return "Please try again shortly."
            case .invalidModelResponse:
                return "Retry the quick check or run a deeper check."
            case .other:
                return "Please try again."
            }
        }
    }

    // MARK: - Public API

    public func run(image: CGImage, options: Options, visionGuess: ((ProductGuess) -> Void)? = nil, modelConfidence: ((Double) -> Void)? = nil, onStageChange: ((Stage) -> Void)? = nil, onStageTiming: ((Stage, Double) -> Void)? = nil) async throws -> SafetyAnalysisResponse {
        let start = ContinuousClock.now
        onStageChange?(.vision)

        let tVisionStart = ContinuousClock.now
        var tFastStart: ContinuousClock.Instant? = nil
        var tSmartStart: ContinuousClock.Instant? = nil

        // 1) Vision
        guard !Task.isCancelled else { throw AnalyzerError.cancelled(stage: .vision) }
        let guess: ProductGuess
        do {
            guess = try await vision.recognizeProduct(from: image)
        } catch is CancellationError {
            throw AnalyzerError.cancelled(stage: .vision)
        } catch {
            throw mapServiceError(error, stage: .vision)
        }
        visionGuess?(guess)
        guard !guess.name.isEmpty else {
            throw AnalyzerError.recognitionFailed(reason: "Vision returned an empty name (confidence=\(String(format: "%.2f", guess.confidence))).")
        }
        onStageTiming?(.vision, tVisionStart.duration(to: ContinuousClock.now).secondsDouble)

        // 2) FAST (with timeout + retry for transient)
        var resp: SafetyAnalysisResponse
        var modelConf: Double
        do {
            (resp, modelConf) = try await Self.withRetry(times: 1) { [weak self] in
                guard let self = self else { throw CancellationError() }
                onStageChange?(.fast)
                tFastStart = ContinuousClock.now
                return try await self.withTimeout(self.FAST_TIMEOUT, stage: .fast) { [weak self] in
                    guard let self = self else { throw CancellationError() }
                    // Return the tuple directly from analyzeSafety
                    return try await self.openAI.analyzeSafety(
                        input: .init(guess: guess, petPreference: options.petPreference),
                        tier: .fast,
                        timeout: self.FAST_TIMEOUT
                    )
                }
            }
        } catch let e as AnalyzerError {
            throw e
        }
        catch is CancellationError {
            throw AnalyzerError.cancelled(stage: .fast)
        }
        catch {
            throw mapServiceError(error, stage: .fast)
        }

        modelConfidence?(modelConf)
        
        try validate(resp, stage: .fast)

        if let tFastStart { onStageTiming?(.fast, tFastStart.duration(to: ContinuousClock.now).secondsDouble) }

        let visionConf = guess.confidence

        // 3) Escalation decision
        let visionWeak     = visionConf < max(VISION_OK - HYSTERESIS, CONF_FLOOR)
        let modelWeak      = modelConf  < max(MODEL_CONF_OK - HYSTERESIS, CONF_FLOOR)
        let eitherVeryLow  = (visionConf < CONF_FLOOR) || (modelConf < CONF_FLOOR)

        let fastHasHighSeverity =
            resp.generalSafety.cons.contains { $0.severity == .high } ||
            !resp.hygieneWarnings.isEmpty ||
            !resp.recalls.isEmpty

        let shouldEscalate =
            eitherVeryLow ||
            (visionWeak && modelWeak) ||
            (fastHasHighSeverity && (visionWeak || modelWeak))

        // Budget check before SMART
        if shouldEscalate {
            let elapsed = ContinuousClock.now - start
            let remaining = OVERALL_HARD_SLA - elapsed
            guard remaining > .seconds(5) else {
                // Not enough time left—return FAST but annotate via invalidModelResponse? No, use timeout
                throw AnalyzerError.timedOut(stage: .smart, seconds: Int(OVERALL_HARD_SLA.components.seconds))
            }

            let smartTimeout = min(SMART_TIMEOUT, remaining - .seconds(1))

            do {
                onStageChange?(.smart)
                tSmartStart = ContinuousClock.now
                (resp, modelConf) = try await withTimeout(smartTimeout, stage: .smart) { [weak self] in
                    guard let self = self else { throw CancellationError() }
                    return try await self.openAI.analyzeSafety(
                        input: .init(guess: guess, petPreference: options.petPreference),
                        tier: .smart,
                        timeout: smartTimeout
                    )
                }
                try validate(resp, stage: .smart)
            } catch let e as AnalyzerError {
                throw e
            }
            catch is CancellationError {
                throw AnalyzerError.cancelled(stage: .smart)
            }
            catch {
                throw mapServiceError(error, stage: .smart)
            }
            if let tSmartStart { onStageTiming?(.smart, tSmartStart.duration(to: ContinuousClock.now).secondsDouble) }
        }

        // 4) Enrich and return
        var enriched = resp
        enriched.recognitionConfidence = visionConf
        enriched.modelConfidence = modelConf
        return enriched
    }


    // MARK: - Validation

    private func validate(_ resp: SafetyAnalysisResponse, stage: Stage) throws {
        var reasons: [String] = []

        if resp.productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append("productName is empty")
        }
        if resp.productType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reasons.append("productType is empty")
        }
        if !(0...100).contains(resp.overallSafetyScore) {
            reasons.append("overallSafetyScore out of range: \(resp.overallSafetyScore)")
        }
        // Optional: ensure pets arrays exist when petPreference != .none is requested
        // (We validate structure rather than business logic here.)
        if !reasons.isEmpty {
            throw AnalyzerError.invalidModelResponse(stage: stage, reason: reasons.joined(separator: "; "))
        }
    }

    // MARK: - Timeout wrapper

    @discardableResult
    private func withTimeout<T>(
        _ duration: Duration,
        stage: Stage,
        _ op: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw AnalyzerError.timedOut(stage: stage, seconds: Int(duration.components.seconds))
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Retry (transient only)

    private static func withRetry<T>(
        times: Int,
        delayBaseMs: UInt64 = 250,
        jitterMs: UInt64 = 60,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 0
        var lastError: Error?
        while true {
            do {
                return try await operation()
            } catch is CancellationError {
                throw errorOr(lastError, fallback: CancellationError())
            } catch {
                lastError = error
                // Retry only transient
                if attempt >= times || !isTransient(error) { throw error }
                let pow2 = UInt64(1 << attempt)
                let backoff = (pow2 * delayBaseMs) + UInt64(Int.random(in: 0...Int(jitterMs)))
                try? await Task.sleep(nanoseconds: backoff * 1_000_000)
                attempt += 1
            }
        }
    }

    private static func errorOr(_ error: Error?, fallback: Error) -> Error {
        error ?? fallback
    }

    private static func isTransient(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return true
            default: break
            }
        }
        // Heuristic for HTTP 429/5xx if the service wraps errors in NSError’s userInfo
        if let status = ns.userInfo["HTTPStatusCode"] as? Int {
            if status == 429 || (500...599).contains(status) { return true }
        }
        return false
    }

    // MARK: - Error mapping

    private func mapServiceError(_ error: Error, stage: Stage) -> AnalyzerError {
        if error is AnalyzerError { return error as! AnalyzerError }
        if error is CancellationError { return .cancelled(stage: stage) }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return .network(stage: stage, underlying: error)
        }
        if let status = ns.userInfo["HTTPStatusCode"] as? Int {
            if status == 429 {
                let retry = ns.userInfo["RetryAfter"] as? Int
                return .rateLimited(stage: stage, retryAfterSeconds: retry, underlying: error)
            }
            if (500...599).contains(status) {
                return .server(stage: stage, status: status, underlying: error)
            }
        }
        // If your OpenAIService defines its own error types, you can downcast here
        return .other(stage: stage, underlying: error)
    }
}

extension Duration {
    var secondsDouble: Double {
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000.0
    }
}
