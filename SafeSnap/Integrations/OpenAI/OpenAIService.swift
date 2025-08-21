//
//  OpenAIService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 30/07/2025.
//

import Foundation

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

final class OpenAIService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - New Safety Analysis API (parity with web)
    @MainActor
    func generateSafetyAnalysis(_ req: SafetyAnalysisRequest, context: Data?) async throws -> SafetyAnalysisResponse {
        #if DEBUG
        let keyPreview = apiKey.isEmpty ? "NOT_SET" : String(apiKey.prefix(8)) + "…"
        print("🔍 OPENAI KEY CHECK:", [
            "exists": !apiKey.isEmpty,
            "length": apiKey.count,
            "preview": keyPreview,
            "startsWithSk": apiKey.hasPrefix("sk-")
        ])
        print("🐕🐱 PET ANALYSIS REQUEST:", [
            "productName": req.productName,
            "includeDogs": req.includeDogs,
            "includeCats": req.includeCats,
            "includeChildren": req.includeChildren
        ])
        #endif

        guard isKeyValid(apiKey) else {
            #if DEBUG
            print("🤖 OPENAI API: Key not configured - using enhanced mock analysis")
            #endif
            return generateEnhancedMockAnalysis(req)
        }

        // Build prompt (with optional compact evidence from Vision context)
        let prompt = buildAnalysisPrompt(req: req, context: context)
        #if DEBUG
        print("📝 Prompt length:", prompt.count)
        #endif

        // Prepare request
        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a product safety expert with extensive knowledge of consumer product safety, regulatory standards, and health risks. Provide accurate, evidence-based safety assessments. Respond with JSON ONLY matching the schema."],
            ["role": "user", "content": prompt]
        ]

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 2000
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            #if DEBUG
            print("❌ OPENAI API: HTTP Error:", http.statusCode)
            print("Body:", String(data: data, encoding: .utf8) ?? "<none>")
            #endif
            throw NSError(domain: "OpenAIService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI API error: \(http.statusCode)"])
        }

        let raw = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = raw.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "OpenAIService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No analysis content received from OpenAI"])
        }

        // Expect strict JSON; strip optional code fences
        let cleaned = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        // Try to decode SafetyAnalysisResponse
        if let data = cleaned.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(SafetyAnalysisResponse.self, from: data) {
            // Backup score validation (conservative)
            let validated = validateSafetyScoreConsistency(
                primaryScore: parsed.overallSafetyScore,
                productName: req.productName.lowercased(),
                petSafety: parsed.petSafety,
                cons: parsed.generalSafety.cons,
                recalls: parsed.recalls,
                shouldAnalyzePets: (req.includeDogs || req.includeCats) || isDangerousToAllPets(req.productName)
            )
            var final = parsed
            final.overallSafetyScore = min(parsed.overallSafetyScore, validated)
            #if DEBUG
            print("✅ Parsed SafetyAnalysisResponse. Score=\(parsed.overallSafetyScore) Validated=\(validated)")
            print(final)
            #endif
            return final
        }

        #if DEBUG
        print("⚠️ Failed to decode strict JSON. Falling back to enhanced mock. Content=\n\(cleaned)")
        #endif
        return generateEnhancedMockAnalysis(req)
    }

    // MARK: - Prompt Builder & Context Summary
    private func buildAnalysisPrompt(req: SafetyAnalysisRequest, context: Data?) -> String {
        let evidence = summarizeContext(context)
        var schema = """
        Return JSON ONLY with this exact schema (keys and value types):
        {
          "overallSafetyScore": Int,
          "generalSafety": {
            "pros": [{"label": String, "severity": "low"|"medium"|"high", "category": String}],
            "cons": [{"label": String, "severity": "low"|"medium"|"high", "category": String}]
          },
        """
        if req.includeCats || req.includeDogs {
            schema += """
          "petSafety": {
            "dogs": [{"severity": "low"|"medium"|"high", "warning": String, "reason": String}],
            "cats": [{"severity": "low"|"medium"|"high", "warning": String, "reason": String}]
          },
        """
        }
          schema += """
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
        Analyze the safety of this product: "\(req.productName)" (Category: \(req.productType))

        Provide a comprehensive safety analysis including:
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
        let name = request.productName.lowercased()
        let type = request.productType

        let dangerousToAllPets = isDangerousToAllPets(name)
        let userRequestedPet = request.includeDogs || request.includeCats
        let shouldAnalyzePets = dangerousToAllPets || userRequestedPet

        var initialScore = calculateInitialSafetyScore(productName: name, productType: type, shouldAnalyzePets: shouldAnalyzePets)
        let ctx = generateContextualSafetyConcerns(productName: name, productType: type, safetyScore: initialScore, request: request)

        let petSafety = SafetyAnalysisResponse.PetSafety(
            dogs: ((shouldAnalyzePets && request.includeDogs) || dangerousToAllPets) ? generatePetWarnings(petType: "dog", productName: name, productType: type) : [],
            cats: ((shouldAnalyzePets && request.includeCats) || dangerousToAllPets) ? generatePetWarnings(petType: "cat", productName: name, productType: type) : []
        )

        let hygiene = generateHygieneWarnings(productName: name, productType: type)
        let recalls = generateRecalls(productName: name, productType: type)

        var finalScore = calculateFinalSafetyScore(
            initialScore: initialScore,
            productName: name,
            petSafety: petSafety,
            cons: ctx.cons,
            recalls: recalls,
            shouldAnalyzePets: shouldAnalyzePets
        )

        let backup = validateSafetyScoreConsistency(
            primaryScore: finalScore,
            productName: name,
            petSafety: petSafety,
            cons: ctx.cons,
            recalls: recalls,
            shouldAnalyzePets: shouldAnalyzePets
        )
        finalScore = min(finalScore, backup)

        return SafetyAnalysisResponse(
            overallSafetyScore: finalScore,
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

    private func validateSafetyScoreConsistency(primaryScore: Int, productName: String, petSafety: SafetyAnalysisResponse.PetSafety, cons: [SafetyAnalysisResponse.LabeledItem], recalls: [SafetyAnalysisResponse.Recall], shouldAnalyzePets: Bool) -> Int {
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
    }

    let choices: [Choice]
}

private extension Bundle {
    func apiKey(named key: String) -> String? {
        infoDictionary?[key] as? String
    }
}
