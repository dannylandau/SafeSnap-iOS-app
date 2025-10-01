import Foundation
import CoreGraphics
import UIKit

struct VisionLabelResult: Decodable {
    let labelAnnotations: [Annotation]?

    struct Annotation: Decodable {
        let description: String
        let score: Float?
    }
    func classifyProduct(from visionData: Data) throws -> ProductIdentification {
        // Minimal inline decoding models for the fields we need
        struct VisionApiResponse: Decodable {
            struct Response: Decodable {
                let labelAnnotations: [Annotation]?
                let textAnnotations: [TextAnnotation]?
                let logoAnnotations: [LogoAnnotation]?
                let webDetection: WebDetection?
                let localizedObjectAnnotations: [LocalizedObjectAnnotation]?
            }
            let responses: [Response]
        }

        struct TextAnnotation: Decodable { let description: String? }
        struct LogoAnnotation: Decodable { let description: String? }
        struct WebDetection: Decodable {
            struct WebEntity: Decodable { let description: String?; let score: Double? }
            struct BestGuessLabel: Decodable { let label: String? }
            let webEntities: [WebEntity]?
            let bestGuessLabels: [BestGuessLabel]?
        }
        struct LocalizedObjectAnnotation: Decodable { let name: String?; let score: Double? }

        // Decode
        let decoded = try JSONDecoder().decode(VisionApiResponse.self, from: visionData)
        guard let resp = decoded.responses.first else { throw VisionError.noProductFound }

        let labels = (resp.labelAnnotations ?? [])
        guard !labels.isEmpty else { throw VisionError.noProductFound }

        // Prepare feature sets
        let sortedLabels = labels.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        let labelStrings = sortedLabels.map { $0.description.lowercased() }

        let objects = (resp.localizedObjectAnnotations ?? [])
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
            .compactMap { $0.name?.lowercased() }

        let detectedText = resp.textAnnotations?.first?.description
        let brands = (resp.logoAnnotations ?? []).compactMap { $0.description }
        let webEntities = (resp.webDetection?.webEntities ?? [])
            .filter { ($0.score ?? 0) > 0.5 }
            .compactMap { $0.description?.lowercased() }
        let bestGuess = resp.webDetection?.bestGuessLabels?.first?.label?.lowercased() ?? ""

        // --- Heuristics ---
        // Keyword map per category (trimmed version of TS rules)
        let typeKeywords: [String: [String]] = [
            "food": ["fruit","vegetable","broccoli","carrot","tomato","bread","meat","fish","snack","meal","coffee","tea","juice","rice","pasta"],
            "household": ["cup","mug","glass","plate","bowl","fork","knife","spoon","bottle","jar","container","detergent","soap","cleaner","kitchen","towel"],
            "animal": ["animal","cat","dog","bird","fish","puppy","kitten"],
            "toy": ["toy","doll","lego","puzzle","action figure","blocks","teddy"],
            "cosmetic": ["cosmetics","makeup","lipstick","shampoo","lotion","perfume","deodorant","skincare"],
            "electronic": ["electronics","phone","smartphone","laptop","tablet","camera","headphones","speaker","charger"],
            "jewelry": ["jewelry","diamond","ring","necklace","bracelet","watch"],
            "clothing": ["clothing","shirt","pants","dress","shoes","jacket","socks","hat"]
        ]

        var typeScores = Dictionary(uniqueKeysWithValues: typeKeywords.keys.map { ($0, 0.0) })

        func bump(_ type: String, _ amount: Double) { typeScores[type, default: 0] += amount }
        func match(_ term: String, _ keyword: String) -> Bool { term.contains(keyword) || keyword.contains(term) }

        // Household vs food bias for cups/mugs
        let cupTerms = ["cup","mug","coffee cup","tea cup","coffee mug","tea mug","drinking cup"]
        let allTermsForBias = objects + webEntities + labelStrings + (bestGuess.isEmpty ? [] : [bestGuess])
        let hasCup = allTermsForBias.contains { t in cupTerms.contains { t.contains($0) || $0.contains(t) } }
        if hasCup { bump("household", 20); bump("food", -8) }

        // 1) Objects (highest weight)
        for obj in objects {
            for (type, kws) in typeKeywords {
                for kw in kws where match(obj, kw) {
                    bump(type, obj == kw ? 20 : 12)
                }
            }
        }

        // 2) Best guess (high weight)
        if !bestGuess.isEmpty {
            for (type, kws) in typeKeywords {
                for kw in kws where match(bestGuess, kw) {
                    bump(type, bestGuess == kw ? 10 : 6)
                }
            }
        }

        // 3) Web entities (medium)
        for ent in webEntities {
            for (type, kws) in typeKeywords {
                for kw in kws where match(ent, kw) {
                    bump(type, ent == kw ? 6 : 4)
                }
            }
        }

        // 4) High-confidence labels (>0.8)
        for l in sortedLabels where (l.score ?? 0) > 0.8 {
            for (type, kws) in typeKeywords {
                for kw in kws where match(l.description.lowercased(), kw) {
                    bump(type, (l.description.lowercased() == kw ? 5.0 : 3.5) * Double(l.score ?? 1))
                }
            }
        }
        // 5) Remaining labels (low)
        for l in sortedLabels where (l.score ?? 0) <= 0.8 {
            for (type, kws) in typeKeywords {
                for kw in kws where match(l.description.lowercased(), kw) {
                    bump(type, 1.0 * Double(l.score ?? 1))
                }
            }
        }
        // 6) Text (very low)
        if let text = detectedText?.lowercased() {
            for (type, kws) in typeKeywords {
                for kw in kws where text.contains(kw) { bump(type, 2) }
            }
        }

        // Pick best type
        let sortedTypes = typeScores.sorted { $0.value > $1.value }.filter { $0.value > 0 }
        let bestType = sortedTypes.first?.key ?? "other"

        let categoryNameMap: [String: String] = [
            "food": "Food",
            "household": "Household",
            "animal": "Animal",
            "toy": "Toy",
            "cosmetic": "Cosmetic",
            "electronic": "Electronic",
            "jewelry": "Jewelry",
            "clothing": "Clothing",
            "other": "Product"
        ]
        let categoryName = categoryNameMap[bestType] ?? "Product"

        // Decide specificType
        var specificType = objects.first ?? ""
        if specificType.isEmpty, !bestGuess.isEmpty { specificType = bestGuess }
        if specificType.isEmpty, let ent = webEntities.first { specificType = ent }
        if specificType.isEmpty { specificType = sortedLabels.first?.description.lowercased() ?? "unknown" }

        func clean(_ s: String) -> String {
            s.replacingOccurrences(of: "[^A-Za-z0-9\n\r -]", with: "", options: .regularExpression)
             .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
             .trimmingCharacters(in: .whitespacesAndNewlines)
             .split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        }

        let productName = "\(clean(specificType))"

        // Confidence (mirrors web weighting)
        var confidence = 0.0
        if !objects.isEmpty { confidence += 0.4 }
        let top5 = sortedLabels.prefix(5)
        if !top5.isEmpty {
            let avg = top5.reduce(0.0) { $0 + Double($1.score ?? 0) } / Double(top5.count)
            confidence += avg * 0.3
        }
        if !webEntities.isEmpty { confidence += 0.2 }
        if !bestGuess.isEmpty { confidence += 0.1 }
        confidence = min(confidence, 0.95)

        print("🛍️ Classified as \(categoryName) (\(bestType)), product: \(productName), confidence: \(String(format: "%.2f", confidence)), specificType: \(clean(specificType)), brands: \(brands), labels: \(labelStrings.prefix(5)), webEntities: \(webEntities.prefix(5)), objects: \(objects.prefix(3)), bestGuess: \(bestGuess), detectedText: \(detectedText ?? "nil")")
        
        return ProductIdentification(
            productType: categoryName,
            productName: productName,
            brandCandidates: brands,
            labels: labelStrings,
            objects: sortedLabels.map { $0.description },
            detectedText: detectedText,
            confidence: confidence
        )
    }
}

