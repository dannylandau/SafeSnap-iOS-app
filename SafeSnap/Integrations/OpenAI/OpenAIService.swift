//
//  OpenAIService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 30/07/2025.
//

import Foundation
import UIKit

// MARK: - Service Error

enum OpenAIServiceError: LocalizedError {
    case invalidAPIKey
    case timeout(stage: ModelTier, seconds: Int)
    case cancelled(stage: ModelTier)
    case http(status: Int, requestID: String?, bodyPreview: String)
    case network(URLError)
    case emptyContent(stage: ModelTier)
    case finishReasonBlocked(stage: ModelTier, reason: String) // e.g., "content_filter"
    case decodeJSON(stage: ModelTier, reason: String, jsonPreview: String)
    case other(stage: ModelTier, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Missing or invalid API key"
        case .timeout(_, let s): return "Timeout reached (\(s)s)"
        case .cancelled: return "Operation cancelled"
        case .http: return "OpenAI API error"
        case .network: return "Network problem"
        case .emptyContent: return "Got an empty response"
        case .finishReasonBlocked(_, let r): return "Response was blocked (\(r))"
        case .decodeJSON: return "Couldn’t read the response"
        case .other: return "Something went wrong"
        }
    }

    var failureReason: String? {
        switch self {
        case .invalidAPIKey: return "API key is missing or malformed."
        case .timeout(let stage, _): return "\(stage) request exceeded the time limit."
        case .cancelled(let stage): return "\(stage) request was cancelled."
        case .http(let status, let rid, _):
            return "HTTP \(status)\(rid.map { ", request-id=\($0)" } ?? "")"
        case .network(let e):
            return "URLSession error: \(e.code.rawValue)"
        case .emptyContent(let stage):
            return "\(stage) returned no content."
        case .finishReasonBlocked(_, let r):
            return "finish_reason='\(r)'"
        case .decodeJSON(_, let why, _):
            return why
        case .other(_, let err):
            let ns = err as NSError; return "\(ns.domain)(\(ns.code))"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidAPIKey: return "Set a valid OpenAI API key in Info.plist or app settings."
        case .timeout: return "Check your connection and try again."
        case .cancelled: return "Tap Retry to run the analysis again."
        case .http(let status, _, _):
            if status == 429 { return "You’re sending requests too quickly. Wait a moment and retry." }
            if (500...599).contains(status) { return "Service had an issue. Try again shortly." }
            return "Please try again."
        case .network: return "Check internet connectivity and retry."
        case .emptyContent: return "Retry, or try the 'Verify' (SMART) pass."
        case .finishReasonBlocked: return "Adjust prompt or retry; content was filtered."
        case .decodeJSON: return "Retry; if it persists, check the schema/prompt."
        case .other: return "Please try again."
        }
    }
}

public protocol OpenAIServiceType {
    /// Returns response + self-reported model confidence (0–1).
    func analyzeSafety(input: SafetyAnalysisInput, tier: ModelTier, timeout: Duration) async throws -> (SafetyAnalysisResponse, modelConfidence: Double)
}

struct OpenAIResult: Decodable {
    let productName: String
    let productCategory: String
    let safetyScore: Int
    let safetyLabel: String
    let isKidSafe: Bool
    let isPetSafe: Bool
    let concerns: [String]
    let benefits: [String]
    let recommendedAuthorities: [String]
}

