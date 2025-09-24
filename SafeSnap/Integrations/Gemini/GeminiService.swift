//
//  GeminiService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import Foundation
import UIKit
import CryptoKit

private struct GoogleAPIErrorEnvelope: Decodable {
    struct Inner: Decodable {
        let code: Int?
        let message: String?
        let status: String?
    }
    let error: Inner?
}

private func decodeGoogleError(from data: Data) -> String? {
    if let env = try? JSONDecoder().decode(GoogleAPIErrorEnvelope.self, from: data),
       let msg = env.error?.message, !msg.isEmpty {
        return msg
    }
    // Fallback: return body as UTF-8
    return String(data: data, encoding: .utf8)
}

final class GeminiService {
    private let model = "gemini-1.5-flash"
    // Determinism & reliability
    private let reliabilityRuns = 3
    private let recognitionGateThreshold: Double = 0.85 // gate low-confidence recognitions
    // Simple in-memory cache to keep repeated scans stable within a session
    private var resultCache: [String: SafetyAnalysisResponse] = [:]

    enum GeminiServiceError: LocalizedError {
        case lowRecognitionConfidence(Double)
        case emptyAIResponse
        case normalizationFailed
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .lowRecognitionConfidence(let c): return "Recognition confidence too low (\(Int(c * 100))%). Please retake the photo (center the product, show the front label)."
            case .emptyAIResponse: return "Gemini returned no JSON text."
            case .normalizationFailed: return "Unable to confidently map the product to a canonical safety category."
            case .cancelled: return "Analysis was cancelled."
            }
        }
    }
    
    /// Hash the image so repeated scans yield cached, consistent results.
    private func cacheKey(for imageData: Data, options: SafetyOptions) -> String {
        var hasher = SHA256()
        hasher.update(data: imageData)
        // include toggles in the key
        let toggles = "\(options.includeDogs)-\(options.includeCats)-\(options.includeChildren)".data(using: .utf8)!
        hasher.update(data: toggles)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Very small taxonomy/normalization layer. Extend as needed.
    private func canonicalCategory(from name: String?, type: String?) -> String? {
        let tokens = ([(name ?? ""), (type ?? "")]
            .joined(separator: " ")
            .lowercased())
        // Alcohol
        let alcoholHints = ["beer","lager","ale","ipa","stout","porter","wine","vodka","whisky","whiskey","rum","gin","tequila","cider","alcohol","alc.","tallboy"]
        if alcoholHints.contains(where: { tokens.contains($0) }) {
            return "alcohol"
        }
        // Tobacco / nicotine
        let tobaccoHints = ["cigarette","tobacco","nicotine","vape","snus","e-cig","e‑cig","e cig"]
        if tobaccoHints.contains(where: { tokens.contains($0) }) {
            return "tobacco_nicotine"
        }
        // Button batteries / magnets
        let batteryHints = ["button battery","coin cell","cr2032","lr44","battery"]
        if batteryHints.contains(where: { tokens.contains($0) }) {
            return "button_battery"
        }
        // Household hazards
        let detergentHints = ["detergent","pods","laundry pod","bleach","cleaner","ammonia"]
        if detergentHints.contains(where: { tokens.contains($0) }) {
            return "household_chemical"
        }
        // Caffeine/energy
        let caffeineHints = ["energy drink","caffeine","espresso","coffee shot","yerba mate","guarana"]
        if caffeineHints.contains(where: { tokens.contains($0) }) {
            return "caffeine"
        }
        // High choking risk
        let chokingHints = ["whole nut","peanut","almond","hazelnut","grape","hot dog","marble"]
        if chokingHints.contains(where: { tokens.contains($0) }) {
            return "choking_hazard"
        }
        // Strong magnets
        let magnetHints = ["neodymium","rare earth magnet","buckyballs","magnet sphere"]
        if magnetHints.contains(where: { tokens.contains($0) }) { return "strong_magnet" }
        return nil
    }
    
    /// Apply hard guardrails & child-first policy on top of model output.
    private func applyPolicyOverrides(_ r: inout SafetyAnalysisResponse, options: SafetyOptions) {
        let cat = canonicalCategory(from: r.productName, type: r.productType)
        
        if cat == "alcohol" {
            // Near-zero for children & pets regardless of AI text
            r.childSafetyScore = min(r.childSafetyScore, 1)
            r.overallSafetyScore = min(r.overallSafetyScore, 1)
            if options.includeDogs { r.dogSafetyScore = (r.dogSafetyScore ?? 1) > 1 ? 1 : r.dogSafetyScore }
            if options.includeCats { r.catSafetyScore = (r.catSafetyScore ?? 1) > 1 ? 1 : r.catSafetyScore }
        } else if cat == "tobacco_nicotine" {
            r.childSafetyScore = min(r.childSafetyScore, 1)
            r.overallSafetyScore = min(r.overallSafetyScore, 1)
        } else if cat == "button_battery" {
            r.childSafetyScore = min(r.childSafetyScore, 1)
            r.overallSafetyScore = min(r.overallSafetyScore, 1)
        } else if cat == "household_chemical" || cat == "caffeine" || cat == "strong_magnet" {
            r.childSafetyScore = min(r.childSafetyScore, 2)
            r.overallSafetyScore = min(r.overallSafetyScore, r.childSafetyScore)
        } else if cat == "choking_hazard" {
            r.childSafetyScore = min(r.childSafetyScore, 2)
            r.overallSafetyScore = min(r.overallSafetyScore, r.childSafetyScore)
        }
        
        // Ensure overall mirrors child perspective
        r.overallSafetyScore = min(r.overallSafetyScore, r.childSafetyScore)
    }
    
    private func median(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private var currentTask: URLSessionDataTask?
    private let session = URLSession(configuration: .default)
    private var wasCancelled = false
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func analyzeSafety(image: UIImage, options: SafetyOptions, streamToken: @escaping (String) -> Void) async throws -> SafetyAnalysisResponse {
        wasCancelled = false
        streamToken("Analyzing with Gemini…")
        // Encode once up front for cache key & payload
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])
        }
        let key = cacheKey(for: imageData, options: options)
        if let cached = resultCache[key] {
            streamToken("Using cached result for consistency.")
            return cached
        }
        if wasCancelled || Task.isCancelled { throw CancellationError() }
        let body = try makeRequestBody(image: image, options: options)
        let (data, response, taskRef) = try await makeNonStreamingRequest(body: body)
        self.currentTask = taskRef
        if wasCancelled || Task.isCancelled { throw CancellationError() }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct GenerateContentResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }
        let api = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let rawText = api.candidates?.first?.content.parts.first?.text else {
            throw NSError(domain: "GeminiService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Gemini returned no JSON text"])
        }

        // Sanitize: strip code fences and extraneous text before first '{' and after last '}'
        let sanitizedText: String = {
            var t = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.hasPrefix("```") { t = t.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "") }
            if let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}") { return String(t[start...end]) }
            return t
        }()
        
        guard let initialData = sanitizedText.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unable to encode Gemini text as UTF-8"])
        }
        
        // Deterministic multi-run aggregation (median to avoid outliers)
        func decodeRun(_ data: Data) throws -> SafetyAnalysisResponse {
            return try JSONDecoder().decode(SafetyAnalysisResponse.self, from: data)
        }
        
        var runs: [SafetyAnalysisResponse] = []
        do {
            if wasCancelled || Task.isCancelled { throw CancellationError() }
            runs.append(try decodeRun(initialData))
        } catch {
            // fall through to retry path below
        }
        
        // If first run failed or looks incomplete, retry with larger token limit and then do extra runs
        while runs.count < reliabilityRuns {
            if wasCancelled || Task.isCancelled { throw CancellationError() }
            streamToken("Ensuring consistency… (\(runs.count + 1)/\(reliabilityRuns))")
            let retryBody = try makeRequestBody(image: image, options: options, maxTokensOverride: 768)
            let (retryData, retryResponse, retryTask) = try await makeNonStreamingRequest(body: retryBody)
            self.currentTask = retryTask
            guard let http2 = retryResponse as? HTTPURLResponse, (200..<300).contains(http2.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let retryApi = try JSONDecoder().decode(GenerateContentResponse.self, from: retryData)
            guard let retryText = retryApi.candidates?.first?.content.parts.first?.text,
                  let retryFinal = retryText.data(using: .utf8) else {
                throw GeminiServiceError.emptyAIResponse
            }
            let decoded = try decodeRun(retryFinal)
            runs.append(decoded)
        }
        
        // Gate on recognition confidence & aggregate via median
        // Only keep runs that pass the recognition gate
        runs = runs.filter { $0.recognitionConfidence >= recognitionGateThreshold }
        guard !runs.isEmpty else {
            throw GeminiServiceError.lowRecognitionConfidence( (try? decodeRun(initialData).recognitionConfidence) ?? 0.0 )
        }
        
        // Aggregate (median) across runs for stability
        func aggInt(_ keyPath: KeyPath<SafetyAnalysisResponse, Int>) -> Int {
            median(runs.map { $0[keyPath: keyPath] })
        }
        func aggOptInt(_ keyPath: KeyPath<SafetyAnalysisResponse, Int?>) -> Int? {
            let vals = runs.compactMap { $0[keyPath: keyPath] }
            return vals.isEmpty ? nil : median(vals)
        }
        
        var final = runs[0]
        final.childSafetyScore = aggInt(\.childSafetyScore)
        final.overallSafetyScore = aggInt(\.overallSafetyScore)
        final.dogSafetyScore = aggOptInt(\.dogSafetyScore)
        final.catSafetyScore = aggOptInt(\.catSafetyScore)
        
        // Apply normalization + policy guardrails (child-first)
        applyPolicyOverrides(&final, options: options)
        
        // Cache and return
        resultCache[key] = final
        return final
    }
    
    // Returns analysis plus explainability extras for UI. Keeps existing analyzeSafety(...) intact.
    public func analyzeSafetyWithExtras(
        image: UIImage,
        options: SafetyOptions,
        streamToken: @escaping (String) -> Void,
        visionLabels: [String] = [],
        ocrHits: [String] = []
    ) async throws -> AnalyzedSafety {
        // Reuse the existing analysis pipeline for the authoritative result
        let resp = try await analyzeSafety(image: image, options: options, streamToken: streamToken)
        
        // Infer canonical category using the same normalizer.
        let cat = canonicalCategory(from: resp.productName, type: resp.productType)
        
        // Infer which policy rule set likely fired, based on category.
        var rules: [String] = []
        switch cat {
        case "alcohol": rules.append("alcohol_guardrail")
        case "tobacco_nicotine": rules.append("tobacco_guardrail")
        case "button_battery": rules.append("button_battery_guardrail")
        case "household_chemical": rules.append("household_chemical_guardrail")
        case "caffeine": rules.append("caffeine_guardrail")
        case "strong_magnet": rules.append("strong_magnet_guardrail")
        case "choking_hazard": rules.append("choking_hazard_guardrail")
        default: break
        }
        // We always align overall <= child as a child-first policy
        rules.append("overall_capped_by_child")
        
        let extras = AnalysisExtras(
            evidence: SafetyEvidence(labels: visionLabels, ocrHits: ocrHits),
            policy: PolicyOutcome(canonicalCategory: cat, rulesTriggered: rules)
        )
        return AnalyzedSafety(response: resp, extras: extras)
    }
    
    func cancelAnalysis() {
        wasCancelled = true
        currentTask?.cancel()
        currentTask = nil
    }
    
    private func makeRequestBody(image: UIImage, options: SafetyOptions, maxTokensOverride: Int? = nil) throws -> Data {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Build pet-specific instructions based on toggles
        let petDirective: String = {
            switch (options.includeDogs, options.includeCats) {
            case (true, true):
                return "Include safety analysis for both dogs and cats. Populate petSafety.dogs and petSafety.cats with concrete warnings (severity: low/medium/high)."
            case (true, false):
                return "Include safety analysis for dogs only. Populate petSafety.dogs with warnings. Set catSafetyScore to null and petSafety.cats to an empty array []. Do not invent cat data."
            case (false, true):
                return "Include safety analysis for cats only. Populate petSafety.cats with warnings. Set dogSafetyScore to null and petSafety.dogs to an empty array []. Do not invent dog data."
            case (false, false):
                return "Do not include pet-specific analysis. Set dogSafetyScore and catSafetyScore to null. Set petSafety.dogs and petSafety.cats to empty arrays []."
            }
        }()
        let childDirective: String = """
        Evaluate SAFETY FOR CHILDREN ONLY (infants, toddlers, and school‑age kids). Ignore adult tolerances.
        - All scores must reflect risk to children, not adults. In particular, set `overallSafetyScore` to the child safety perspective (it should mirror or be derived from `childSafetyScore`).
        - Prioritize pediatric risks: choking hazards (small parts, hard candies, whole nuts, coins, button batteries), toxicity (alcohol, caffeine, nicotine, xylitol, essential oils, household chemicals), high sugar/sodium, raw/unpasteurized items, known pediatric allergens, sharp edges, magnets, and temperature/burn risks.
        - If the item is an adult‑only product (e.g., alcoholic beverage, adult supplements/medications), return a very low `childSafetyScore` (≤ 2/10) with explicit warnings and set `overallSafetyScore` accordingly.
        - Do NOT include guidance framed for adults; all advice must be child‑focused.
        """
        let specificityDirective: String = """
        Be maximally specific when naming the product. If it's a mushroom, identify the species (e.g., 'shiitake', 'chanterelle'); if it's a plant/fruit/vegetable/herb/spice or any item with varieties, name the exact type/variety where possible (e.g., 'Gala apple', 'Roma tomato', 'curly parsley'). Use context from the image (shape, color, texture, packaging text) to disambiguate. Score safety for the specific type you identify. If two types are plausible, pick the most likely and reflect uncertainty via recognitionConfidence and modelConfidence. Do NOT invent fields outside the schema.
        """
        let ocrDirective: String = """
        Read any visible text directly from the image (OCR). Extract brand names, variety/species, flavor, size/weight, and any qualifiers (e.g., organic). Prefer OCR tokens to determine the exact product/variety name. Do not include the OCR text itself in your output; return JSON only that matches the schema. When OCR and visual cues agree, raise recognitionConfidence; when they conflict or are unclear, lower it and choose the most likely single specific type.
        """
        
        let generationConfig: [String: Any] = [
            "temperature": 0.0,
            "maxOutputTokens": maxTokensOverride ?? 640,
            "responseMimeType": "application/json",
            "responseSchema": SafetyAnalysisSchema.geminiResponseSchema(),
            "topP": 1.0
        ]
        
        let bodyDict: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": "You are a product safety analyst for CHILD SAFETY. Return JSON only that matches the provided schema."],
                    ["text": petDirective],
                    ["text": childDirective],
                    ["text": ocrDirective],
                    ["text": specificityDirective],
                    ["text": "Examples: 1) Image shows brown gills, convex cap with white stem → 'Mushroom — shiitake'. 2) Small red apple with yellow streaks, label 'Gala' visible → 'Apple — Gala'. 3) Long plum tomato on vine → 'Tomato — Roma'."],
                    ["text": "Normalization: Map any detected product/brand to a canonical category (e.g., 'FRZ Tallboy' → 'Beer' → 'Alcoholic Beverage'). Always fill productType with this canonical category."],
                    ["text": "Guardrails: If canonical category ∈ {alcohol, tobacco/nicotine, button battery, sharp magnets} then set childSafetyScore ≤ 2/10 and align overallSafetyScore to childSafetyScore. Do not contradict this with prose."]
                ]
            ],
            "contents": [[
                "role": "user",
                "parts": [
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]],
                    ["text": "Use integers 0-100 for scores, modelConfidence 0.0-1.0. Use nulls or empty arrays when unknown.\n\nOCR: Read any visible label/packaging text from the image and use it to decide the exact product/variety. Do not print OCR text; return JSON only.\n\nPet rules: \(petDirective)\nKid focus: \(childDirective)\n\nSpecificity: \(specificityDirective)\nAvoid generic names like 'mushroom', 'apple', 'lettuce' unless recognitionConfidence < 0.5.\nNormalization: Map brand/product names back to a canonical category before scoring (e.g., FRZ Tallboy → beer → alcohol).\nGuardrails: If category is alcohol/tobacco/nicotine/button battery, set childSafetyScore ≤ 2/10 and overallSafetyScore = childSafetyScore." ]
                ]
            ]],
            "generationConfig": generationConfig
        ]
        return try JSONSerialization.data(withJSONObject: bodyDict, options: [])
    }
    
    private func makeStreamingRequest(body: Data) async throws -> (URLSession.AsyncBytes, URLResponse) {
        var comps = URLComponents(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent"
        )!
        comps.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "alt", value: "sse")
        ]
        
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        return try await URLSession.shared.bytes(for: req)
    }
    
    private func makeNonStreamingRequest(body: Data) async throws -> (Data, URLResponse, URLSessionDataTask) {
        var comps = URLComponents(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse, URLSessionDataTask), Error>) in
            var task: URLSessionDataTask!
            task = session.dataTask(with: req) { [weak self] data, response, error in
                defer { self?.currentTask = nil }
                if let error = error as? URLError, error.code == .cancelled {
                    return continuation.resume(throwing: CancellationError())
                }
                if let error = error { return continuation.resume(throwing: error) }
                guard let data = data, let response = response else {
                    return continuation.resume(throwing: URLError(.badServerResponse))
                }
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    let msg = decodeGoogleError(from: data) ?? "HTTP \(http.statusCode)"
                    print("Gemini generateContent error: \(msg)")
                    continuation.resume(throwing: NSError(domain: "GeminiService", code: http.statusCode,
                                                          userInfo: [NSLocalizedDescriptionKey: msg]))
                } else {
                    continuation.resume(returning: (data, response, task))
                }
            }
            self.currentTask = task
            if self.wasCancelled {
                task.cancel()
            } else {
                task.resume()
            }
        }
    }
    
    private func extractStreamErrorText(from bytes: URLSession.AsyncBytes) async throws -> String? {
        var collected = Data()
        for try await line in bytes.lines {
            if line.isEmpty { continue }
            if line == "[DONE]" { break }
            if line.hasPrefix("data: ") {
                let jsonText = String(line.dropFirst(6))
                if let data = jsonText.data(using: String.Encoding.utf8) {
                    collected.append(data)
                    collected.append(0x0A as UInt8)
                }
            }
        }
        if collected.isEmpty { return nil }
        return String(data: collected, encoding: String.Encoding.utf8)
    }
}

struct GeminiChunk: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String? }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]?
}

private extension GeminiChunk {
    var errorMessage: String? {
        // Some SSE errors come encoded in a 'promptFeedback' or 'error' style object.
        // We only do a very light extraction here since the schema can vary.
        return nil
    }
}

public struct SafetyEvidence: Sendable {
    public var labels: [String]      // from Vision (image labels)
    public var ocrHits: [String]     // from OCR
}

public struct PolicyOutcome: Sendable {
    public var canonicalCategory: String?
    public var rulesTriggered: [String]   // e.g., ["alcohol_guardrail", "child_overall_alignment"]
}

public struct AnalysisExtras: Sendable {
    public var evidence: SafetyEvidence
    public var policy: PolicyOutcome
}

public struct AnalyzedSafety: Sendable {
    public let response: SafetyAnalysisResponse
    public let extras: AnalysisExtras
}

extension GeminiService: SafetyAnalyzing {}