public struct VisionAnalysisResult {
    public let guess: ProductGuess
    public let labels: [String]
    public let objects: [String]
    public let detectedText: String?
    public let brandCandidates: [String]
    public let confidence: Double
    public let sanitizedContext: String?

    public init(
        guess: ProductGuess,
        labels: [String],
        objects: [String],
        detectedText: String?,
        brandCandidates: [String],
        confidence: Double,
        sanitizedContext: String?
    ) {
        self.guess = guess
        self.labels = labels
        self.objects = objects
        self.detectedText = detectedText
        self.brandCandidates = brandCandidates
        self.confidence = confidence
        self.sanitizedContext = sanitizedContext
    }
}

public protocol VisionServiceType {
    func recognizeProduct(from image: CGImage) async throws -> ProductGuess
    func analyze(image: UIImage) async throws -> VisionAnalysisResult
}

public extension VisionServiceType {
    func analyze(image: UIImage) async throws -> VisionAnalysisResult {
        guard let cgImage = image.cgImage else { throw VisionError.invalidImageData }
        let guess = try await recognizeProduct(from: cgImage)
        let brands = guess.brand.map { [$0] } ?? []
        return VisionAnalysisResult(
            guess: guess,
            labels: [],
            objects: [],
            detectedText: nil,
            brandCandidates: brands,
            confidence: guess.confidence,
            sanitizedContext: nil
        )
    }
}

enum VisionError: LocalizedError {
    case missingAPIKey
    case invalidImageData
    case failedRequest
    case noProductFound
}

