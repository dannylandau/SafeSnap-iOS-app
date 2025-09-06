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
    private let endpoint = URL(string: "https://api.gemini.example.com/v1/analyze")!
    private let model = "gemini-1.5-flash"
    private var currentTask: URLSessionDataTask?
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func analyzeSafety(image: UIImage, options: SafetyOptions, streamToken: @escaping (String) -> Void) async throws -> SafetyAnalysisResponse {
        streamToken("Analyzing with Gemini…")
        let body = try makeRequestBody(image: image, options: options)
        let (data, response) = try await makeNonStreamingRequest(body: body)
        
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
        guard let text = api.candidates?.first?.content.parts.first?.text,
              let finalData = text.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Gemini returned no JSON text"])
        }
        print(text)
        let result = try JSONDecoder().decode(SafetyAnalysisResponse.self, from: finalData)
        return result
    }
    
    func cancelAnalysis() {
        currentTask?.cancel()
    }
    
    private func makeRequestBody(image: UIImage, options: SafetyOptions) throws -> Data {
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
        
        let generationConfig: [String: Any] = [
            "temperature": 0.2,
            "maxOutputTokens": 512,
            "responseMimeType": "application/json",
            "responseSchema": SafetyAnalysisSchema.geminiResponseSchema()
        ]
        
        let bodyDict: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": "You are a product safety analyst. Return JSON only that matches the provided schema."],
                    ["text": petDirective]
                ]
            ],
            "contents": [[
                "role": "user",
                "parts": [
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]],
                    ["text": "Use integers 0-100 for scores, modelConfidence 0.0-1.0. Use nulls or empty arrays when unknown. \n\nPet rules: \(petDirective)" ]
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
    
    private func makeNonStreamingRequest(body: Data) async throws -> (Data, URLResponse) {
        var comps = URLComponents(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = decodeGoogleError(from: data) ?? "HTTP \(http.statusCode)"
            print("Gemini generateContent error: \(msg)")
            throw NSError(domain: "GeminiService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return (data, response)
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