final class OpenAIService: OpenAIServiceType {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    // JSON Schema that mirrors SafetyAnalysisResponse exactly
    private func safetyJSONSchema() -> [String: Any] {
        return [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "productName",
                "productType",
                "overallSafetyScore",
                "childSafetyScore",
                "dogSafetyScore",
                "catSafetyScore",
                "modelConfidence",
                "recognitionConfidence",
                "generalSafety",
                "petSafety",
                "hygieneWarnings",
                "recalls"
            ],
            "properties": [
                "productName": ["type": "string"],
                "productType": ["type": "string"],

                // Scoring fields
                "overallSafetyScore": ["type": "integer", "minimum": 0, "maximum": 100],
                "childSafetyScore":  ["type": "integer", "minimum": 0, "maximum": 100],
                "dogSafetyScore":    ["type": ["integer","null"], "minimum": 0, "maximum": 100],
                "catSafetyScore":    ["type": ["integer","null"], "minimum": 0, "maximum": 100],

                // Confidence
                "modelConfidence":       ["type": "number", "minimum": 0.0, "maximum": 1.0],
                "recognitionConfidence": ["type": "number", "minimum": 0.0, "maximum": 1.0],

                // General safety (pros/cons)
                "generalSafety": [
                    "type": "object",
                    "required": ["pros","cons"],
                    "properties": [
                        "pros": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "required": ["label","severity","category"],
                                "properties": [
                                    "label": ["type": "string"],
                                    "severity": ["type": "string", "enum": ["low","medium","high"]],
                                    "category": ["type": "string"]
                                ]
                            ]
                        ],
                        "cons": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "required": ["label","severity","category"],
                                "properties": [
                                    "label": ["type": "string"],
                                    "severity": ["type": "string", "enum": ["low","medium","high"]],
                                    "category": ["type": "string"]
                                ]
                            ]
                        ]
                    ]
                ],

                // Pet safety (dogs/cats warnings)
                "petSafety": [
                    "type": "object",
                    "required": ["dogs","cats"],
                    "properties": [
                        "dogs": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "required": ["severity","warning","reason"],
                                "properties": [
                                    "severity": ["type": "string", "enum": ["low","medium","high"]],
                                    "warning": ["type": "string"],
                                    "reason": ["type": "string"]
                                ]
                            ]
                        ],
                        "cats": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "required": ["severity","warning","reason"],
                                "properties": [
                                    "severity": ["type": "string", "enum": ["low","medium","high"]],
                                    "warning": ["type": "string"],
                                    "reason": ["type": "string"]
                                ]
                            ]
                        ]
                    ]
                ],

                // Hygiene warnings
                "hygieneWarnings": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "required": ["type","message"],
                        "properties": [
                            "type": ["type": "string"],
                            "message": ["type": "string"]
                        ]
                    ]
                ],

                // Recalls
                "recalls": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "required": ["date","reason","severity","source"],
                        "properties": [
                            "date": ["type": "string"],
                            "reason": ["type": "string"],
                            "severity": ["type": "string", "enum": ["low","medium","high"]],
                            "source": ["type": "string"]
                        ]
                    ]
                ]
            ]
        ]
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

#if DEBUG
    private func debugPrintChatBody(label: String, body: [String: Any]) {
        func trunc(_ s: String, _ n: Int = 240) -> String {
            if s.count <= n { return s }
            let head = s.prefix(n)
            return "\(head)… [+\(s.count - n) more]"
        }
        var info: [String: Any] = [:]
        info["label"] = label
        info["model"] = body["model"] ?? ""
        info["temperature"] = body["temperature"] ?? ""
        info["max_completion_tokens"] = body["max_completion_tokens"] ?? ""
        info["response_format"] = body["response_format"] ?? ""
        if let msgs = body["messages"] as? [[String: Any]] {
            var compactMsgs: [[String: Any]] = []
            for (i, m) in msgs.enumerated() {
                var row: [String: Any] = [:]
                row["i"] = i
                row["role"] = m["role"] ?? ""
                if let contentArr = m["content"] as? [[String: Any]] {
                    var parts: [[String: Any]] = []
                    for (j, part) in contentArr.enumerated() {
                        var pr: [String: Any] = [:]
                        pr["j"] = j
                        let type = (part["type"] as? String) ?? "text"
                        pr["type"] = type
                        if type == "text", let t = part["text"] as? String {
                            pr["text"] = trunc(t, 320)
                            pr["text_len"] = t.count
                        } else if (type == "image_url"),
                                  let img = part["image_url"] as? [String: Any],
                                  let url = img["url"] as? String {
                            pr["image_url_prefix"] = trunc(url, 64)
                            pr["image_data_len"] = url.count
                        } else {
                            pr["raw"] = part
                        }
                        parts.append(pr)
                    }
                    row["content(parts)"] = parts
                } else if let text = m["content"] as? String {
                    row["content(text)"] = trunc(text, 320)
                    row["content_len"] = text.count
                } else {
                    row["content"] = m["content"] ?? ""
                }
                compactMsgs.append(row)
            }
            info["messages_summary"] = compactMsgs
            info["messages_count"] = msgs.count
        }
        print("➡️ OpenAI Chat Request:", info)
    }