final class VisionService: VisionServiceType {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyze(image: UIImage) async throws -> VisionAnalysisResult {
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            throw VisionError.invalidImageData
        }

        let rawData = try await detectProducts(in: jpeg)
        let classifier = VisionLabelResult(labelAnnotations: nil)
        let identification = try classifier.classifyProduct(from: rawData)

        let guess = ProductGuess(
            name: identification.productName,
            type: identification.productType,
            confidence: max(0.0, min(1.0, identification.confidence)),
            brand: identification.brandCandidates.first
        )

        let sanitizedData = try? sanitizedOpenAIData(from: rawData)
        let sanitizedContext: String?
        if let sanitizedData,
           let json = String(data: sanitizedData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !json.isEmpty {
            sanitizedContext = json
        } else {
            sanitizedContext = nil
        }

        return VisionAnalysisResult(
            guess: guess,
            labels: identification.labels,
            objects: identification.objects,
            detectedText: identification.detectedText,
            brandCandidates: identification.brandCandidates,
            confidence: guess.confidence,
            sanitizedContext: sanitizedContext
        )
    }

    func detectProducts(in imageData: Data) async throws -> Data {
        
        guard !apiKey.isEmpty else {
            #if DEBUG
            print("⚠️ Google Vision API key is missing. Falling back to mock.")
            #endif
            throw VisionError.missingAPIKey
        }

        let base64Image = imageData.base64EncodedString()

        let requestPayload: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [["type": "LABEL_DETECTION", "maxResults": 50],
                                ["type": "TEXT_DETECTION", "maxResults": 20],
                                ["type": "LOGO_DETECTION", "maxResults": 20],
                                ["type": "WEB_DETECTION", "maxResults": 20],
                                ["type": "OBJECT_LOCALIZATION", "maxResults": 20],
                                ["type": "IMAGE_PROPERTIES"]],
                    "imageContext": [ "webDetectionParams": ["includeGeoResults": true],
                                      "textDetectionParams": ["enableTextDetectionConfidenceScore": true]
                                      ]
                ]
            ]
        ]

        let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
#if DEBUG
            if let payload = try? JSONSerialization.data(withJSONObject: requestPayload, options: .prettyPrinted),
               let jsonString = String(data: payload, encoding: .utf8) {
                print("📤 Request Payload:\n\(jsonString)")
            }
#endif
            throw VisionError.failedRequest
        }
#if DEBUG
        print("📡 Status Code: \(httpResponse.statusCode)")
#endif
        guard (200...299).contains(httpResponse.statusCode) else {
            throw VisionError.failedRequest
        }
#if DEBUG
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("📦 Google Vision raw response:\n\(rawResponse)")
        }
