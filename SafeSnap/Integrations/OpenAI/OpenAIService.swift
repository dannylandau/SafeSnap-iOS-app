//
//  OpenAIService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 30/07/2025.
//

import Foundation
import UIKit

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
            "required": [
                "productName","productType",
                "overallSafetyScore",
                "childSafetyScore","animalSafetyScore","dogSafetyScore","catSafetyScore",
                "modelConfidence","recognitionConfidence",
                "generalSafety","petSafety","hygieneWarnings","recalls"
            ],
            "properties": [
                "productName": ["type": "string"],
                "productType": ["type": "string"],

                // Scoring fields
                "overallSafetyScore": ["type": "integer", "minimum": 0, "maximum": 100],
                "childSafetyScore":  ["type": "integer", "minimum": 0, "maximum": 100],
                "animalSafetyScore": ["type": "integer", "minimum": 0, "maximum": 100],
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
    private func sendChat(body: [String: Any], apiKey: String, endpoint: String) async throws -> (content: String, data: Data, finishReason: String?) {
        let t0 = Date()
        var request = URLRequest(url: URL(string: endpoint)!)
        request.timeoutInterval = 60
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            #if DEBUG
            print("❌ OPENAI API: HTTP Error:", http.statusCode)
            print("Body:", String(data: data, encoding: .utf8) ?? "<none>")
            #endif
            throw NSError(domain: "OpenAIService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI API error: \(http.statusCode)"])
        }

        // Decode content as String or content parts
        let raw = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        let content = raw.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Try to read finish_reason from the raw JSON for retry logic
        var finish: String? = nil
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = obj["choices"] as? [[String: Any]],
           let first = choices.first {
            finish = first["finish_reason"] as? String
        }

#if DEBUG
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        print("⏱️ OpenAI sendChat elapsed: \(ms) ms, finish_reason=\(finish ?? "nil"), content_len=\(content.count)")
#endif
        return (content, data, finish)
    }