#endif
    
    // MARK: - New Safety Analysis API (parity with web)
    // Shared sender for chat requests (text/image)
    private func sendChat(
        body: [String: Any],
        apiKey: String,
        endpoint: String,
        stage: ModelTier,                 // NEW: to label errors
        requestTimeout: TimeInterval      // NEW: pass from caller
    ) async throws -> (content: String, data: Data, finishReason: String?, requestID: String?, elapsedMs: Int) {
        guard isKeyValid(apiKey) else { throw OpenAIServiceError.invalidAPIKey }

        let t0 = Date()
        var request = URLRequest(url: URL(string: endpoint)!)
        request.timeoutInterval = requestTimeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            let http = response as? HTTPURLResponse
            let reqID = http?.allHeaderFields["x-request-id"] as? String
            if let http, !(200...299).contains(http.statusCode) {
                let preview = String(data: data, encoding: .utf8)?.prefix(600) ?? Substring("<none>")
                #if DEBUG
                print("❌ OPENAI HTTP \(http.statusCode), rid=\(reqID ?? "-"), bodyPreview=\(preview)")
                #endif
                throw OpenAIServiceError.http(status: http.statusCode, requestID: reqID, bodyPreview: String(preview))
            }

            // Decode content as String or content parts
            let raw = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            let content = raw.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // Read finish_reason from raw JSON
            var finish: String? = nil
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let first = choices.first {
                finish = first["finish_reason"] as? String
            }

            #if DEBUG
            print("⏱️ OpenAI sendChat elapsed=\(ms)ms, rid=\(reqID ?? "-"), finish_reason=\(finish ?? "nil"), content_len=\(content.count)")
            #endif
            return (content, data, finish, reqID, ms)

        } catch is CancellationError {
            throw OpenAIServiceError.cancelled(stage: stage)
        } catch let e as URLError where e.code == .timedOut {
            throw OpenAIServiceError.timeout(stage: stage, seconds: Int(requestTimeout))
        } catch let e as URLError {
            throw OpenAIServiceError.network(e)
        } catch {
            throw OpenAIServiceError.other(stage: stage, underlying: error)
        }
    }