#endif
        return data
    }

    /// Returns a compact JSON payload (Data) tailored for OpenAI prompts.
    /// It removes heavy URL lists and keeps only high-signal fields.
    /// - Keeps: top labels/objects/web entities, first text block, best guess, logo candidates, dominant colors (top 5), counts of web matches
    /// - Drops: fullMatchingImages/partialMatchingImages/pagesWithMatchingImages/visuallySimilarImages URLs
    func sanitizedOpenAIData(from visionData: Data) throws -> Data {
        // Inline light models to decode just what we need
        struct VisionApiResponse: Decodable {
            struct Response: Decodable {
                let labelAnnotations: [Label]?
                let textAnnotations: [Text]?
                let logoAnnotations: [Logo]?
                let webDetection: WebDetection?
                let localizedObjectAnnotations: [Obj]?
                let imagePropertiesAnnotation: ImageProps?
            }
            let responses: [Response]
        }
        struct Label: Decodable { let description: String; let score: Double? }
        struct Text: Decodable { let description: String? }
        struct Logo: Decodable { let description: String? }
        struct Obj: Decodable { let name: String?; let score: Double? }
        struct WebDetection: Decodable {
            struct WebEntity: Decodable { let description: String?; let score: Double? }
            let webEntities: [WebEntity]?
            // The following arrays are intentionally *not* modeled: fullMatchingImages, partialMatchingImages, pagesWithMatchingImages, visuallySimilarImages
            struct BestGuessLabel: Decodable { let label: String?; let languageCode: String? }
            let bestGuessLabels: [BestGuessLabel]?
        }
        struct ImageProps: Decodable {
            struct DominantColors: Decodable {
                struct ColorItem: Decodable {
                    struct RGB: Decodable { let red: Int?; let green: Int?; let blue: Int? }
                    let color: RGB
                    let score: Double?
                    let pixelFraction: Double?
                }
                let colors: [ColorItem]
            }
            let dominantColors: DominantColors
        }

        // Decode once
        let decoded = try JSONDecoder().decode(VisionApiResponse.self, from: visionData)
        guard let first = decoded.responses.first else { throw VisionError.noProductFound }

        // Collect fields (with limits)
        let labels = (first.labelAnnotations ?? [])
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        let topLabels = Array(labels.prefix(10)).map { ["description": $0.description, "score": $0.score ?? 0] }

        let objects = (first.localizedObjectAnnotations ?? [])
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        let topObjects = Array(objects.prefix(10)).compactMap { obj -> [String: Any]? in
            guard let name = obj.name else { return nil }
            return ["name": name, "score": obj.score ?? 0]
        }

        let webEntities = (first.webDetection?.webEntities ?? [])
            .filter { ($0.score ?? 0) > 0.5 }
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        let topEntities = Array(webEntities.prefix(10)).compactMap { ent -> [String: Any]? in
            guard let desc = ent.description else { return nil }
            return ["description": desc, "score": ent.score ?? 0]
        }

        let bestGuess = first.webDetection?.bestGuessLabels?.first?.label
        let detectedText = (first.textAnnotations?.first?.description ?? "")
        let trimmedText: String = {
            let s = detectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.count > 500 { return String(s.prefix(500)) + "…" }
            return s
        }()

        let brands = Array((first.logoAnnotations ?? []).compactMap { $0.description }.prefix(3))

        // Dominant colors (top 5), include RGB and a hex for convenience
        func toHex(_ r: Int?, _ g: Int?, _ b: Int?) -> String {
            let rr = max(0, min(255, r ?? 0))
            let gg = max(0, min(255, g ?? 0))
            let bb = max(0, min(255, b ?? 0))
            return String(format: "#%02X%02X%02X", rr, gg, bb)
        }
        let colorItems = first.imagePropertiesAnnotation?.dominantColors.colors ?? []
        let topColors = Array(colorItems.prefix(5)).map { c in
            [
                "rgb": [c.color.red ?? 0, c.color.green ?? 0, c.color.blue ?? 0],
                "hex": toHex(c.color.red, c.color.green, c.color.blue),
                "score": c.score ?? 0,
                "pixelFraction": c.pixelFraction ?? 0
            ] as [String: Any]
        }

        // Lightweight classification summary (reusing our classifier)
        let classifier = VisionLabelResult(labelAnnotations: nil)
        let classification: ProductIdentification = (try? classifier.classifyProduct(from: visionData)) ?? ProductIdentification(
            productType: "ProductType - Unknown",
            productName: "Product - Unknown",
//            specificType: "Unknown",
            brandCandidates: brands,
            labels: labels.map { $0.description },
            objects: topObjects.compactMap { $0["name"] as? String },
            detectedText: trimmedText.isEmpty ? nil : trimmedText,
            confidence: 0
        )

        // Build compact dictionary
        var payload: [String: Any] = [
            "summary": [
                "productName": classification.productName,
                "categoryName": classification.productType,
//                "specificType": classification.specificType,
                "productType": classification.productType,
                "brand": classification.brandCandidates.first as Any,
                "confidence": classification.confidence
            ],
            "signals": [
                "bestGuess": bestGuess as Any,
                "labels": topLabels,
                "objects": topObjects,
                "webEntities": topEntities,
                "detectedText": trimmedText,
                "brandCandidates": brands,
                "dominantColors": topColors
            ],
            "counts": [
                // Keep only counts, not the heavy URL arrays
                "fullMatchingImages": 0,
                "partialMatchingImages": 0,
                "pagesWithMatchingImages": 0
            ],
            "meta": [
                "source": "GoogleVision images:annotate",
                "schema": 1
            ]
        ]

        // If you want to communicate the *presence* of matches without the bulk, include counts when available.
        // We didn’t decode those arrays; leave counts at 0 intentionally to keep this routine light.

        // Encode compact JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])

        #if DEBUG
        print("📦 OpenAI payload size reduced from \(visionData.count)B to \(jsonData.count)B")
        #endif

        return jsonData
    }
    /// Recognize product name/type from a CGImage using Google Vision and our classifier.
    /// - Returns: `ProductGuess` with name, type, confidence, and first brand candidate if available.
    public func recognizeProduct(from image: CGImage) async throws -> ProductGuess {
        // 1) Encode CGImage to JPEG data
        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) else {
            throw VisionError.invalidImageData
        }

        // 2) Call Vision API
        let raw = try await detectProducts(in: jpeg)

        // 3) Classify using existing heuristics
        let classifier = VisionLabelResult(labelAnnotations: nil)
        let identification = try classifier.classifyProduct(from: raw)

        // 4) Map to ProductGuess expected by the app
        let brand = identification.brandCandidates.first
        let confidence = max(0.0, min(1.0, identification.confidence))
        return ProductGuess(
            name: identification.productName,
            type: identification.productType,
            confidence: confidence,
            brand: brand
        )
    }
}