// MARK: - analyzeSafety implementation (OpenAIServiceType)

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
                    ["type": "json_object"],
                    [
                        "type": "json_schema",
                        "json_schema": ["name": "SafetyAnalysisResponse", "schema": safetyJSONSchema()]
                    ]
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
        You are a product safety analyst. Return JSON ONLY per the schema (0–100 integer scores for childSafetyScore, dogSafetyScore, catSafetyScore; animalSafetyScore = min(dog,cat); modelConfidence in 0–1; recognitionConfidence may be 0.0). No markdown, no code fences, no commentary.
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
        Analyze this product's safety.
        OPTIONS: { \(petFlags), includeChildren: \(input.includePetSafety ? "true" : "false") }

        Product guess (from Vision):
        - name: \(guess.name)
        - type: \(guess.type)
        - brand: \(guess.brand ?? "unknown")
        - vision_confidence: \(String(format: "%.2f", guess.confidence))

        OUTPUT:
        Return STRICT JSON matching the app schema. Provide 0–100 integer scores for childSafetyScore, dogSafetyScore, catSafetyScore; set animalSafetyScore = min(dog, cat). Fill modelConfidence 0.0–1.0. recognitionConfidence may be 0.0 (the app may overwrite from Vision).
        """

        // Helper to run a single request with a given response_format
        func runOnce(responseFormat: [String: Any]) async throws -> (String, Data, String?) {
            var body: [String: Any] = [
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

            // Race network vs timeout
            func send() async throws -> (String, Data, String?) {
                try await sendChat(body: body, apiKey: apiKey, endpoint: endpoint)
            }
            let ns = UInt64(timeout.components.seconds) * 1_000_000_000
            let (content, data, finish): (String, Data, String?) = try await withThrowingTaskGroup(of: (String, Data, String?).self) { group in
                group.addTask { try await send() }
                group.addTask {
                    try await Task.sleep(nanoseconds: ns)
                    throw NSError(domain: "OpenAIService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "timeout"])
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            return (content, data, finish)
        }

        // Cleaners & decoder
        func cleanedJSON(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
             .replacingOccurrences(of: "```json", with: "")
             .replacingOccurrences(of: "```", with: "")
        }
        func tryDecode(_ content: String, includeDogs: Bool, includeCats: Bool) -> SafetyAnalysisResponse? {
            let cleaned = cleanedJSON(content)
            guard let data = cleaned.data(using: .utf8) else { return nil }
            if var parsed = try? JSONDecoder().decode(SafetyAnalysisResponse.self, from: data) {
                // Normalize ranges, backfill, and cap using validator (parity with generateSafetyAnalysis)
                parsed.childSafetyScore = max(0, min(100, parsed.childSafetyScore))
                parsed.dogSafetyScore = parsed.dogSafetyScore.map { max(0, min(100, $0)) }
                parsed.catSafetyScore = parsed.catSafetyScore.map { max(0, min(100, $0)) }
                parsed.animalSafetyScore = max(0, min(100, parsed.animalSafetyScore))
                parsed.overallSafetyScore = max(0, min(100, parsed.overallSafetyScore))
                parsed.modelConfidence = max(0.0, min(1.0, parsed.modelConfidence))
                parsed.recognitionConfidence = max(0.0, min(1.0, parsed.recognitionConfidence))
                parsed.backfillAnimalScoresIfNeeded()
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
            }
            return nil
        }

        // Flags for validator
        let includeDogs = input.includePetSafety && (input.petPreference == .dog || input.petPreference == .both)
        let includeCats = input.includePetSafety && (input.petPreference == .cat || input.petPreference == .both)

        // Attempt primary format
        let (contentPrimary, _, _) = try await runOnce(responseFormat: primaryFormat)
        if let parsed = tryDecode(contentPrimary, includeDogs: includeDogs, includeCats: includeCats) {
            let mc = max(0.0, min(1.0, parsed.modelConfidence > 0 ? parsed.modelConfidence : 0.5))
            return (parsed, mc)
        }

        // Optional retry with schema (FAST tier only)
        if let fallback = fallbackFormat {
            let (contentFallback, _, _) = try await runOnce(responseFormat: fallback)
            if let parsed = tryDecode(contentFallback, includeDogs: includeDogs, includeCats: includeCats) {
                let mc = max(0.0, min(1.0, parsed.modelConfidence > 0 ? parsed.modelConfidence : 0.5))
                return (parsed, mc)
            }
        }

        #if DEBUG
        print("⚠️ analyzeSafety(\(tier)) failed to decode with both formats; returning mock.")
        #endif
        let mock = generateEnhancedMockAnalysis(SafetyAnalysisRequest(
            includeDogs: includeDogs,
            includeCats: includeCats,
            includeChildren: true
        ))
        return (mock, 0.5)
    }

// MARK: - Prompt Builder & Context Summary
    private func buildAnalysisPrompt(req: SafetyAnalysisRequest, context: Data?, imageHint: String? = nil) -> String {
        let evidence = imageHint ?? summarizeContext(context)
        var schema = """
        OUTPUT REQUIREMENT:
        Return JSON ONLY with this exact schema (keys and value types). Do NOT include any identification fields in the output; use them only to ground the analysis.
        {
          "productName": String,
          "productType": String,
          "overallSafetyScore": Int,            // 0–100
          "childSafetyScore": Int,              // 0–100
          "animalSafetyScore": Int,             // 0–100 (min(dog,cat))
          "dogSafetyScore": Int|null,           // 0–100
          "catSafetyScore": Int|null,           // 0–100
          "modelConfidence": Double,            // 0.0–1.0
          "recognitionConfidence": Double,      // 0.0–1.0 (you may set 0.0; app will overwrite from Vision)
          "generalSafety": {
            "pros": [{"label": String, "severity": "low"|"medium"|"high", "category": String}],
            "cons": [{"label": String, "severity": "low"|"medium"|"high", "category": String}]
          },
          "petSafety": {
            "dogs": [{"severity": "low"|"medium"|"high", "warning": String, "reason": String}],
            "cats": [{"severity": "low"|"medium"|"high", "warning": String, "reason": String}]
          },
          "hygieneWarnings": [{"type": String, "message": String}],
          "recalls": [{"date": String, "reason": String, "severity": "low"|"medium"|"high", "source": String}]
        }
        """

        let petSection: String = {
            var lines: [String] = []
            if req.includeDogs { lines.append("- Analyze safety for dogs (toxicity, choking hazards, behavioral risks)") }
            if req.includeCats { lines.append("- Analyze safety for cats (toxicity, choking hazards, behavioral risks)") }
            return lines.isEmpty ? "" : ("\nPET SAFETY ANALYSIS:\n" + lines.joined(separator: "\n"))
        }()

        let base = """
        Analyze the safety of this product.
        
        OPTIONS: { "includeDogs": \(req.includeDogs), "includeCats": \(req.includeCats), "includeChildren": \(req.includeChildren) }
        Return JSON only—no markdown, no code fences, no prose.

        STEP 1 — IDENTIFY FROM IMAGE (internal reasoning only, do not output this section):
        - Determine productType (one of: "food", "toy", "cosmetic", "electronic", "household", "clothing", "jewelry", "pharmaceutical", "automotive", "other").
        - Determine canonical productName the user would recognize.
        - List up to 3 brandCandidates visible or likely from the image/text/packaging.
        - List up to 5 high-level labels (what you see, e.g., "bottle", "snack", "logo").
        - List up to 5 localized objects (e.g., "power cord", "blade").
        - Extract any prominent detectedText from packaging (OCR).
        - Estimate a recognition confidence between 0.0 and 1.0.
        Use this identification to ground the safety analysis in STEP 2. Do NOT include these identification fields in the output JSON; they are for your reasoning only.

        STEP 2 — SAFETY ANALYSIS (this must be reflected in the JSON output):

        Provide a comprehensive safety analysis including (grounded in STEP 1 identification):
        OVERALL SAFETY SCORE (0-10) with rationale.
        GENERAL SAFETY: 2-4 pros and 2-4 cons with severity and category.
        HYGIENE WARNINGS and RECALLS if relevant.
        \(petSection)

        Use evidence (if provided) to stay specific:
        \(evidence)

        \(schema)
        """
        return base
    }

    private func summarizeContext(_ context: Data?) -> String {
    // If present: update generateSafetyAnalysis(_ req: SafetyAnalysisRequest, context: Data?) response_format
        guard let context else { return "(no extra evidence)" }
        guard let json = try? JSONSerialization.jsonObject(with: context) as? [String: Any] else { return "(evidence unavailable)" }

        var lines: [String] = []
        if let summary = json["summary"] as? [String: Any] {
            if let pn = summary["productName"] as? String { lines.append("- classifier.productName: \(pn)") }
            if let pt = summary["productType"] as? String { lines.append("- classifier.productType: \(pt)") }
            if let conf = summary["confidence"] as? Double { lines.append(String(format: "- classifier.confidence: %.2f", conf)) }
        }
        if let signals = json["signals"] as? [String: Any] {
            if let best = signals["bestGuess"] as? String, !best.isEmpty { lines.append("- bestGuess: \(best)") }
            if let labels = signals["labels"] as? [[String: Any]] {
                let top = labels.prefix(5).compactMap { $0["description"] as? String }
                if !top.isEmpty { lines.append("- topLabels: \(top.joined(separator: ", "))") }
            }
            if let objs = signals["objects"] as? [[String: Any]] {
                let top = objs.prefix(3).compactMap { $0["name"] as? String }
                if !top.isEmpty { lines.append("- objects: \(top.joined(separator: ", "))") }
            }
            if let ents = signals["webEntities"] as? [[String: Any]] {
                let top = ents.prefix(5).compactMap { $0["description"] as? String }
                if !top.isEmpty { lines.append("- webEntities: \(top.joined(separator: ", "))") }
            }
            if let text = signals["detectedText"] as? String, !text.isEmpty {
                let t = text.count > 200 ? String(text.prefix(200)) + "…" : text
                lines.append("- detectedText: \(t)")
            }
            if let brands = signals["brandCandidates"] as? [String], !brands.isEmpty {
                lines.append("- brands: \(brands.prefix(2).joined(separator: ", "))")
            }
        }
        return lines.isEmpty ? "(no extra evidence)" : lines.joined(separator: "\n")
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
        let animal100 = min(dog100, cat100)

        // Choose a conservative overall (child-focused here). SafetyAnalyzer will remap for pets.
        let overall = child100

        return SafetyAnalysisResponse(
            productName: name,
            productType: type,
            overallSafetyScore: overall,
            childSafetyScore: child100,
            animalSafetyScore: animal100,
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