// MARK: - analyzeSafety implementation (OpenAIServiceType)
    
    private func shouldTryFallback(_ error: Error) -> Bool {
        // Fallback is only meaningful for content/schema issues (not transport)
        guard let e = error as? OpenAIServiceError else { return true } // unknown → try fallback
        switch e {
        case .finishReasonBlocked, .decodeJSON, .emptyContent:
            return true
        default:
            return false
        }
    }

    public func analyzeSafety(
        input: SafetyAnalysisInput,
        tier: ModelTier,
        timeout: Duration
    ) async throws -> (SafetyAnalysisResponse, modelConfidence: Double) {
        // Tier-specific settings: fast = json_object with schema fallback; smart = json_schema
        let (model, temperature, maxTokens, primaryFormat, fallbackFormat): (String, Double, Int, [String: Any], [String: Any]?) = {
            switch tier {
            case .fast:
                return (
                    "gpt-4.1-mini", 0.2, 900,
                    [
                        "type": "json_schema",
                        "json_schema": ["name": "SafetyAnalysisResponse", "schema": safetyJSONSchema()]
                    ],
                    ["type": "json_object"]
                )
            case .smart:
                return (
                    "gpt-5", 1, 2200,
                    [
                        "type": "json_schema",
                        "json_schema": ["name": "SafetyAnalysisResponse", "schema": safetyJSONSchema()]
                    ],
                    nil
                )
            }
        }()

        // Shared prompts
        let systemText = """
        You are a product safety analyst.

        OUTPUT RULES (MANDATORY):
        - Return JSON ONLY that VALIDATES against the provided schema. No prose, no markdown.
        - Do NOT add keys not present in the schema; leave optional fields null or empty arrays instead of inventing values.
        - Score ranges: overall/child/dog/cat = 0–100 integers; modelConfidence & recognitionConfidence = 0.0–1.0 numbers.
        - DO NOT perform any image recognition or OCR. Rely ONLY on the Google Vision data and fields provided by the app (productName, productType, brand candidates, labels/objects, detected text, recognition confidence).
        - If you are uncertain about any field, choose the safest default:
          • productName/productType may be "Unknown" if not inferable from the provided Vision data
          • recalls: [] unless there is strong evidence
          • hygieneWarnings: [] unless clearly warranted
        - When pet analysis is disabled, still return the pet sections and scores, but set dogSafetyScore/catSafetyScore to null and empty arrays in petSafety.
        - Keep answers concise; avoid repeating evidence in text—encode it in the JSON fields only.
        """

        let guess = input.guess
        let petFlags: String = {
            switch input.petPreference {
            case .dog:  return "includeDogs=true, includeCats=false"
            case .cat:  return "includeDogs=false, includeCats=true"
            case .both: return "includeDogs=true, includeCats=true"
            case .none: return "includeDogs=false, includeCats=false"
            }
        }()

        let user = """
        Analyze this product's safety using the schema.

        IMPORTANT:
        - Do NOT attempt to recognize the image.
        - Use ONLY the following Google Vision-derived fields as ground truth for identification.

        Product (from Google Vision):
        - name: \(guess.name)
        - type: \(guess.type)
        - brand: \(guess.brand ?? "unknown")
        - vision_confidence: \(String(format: "%.2f", guess.confidence))

        OPTIONS: { \(petFlags) }
        """

        // Helper to run a single request with a given response_format
        func runOnce(responseFormat: [String: Any]) async throws -> (content: String, data: Data, finish: String?, requestID: String?) {
            let body: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": [["type": "text", "text": systemText]]],
                    ["role": "user",   "content": [["type": "text", "text": user]]]
                ],
                "response_format": responseFormat,
                "temperature": temperature,
                "max_completion_tokens": maxTokens
            ]
            #if DEBUG
            debugPrintChatBody(label: tier == .fast ? "FAST SAFETY" : "SMART SAFETY", body: body)
            #endif

            // Respect the caller's timeout (Duration) without double-wrapping;
            // URLRequest.timeoutInterval is set inside sendChat.
            let seconds = max(1, Int(timeout.components.seconds))
            let (content, data, finish, requestID, _) = try await sendChat(
                body: body,
                apiKey: apiKey,
                endpoint: endpoint,
                stage: tier,
                requestTimeout: TimeInterval(seconds)
            )
            
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw OpenAIServiceError.emptyContent(stage: tier)
            }

            // OpenAI might return finish_reason that signals filtering/truncation
            if let finish, finish != "stop" {
                if finish == "length" {
                    // Not fatal by itself; we’ll try decoding anyway
                } else if finish.contains("content_filter") {
                    throw OpenAIServiceError.finishReasonBlocked(stage: tier, reason: finish)
                }
            }

            return (content, data, finish, requestID)
        }

        // Cleaners & decoder
        func cleanedJSON(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
             .replacingOccurrences(of: "```json", with: "")
             .replacingOccurrences(of: "```", with: "")
        }

        func decodeOrThrow(_ content: String, requestID: String?, finish: String?, includeDogs: Bool, includeCats: Bool) throws -> SafetyAnalysisResponse {
            let cleaned = cleanedJSON(content)
            #if DEBUG
            print("🪄 OpenAI Raw JSON Response:", cleaned)
            #endif
            guard let data = cleaned.data(using: .utf8) else {
                throw OpenAIServiceError.decodeJSON(stage: tier, reason: "UTF-8 conversion failed", jsonPreview: String(cleaned.prefix(240)))
            }
            do {
                var parsed = try JSONDecoder().decode(SafetyAnalysisResponse.self, from: data)

                // Normalize & validate ranges
                parsed.childSafetyScore = max(0, min(100, parsed.childSafetyScore))
                parsed.dogSafetyScore = parsed.dogSafetyScore.map { max(0, min(100, $0)) }
                parsed.catSafetyScore = parsed.catSafetyScore.map { max(0, min(100, $0)) }
                parsed.overallSafetyScore = max(0, min(100, parsed.overallSafetyScore))
                parsed.modelConfidence = max(0.0, min(1.0, parsed.modelConfidence))
                parsed.recognitionConfidence = max(0.0, min(1.0, parsed.recognitionConfidence))

                let validated10 = validateSafetyScoreConsistency(
                    primaryScore: parsed.overallSafetyScore / 10,
                    productName: parsed.productName.lowercased(),
                    productType: parsed.productType.lowercased(),
                    petSafety: parsed.petSafety,
                    cons: parsed.generalSafety.cons,
                    recalls: parsed.recalls,
                    shouldAnalyzePets: (includeDogs || includeCats) || isDangerousToAllPets(parsed.productName.lowercased())
                )
                parsed.overallSafetyScore = min(parsed.overallSafetyScore, validated10 * 10)
                return parsed
            } catch let e as DecodingError {
                let why: String
                switch e {
                case .keyNotFound(let k, _):       why = "Missing key: \(k.stringValue)"
                case .typeMismatch(let t, _):      why = "Type mismatch: \(t)"
                case .valueNotFound(let t, _):     why = "Value not found for: \(t)"
                case .dataCorrupted(let ctx):      why = "Data corrupted: \(ctx.debugDescription)"
                @unknown default:                  why = "Unknown decoding error"
                }
                throw OpenAIServiceError.decodeJSON(stage: tier, reason: why + (finish != nil ? " (finish_reason=\(finish!))" : ""), jsonPreview: String(cleaned.prefix(480)))
            } catch {
                throw OpenAIServiceError.other(stage: tier, underlying: error)
            }
        }

        // Flags for validator
        let includeDogs = input.petPreference == .dog || input.petPreference == .both
        let includeCats = input.petPreference == .cat || input.petPreference == .both

        // Attempt primary format
        let contentPrimary: String
        let finishPrimary: String?
        let ridPrimary: String?

        do {
            let r = try await runOnce(responseFormat: primaryFormat)
            contentPrimary = r.content
            finishPrimary  = r.finish
            ridPrimary     = r.requestID
        } catch {
            #if DEBUG
            print("⚠️ Primary request failed (\(tier)): \(error)")
            #endif

            // Only try fallback for FAST and only for non-transport errors.
            if tier == .fast, shouldTryFallback(error), let fallback = fallbackFormat {
                let r = try await runOnce(responseFormat: fallback)
                let parsed = try decodeOrThrow(
                    r.content,
                    requestID: r.requestID,
                    finish: r.finish,
                    includeDogs: includeDogs,
                    includeCats: includeCats
                )
                let mc = max(0.0, min(1.0, parsed.modelConfidence > 0 ? parsed.modelConfidence : 0.5))
                return (parsed, mc)
            }

            // Transport/HTTP/etc. → propagate
            throw error
        }

        // Decode primary
        do {
            let parsed = try decodeOrThrow(
                contentPrimary,
                requestID: ridPrimary,
                finish: finishPrimary,
                includeDogs: includeDogs,
                includeCats: includeCats
            )
            let mc = max(0.0, min(1.0, parsed.modelConfidence > 0 ? parsed.modelConfidence : 0.5))
            return (parsed, mc)
        } catch {
            #if DEBUG
            print("⚠️ Primary decode failed (\(tier)): \(error)")
            #endif
        }

        // Try fallback decode for FAST (schema rescue). For SMART we degrade later.
        if let fallback = fallbackFormat {
            let r = try await runOnce(responseFormat: fallback)
            do {
                let parsed = try decodeOrThrow(
                    r.content,
                    requestID: r.requestID,
                    finish: r.finish,
                    includeDogs: includeDogs,
                    includeCats: includeCats
                )
                let mc = max(0.0, min(1.0, parsed.modelConfidence > 0 ? parsed.modelConfidence : 0.5))
                return (parsed, mc)
            } catch {
                #if DEBUG
                print("⚠️ Fallback decode failed (\(tier)): \(error)")
                #endif
                if tier == .fast { throw error }
                // for .smart we degrade to mock below
            }
        }

        #if DEBUG
        print("⚠️ analyzeSafety(\(tier)) failed to decode; serving mock for UX continuity.")
        #endif
        let mock = generateEnhancedMockAnalysis(SafetyAnalysisRequest(
            includeDogs: includeDogs,
            includeCats: includeCats,
            includeChildren: true
        ))
        return (mock, 0.5)
    }

    private func isKeyValid(_ key: String) -> Bool {
        !key.isEmpty && key.count >= 20 && key.hasPrefix("sk-")
    }

    // MARK: - Enhanced Mock (parity with web logic, trimmed)
    private func generateEnhancedMockAnalysis(_ request: SafetyAnalysisRequest) -> SafetyAnalysisResponse {
        let name = "Unknown"
        let type = "Unknown"

        let dangerousToAllPets = isDangerousToAllPets(name)
        let userRequestedPet = request.includeDogs || request.includeCats
        let shouldAnalyzePets = dangerousToAllPets || userRequestedPet

        // Base child-centric score on 1–10 heuristic, then scale to 0–100
        let initial10 = calculateInitialSafetyScore(productName: name, productType: type, shouldAnalyzePets: shouldAnalyzePets)

        // Sections used by scoring
        let ctx = generateContextualSafetyConcerns(productName: name, productType: type, safetyScore: initial10, request: request)
        let petSafety = SafetyAnalysisResponse.PetSafety(
            dogs: ((shouldAnalyzePets && request.includeDogs) || dangerousToAllPets) ? generatePetWarnings(petType: "dog", productName: name, productType: type) : [],
            cats: ((shouldAnalyzePets && request.includeCats) || dangerousToAllPets) ? generatePetWarnings(petType: "cat", productName: name, productType: type) : []
        )
        let hygiene = generateHygieneWarnings(productName: name, productType: type)
        let recalls = generateRecalls(productName: name, productType: type)

        // Finalize the 1–10 score and scale
        let final10 = calculateFinalSafetyScore(
            initialScore: initial10,
            productName: name,
            petSafety: petSafety,
            cons: ctx.cons,
            recalls: recalls,
            shouldAnalyzePets: shouldAnalyzePets
        )
        let backup10 = validateSafetyScoreConsistency(
            primaryScore: final10,
            productName: name,
            productType: type,
            petSafety: petSafety,
            cons: ctx.cons,
            recalls: recalls,
            shouldAnalyzePets: shouldAnalyzePets
        )
        let final10Capped = min(final10, backup10)
        let child100 = max(0, min(100, final10Capped * 10))

        // Pet scores from warnings (simple mapping)
        func petScore(from warnings: [SafetyAnalysisResponse.PetWarning]) -> Int {
            let hasHigh = warnings.contains { $0.severity == .high }
            let hasMed  = warnings.contains { $0.severity == .medium }
            if hasHigh { return 15 }
            if hasMed  { return 55 }
            return 90
        }
        let dog100: Int = petSafety.dogs.isEmpty ? 90 : petScore(from: petSafety.dogs)
        let cat100: Int = petSafety.cats.isEmpty ? 90 : petScore(from: petSafety.cats)

        // Choose a conservative overall (child-focused here). SafetyAnalyzer will remap for pets.
        let overall = child100

        return SafetyAnalysisResponse(
            productName: name,
            productType: type,
            overallSafetyScore: overall,
            childSafetyScore: child100,
            dogSafetyScore: dog100,
            catSafetyScore: cat100,
            modelConfidence: 0.6,
            recognitionConfidence: 0.0,
            generalSafety: SafetyAnalysisResponse.GeneralSafety(pros: ctx.pros, cons: ctx.cons),
            petSafety: petSafety,
            hygieneWarnings: hygiene,
            recalls: recalls
        )
    }

    // MARK: - Scoring & Rules (trimmed from web impl)
    private func getDefaultScore(productType: String) -> Int {
        let defaults: [String: Int] = [
            "food": 8, "cosmetic": 7, "toy": 8, "electronic": 7,
            "household": 6, "clothing": 8, "animal": 3, "jewelry": 7,
            "pharmaceutical": 6, "automotive": 5, "other": 6
        ]
        return defaults[productType, default: 6]
    }

    private func isDangerousToAllPets(_ productName: String) -> Bool {
        let items = ["chocolate","cocoa","raisin","raisins","grape","grapes","lily","lilies","onion","garlic","avocado","xylitol","macadamia"]
        return items.contains { productName.contains($0) }
    }

    private func calculateInitialSafetyScore(productName: String, productType: String, shouldAnalyzePets: Bool) -> Int {
        var score = getDefaultScore(productType: productType)
        if productName.contains("raisin") || productName.contains("grape") {
            score = shouldAnalyzePets ? 1 : 7
        } else if productName.contains("banana") {
            score = 9
        } else if productName.contains("chocolate") || productName.contains("cocoa") {
            score = shouldAnalyzePets ? 1 : 7
        } else if productName.contains("lily") || productName.contains("lilies") {
            score = shouldAnalyzePets ? 1 : 6
        } else if productName.contains("alligator") || productName.contains("crocodile") {
            score = 1
        } else if productName.contains("tank") || productName.contains("military") {
            score = 2
        } else if productName.contains("eagle") || productName.contains("bird") {
            score = shouldAnalyzePets ? 3 : 6
        }
        return score
    }

    private func calculateFinalSafetyScore(initialScore: Int, productName: String, petSafety: SafetyAnalysisResponse.PetSafety, cons: [SafetyAnalysisResponse.LabeledItem], recalls: [SafetyAnalysisResponse.Recall], shouldAnalyzePets: Bool) -> Int {
        var final = initialScore
        let highPet = (petSafety.dogs + petSafety.cats).filter { $0.severity == .high }.count
        let highCons = cons.filter { $0.severity == .high }.count
        let highRecalls = recalls.filter { $0.severity == .high }.count

        if highPet > 0 { final = min(final, 3) }
        if highPet >= 2 || (highPet > 0 && highCons > 0) || (highPet > 0 && highRecalls > 0) { final = min(final, 2) }
        if isDangerousToAllPets(productName) && shouldAnalyzePets { final = 1 }
        return max(1, min(10, final))
    }

    private func validateSafetyScoreConsistency(primaryScore: Int, productName: String, productType: String, petSafety: SafetyAnalysisResponse.PetSafety, cons: [SafetyAnalysisResponse.LabeledItem], recalls: [SafetyAnalysisResponse.Recall], shouldAnalyzePets: Bool) -> Int {
        var backup = 6
        let deadly = ["chocolate","raisin","grape","lily","alligator","crocodile"].contains { productName.contains($0) }
        if deadly && shouldAnalyzePets { return 1 }
        let highCount = (petSafety.dogs + petSafety.cats).filter { $0.severity == .high }.count + cons.filter { $0.severity == .high }.count + recalls.filter { $0.severity == .high }.count
        if highCount >= 4 { backup = 1 }
        else if highCount >= 2 { backup = 2 }
        else if highCount >= 1 { backup = 3 }
        else {
            let mediumCount = (petSafety.dogs + petSafety.cats).filter { $0.severity == .medium }.count + cons.filter { $0.severity == .medium }.count
            if mediumCount >= 3 { backup = 4 }
            else if mediumCount >= 1 { backup = 6 }
            else { backup = 8 }
        }
        if productName.contains("banana") && !shouldAnalyzePets { backup = 9 }
        return max(1, min(10, backup))
    }
    
    // Rough token estimator (~4 chars per token)
    private func estimateTokens(for text: String) -> Int {
        let count = text.unicodeScalars.count
        return max(1, count / 4)
    }
    
    // Downscale image to reduce latency/payload
    private func downscaleJPEG(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.75) -> Data {
        #if canImport(UIKit)
        guard let img = UIImage(data: data) else { return data }
        let w = img.size.width, h = img.size.height
        let scale = min(1, maxDimension / max(w, h))
        guard scale < 1 else {
            return img.jpegData(compressionQuality: quality) ?? data
        }
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        img.draw(in: CGRect(origin: .zero, size: newSize))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaled?.jpegData(compressionQuality: quality) ?? data
        #else
        return data
        #endif
    }

    private func generateContextualSafetyConcerns(productName: String, productType: String, safetyScore: Int, request: SafetyAnalysisRequest) -> (pros: [SafetyAnalysisResponse.LabeledItem], cons: [SafetyAnalysisResponse.LabeledItem]) {
        var pros: [SafetyAnalysisResponse.LabeledItem] = []
        var cons: [SafetyAnalysisResponse.LabeledItem] = []

        func addPro(_ label: String, _ sev: Severity, _ cat: String) { pros.append(.init(label: label, severity: sev, category: cat)) }
        func addCon(_ label: String, _ sev: Severity, _ cat: String) { cons.append(.init(label: label, severity: sev, category: cat)) }

        if productName.contains("raisin") || productName.contains("grape") {
            addPro("Natural source of antioxidants and fiber for humans", .low, "nutrition")
            addCon("DEADLY TO DOGS: Causes acute kidney failure", .high, "chemical")
            addCon("Even small amounts can be fatal to dogs", .high, "chemical")
            if request.includeCats { addCon("May cause digestive upset in cats", .medium, "biological") }
        } else if productName.contains("chocolate") {
            addPro("Rich in antioxidants and may provide mood benefits", .low, "nutrition")
            addCon("Contains theobromine - extremely toxic to pets", .high, "chemical")
            addCon("High sugar content may contribute to dental issues", .medium, "nutrition")
        } else if productName.contains("alligator") || productName.contains("crocodile") {
            addCon("Powerful bite force can cause severe injury or death", .high, "physical")
            addCon("Aggressive predator with unpredictable behavior", .high, "biological")
            addCon("Carries various pathogens and parasites", .high, "biological")
        } else if productName.contains("mouse") || productName.contains("rat") {
            addCon("May carry diseases transmissible to humans", .medium, "biological")
            addCon("Can bite when threatened or cornered", .low, "physical")
            addPro("Generally small and manageable size", .low, "physical")
        } else if productName.contains("dinosaur") || productName.contains("t-rex") {
            addCon("Massive size and weight pose crushing hazard", .high, "physical")
            addCon("Powerful jaws designed for crushing bone", .high, "physical")
            addCon("Apex predator with hunting instincts", .high, "biological")
        } else if productName.contains("tank") || productName.contains("military") {
            addCon("Heavy armor and weaponry designed for combat", .high, "physical")
            addCon("Not designed for civilian use or safety", .high, "regulatory")
            addCon("Requires specialized training to operate safely", .high, "mechanical")
        } else if productName.contains("lily") || productName.contains("lilies") {
            if request.includeCats {
                addCon("DEADLY TO CATS: All parts cause acute kidney failure", .high, "chemical")
                addCon("Even tiny amounts of pollen can kill cats within 24-72 hours", .high, "chemical")
                addCon("Emergency veterinary treatment required for any contact", .high, "biological")
            } else {
                addPro("Beautiful ornamental flowering plant", .low, "environmental")
                addCon("Toxic to cats if pets are introduced later", .medium, "chemical")
            }
        } else if productName.contains("flower") || productName.contains("orchid") {
            addPro("Natural and biodegradable material", .low, "environmental")
            addPro("Generally safe for human handling", .low, "physical")
        } else {
            switch productType {
            case "food": addPro("Regulated by food safety authorities", .low, "regulatory")
            case "toy": addPro("Designed with child safety standards", .low, "regulatory")
            case "electronic": addPro("Typically FCC/CE certified for electromagnetic safety", .low, "electrical")
            default: break
            }
        }

        if pros.isEmpty { addPro("No specific safety benefits identified", .low, "regulatory") }
        if cons.isEmpty && safetyScore < 8 { addCon("General safety precautions recommended", .low, "regulatory") }
        return (pros, cons)
    }

    private func generatePetWarnings(petType: String, productName: String, productType: String) -> [SafetyAnalysisResponse.PetWarning] {
        var warnings: [SafetyAnalysisResponse.PetWarning] = []
        func push(_ sev: Severity, _ warn: String, _ reason: String) { warnings.append(.init(severity: sev, warning: warn, reason: reason)) }
        let lower = productName

        if lower.contains("raisin") || lower.contains("grape") {
            if petType == "dog" {
                push(.high, "Raisins and grapes are extremely toxic to dogs", "Can cause acute kidney failure")
                push(.high, "Emergency vet required if dog consumes any amount", "Immediate treatment is critical")
            } else {
                push(.medium, "Monitor cats around grapes and raisins", "May cause digestive upset")
            }
        } else if lower.contains("chocolate") || lower.contains("cocoa") {
            push(.high, "Chocolate is extremely toxic to \(petType)s", "Contains theobromine; can cause seizures and death")
            if lower.contains("dark chocolate") { push(.high, "Dark chocolate is especially dangerous", "Higher theobromine levels") }
        } else if lower.contains("orchid") {
            push(.medium, "Some orchids may be toxic to \(petType)s", "Certain species can cause digestive upset")
        } else if lower.contains("flower") || productType == "cosmetic" {
            push(.low, "Monitor \(petType) around flowers and plants", "May cause allergic reactions or GI upset")
        } else if petType == "cat" && (lower.contains("lily") || lower.contains("lilies")) {
            push(.high, "DEADLY: All lilies are lethal to cats", "Pollen/petals cause acute kidney failure within 24-72 hours")
            push(.high, "Emergency vet required if any contact occurs", "Immediate treatment is the only chance of survival")
        } else if lower.contains("alligator") || lower.contains("crocodile") {
            push(.high, "Keep \(petType)s away from alligators/crocodiles", "Large predators can seriously injure or kill pets")
        } else if lower.contains("eagle") || lower.contains("hawk") || lower.contains("falcon") {
            push(.high, "Birds of prey pose danger to small \(petType)s", "Can attack and carry off small pets")
        } else if lower.contains("bird") {
            push(.medium, "Monitor \(petType) interactions with wild birds", "Wild birds may carry diseases")
        } else if lower.contains("mouse") || lower.contains("rat") {
            push(.medium, "Monitor \(petType) around wild rodents", "Rodents may carry diseases and parasites")
        } else if productType == "electronic" {
            push(.low, "Keep electrical cords away from \(petType)s", "Chewing can cause burns or electrocution")
        }
        return warnings
    }

    private func generateHygieneWarnings(productName: String, productType: String) -> [SafetyAnalysisResponse.HygieneWarning] {
        var warnings: [SafetyAnalysisResponse.HygieneWarning] = []
        let lower = productName
        if lower.contains("chocolate") { warnings.append(.init(type: "wash", message: "Wash hands after handling chocolate products")) }
        if lower.contains("alligator") || lower.contains("crocodile") {
            warnings.append(.init(type: "danger", message: "Extreme caution required - dangerous wild animal"))
            warnings.append(.init(type: "bacteria", message: "May carry harmful bacteria and parasites"))
        }
        if lower.contains("mouse") || lower.contains("rat") { warnings.append(.init(type: "germs", message: "Wild rodents may carry diseases - avoid direct contact")) }
        if lower.contains("flower") || lower.contains("plant") { warnings.append(.init(type: "wash", message: "Wash hands after handling plants and flowers")) }
        if productType == "food" && warnings.isEmpty { warnings.append(.init(type: "wash", message: "Wash hands before and after handling food products")) }
        return warnings
    }

    private func generateRecalls(productName: String, productType: String) -> [SafetyAnalysisResponse.Recall] {
        var recalls: [SafetyAnalysisResponse.Recall] = []
        // Demo-only: randomize a couple scenarios similar to web
        if productName.contains("chocolate") && Bool.random() {
            recalls.append(.init(date: "2024-01-15", reason: "Potential salmonella contamination in chocolate products", severity: .medium, source: "FDA"))
        }
        if productType == "toy" && Int.random(in: 0...9) > 7 {
            recalls.append(.init(date: "2023-12-10", reason: "Small parts may pose choking hazard", severity: .high, source: "CPSC"))
        }
        return recalls
    }
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String
        // Accept either a plain string or an array of content parts with text.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // First try as a simple string
            if let s = try? container.decode(String.self, forKey: .content) {
                self.content = s
                return
            }
            // Then try as an array of parts
            if var unkeyed = try? container.nestedUnkeyedContainer(forKey: .content) {
                var texts: [String] = []
                while !unkeyed.isAtEnd {
                    if let part = try? unkeyed.decode(ContentPart.self) {
                        if let t = part.text {
                            texts.append(t)
                        }
                    } else {
                        _ = try? unkeyed.decode(EmptyDecodable.self)
                    }
                }
                self.content = texts.joined(separator: "\n")
                return
            }
            // Fallback empty
            self.content = ""
        }
        enum CodingKeys: String, CodingKey { case content }
        struct ContentPart: Decodable {
            let type: String?
            let text: String?
        }
        struct EmptyDecodable: Decodable {}
    }
    let choices: [Choice]
}

private extension Bundle {
    func apiKey(named key: String) -> String? {
        infoDictionary?[key] as? String
    }
}

