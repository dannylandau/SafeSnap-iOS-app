//
//  GeminiService.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import Foundation
import UIKit

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
    private var currentTask: URLSessionDataTask?
    private let session = URLSession(configuration: .default)
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func analyzeSafety(image: UIImage, options: SafetyOptions, streamToken: @escaping (String) -> Void) async throws -> SafetyAnalysisResponse {
        streamToken("Analyzing with Gemini…")
        let body = try makeRequestBody(image: image, options: options)
        let (data, response, taskRef) = try await makeNonStreamingRequest(body: body)
        self.currentTask = taskRef
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
        
        if let finalData = sanitizedText.data(using: .utf8) {
            do {
                return try JSONDecoder().decode(SafetyAnalysisResponse.self, from: finalData)
            } catch {
                // If likely truncation, retry once with higher token limit
                if sanitizedText.count > 0 {
                    streamToken("Retrying with larger token limit…")
                    let retryBody = try makeRequestBody(image: image, options: options, maxTokensOverride: 768)
                    let (retryData, retryResponse, retryTask) = try await makeNonStreamingRequest(body: retryBody)
                    self.currentTask = retryTask
                    guard let http2 = retryResponse as? HTTPURLResponse, (200..<300).contains(http2.statusCode) else {
                        throw URLError(.badServerResponse)
                    }
                    let retryApi = try JSONDecoder().decode(GenerateContentResponse.self, from: retryData)
                    guard let retryText = retryApi.candidates?.first?.content.parts.first?.text,
                          let retryFinal = retryText.data(using: .utf8) else {
                        throw NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Gemini returned no JSON on retry"])
                    }
                    return try JSONDecoder().decode(SafetyAnalysisResponse.self, from: retryFinal)
                }
                throw error
            }
        } else {
            throw NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unable to encode Gemini text as UTF-8"])
        }
    }
    
    func cancelAnalysis() {
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
        let specificityDirective: String = """
        Be maximally specific when naming the product. If it's a mushroom, identify the species (e.g., 'shiitake', 'chanterelle'); if it's a plant/fruit/vegetable/herb/spice or any item with varieties, name the exact type/variety where possible (e.g., 'Gala apple', 'Roma tomato', 'curly parsley'). Use context from the image (shape, color, texture, packaging text) to disambiguate. Score safety for the specific type you identify. If two types are plausible, pick the most likely and reflect uncertainty via recognitionConfidence and modelConfidence. Do NOT invent fields outside the schema.
        """
        let ocrDirective: String = """
        Read any visible text directly from the image (OCR). Extract brand names, variety/species, flavor, size/weight, and any qualifiers (e.g., organic). Prefer OCR tokens to determine the exact product/variety name. Do not include the OCR text itself in your output; return JSON only that matches the schema. When OCR and visual cues agree, raise recognitionConfidence; when they conflict or are unclear, lower it and choose the most likely single specific type.
        """
        
        let generationConfig: [String: Any] = [
            "temperature": 0.2,
            "topK": 40,
            "topP": 0.9,
            "maxOutputTokens": maxTokensOverride ?? 640,
            "responseMimeType": "application/json",
            "responseSchema": SafetyAnalysisSchema.geminiResponseSchema()
        ]
        
        let bodyDict: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": "You are a product safety analyst. Return JSON only that matches the provided schema."],
                    ["text": petDirective],
                    ["text": ocrDirective],
                    ["text": specificityDirective],
                    ["text": "Examples: 1) Image shows brown gills, convex cap with white stem → 'Mushroom — shiitake'. 2) Small red apple with yellow streaks, label 'Gala' visible → 'Apple — Gala'. 3) Long plum tomato on vine → 'Tomato — Roma'."],
                ]
            ],
            "contents": [[
                "role": "user",
                "parts": [
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]],
                    ["text": "Use integers 0-100 for scores, modelConfidence 0.0-1.0. Use nulls or empty arrays when unknown.\n\nOCR: Read any visible label/packaging text from the image and use it to decide the exact product/variety. Do not print OCR text; return JSON only.\n\nPet rules: \(petDirective)\n\nSpecificity: \(specificityDirective)\nAvoid generic names like 'mushroom', 'apple', 'lettuce' unless recognitionConfidence < 0.5." ]
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
            var task: URLSessionDataTask?
            task = session.dataTask(with: req) { data, response, error in
                if let error = error { return continuation.resume(throwing: error) }
                guard let data = data, let response = response, let task = task else {
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
            task?.resume()
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
