//
//  ArchieAPIService.swift
//  Archie
//
//  Centralized API client for Archie backend
//

import Foundation
import UIKit

// MARK: - API Configuration

enum APIEnvironment {
    case production
    case development
    
    var baseURL: String {
        switch self {
        case .production:
            return "https://be.archieml.com"
        case .development:
            return "http://localhost:4000"
        }
    }
}

// MARK: - API Errors

enum ArchieAPIError: LocalizedError {
    case invalidURL
    case encodingFailed
    case decodingFailed(underlying: Error)
    case httpError(statusCode: Int, message: String?)
    case unauthorized
    case notFound
    case networkError(underlying: Error)
    case imageEncodingFailed
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .encodingFailed:
            return "Failed to encode request data"
        case .decodingFailed(let error):
            return "Failed to decode response: \(Self.detailedDecodingError(error))"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message ?? "Unknown error")"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .notFound:
            return "Resource not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .imageEncodingFailed:
            return "Failed to encode image"
        case .noData:
            return "No data received from server"
        }
    }
    
    /// Extracts detailed information from a DecodingError
    private static func detailedDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        
        switch decodingError {
        case .keyNotFound(let key, let context):
            let path = codingPathString(context.codingPath)
            return "Missing key '\(key.stringValue)' at path: \(path.isEmpty ? "root" : path). \(context.debugDescription)"
            
        case .typeMismatch(let type, let context):
            let path = codingPathString(context.codingPath)
            return "Type mismatch for '\(type)' at path: \(path.isEmpty ? "root" : path). \(context.debugDescription)"
            
        case .valueNotFound(let type, let context):
            let path = codingPathString(context.codingPath)
            return "Missing value of type '\(type)' at path: \(path.isEmpty ? "root" : path). \(context.debugDescription)"
            
        case .dataCorrupted(let context):
            let path = codingPathString(context.codingPath)
            return "Data corrupted at path: \(path.isEmpty ? "root" : path). \(context.debugDescription)"
            
        @unknown default:
            return decodingError.localizedDescription
        }
    }
    
    /// Converts a coding path to a readable string like "analysisMetadata.isHumorMode"
    private static func codingPathString(_ path: [CodingKey]) -> String {
        path.map { key in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }
            return key.stringValue
        }.joined(separator: ".")
    }
}

// MARK: - API Protocol

/// Protocol for product analysis API - enables testing with mocks
protocol ProductAnalyzing {
    func analyze(
        image: UIImage,
        includeDogs: Bool,
        includeCats: Bool,
        includeChildren: Bool
    ) async throws -> ProductAnalysis
    
    func saveToHistory(
        item: APIHistoryItem
    ) async throws -> HistorySaveResponse
}

// MARK: - API Service

final class ArchieAPIService: ProductAnalyzing {
    
    // MARK: - Properties
    
    private let environment: APIEnvironment
    private let session: URLSession
    private var cachedToken: String?
    private let tokenProvider: (() async throws -> String?)?
    
    // MARK: - Singleton
    
    static let shared = ArchieAPIService()
    
    // MARK: - Init
    
    init(
        environment: APIEnvironment = .production,
        tokenProvider: (() async throws -> String?)? = nil,
        configuration: URLSessionConfiguration = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 120
            return config
        }()
    ) {
        self.environment = environment
        self.tokenProvider = tokenProvider
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Token Management
    
    func setTokenProvider(_ provider: @escaping () async throws -> String?) {
        // This would require making tokenProvider a var, but for simplicity
        // we'll use the cached token approach
    }
    
    func setToken(_ token: String?) {
        cachedToken = token
    }
    
    func clearToken() {
        cachedToken = nil
    }
    
    private func getAuthToken() async throws -> String? {
        if let provider = tokenProvider {
            return try await provider()
        }
        return cachedToken
    }
    
    // MARK: - Generic Request Methods
    
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = false,
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(environment.baseURL)\(endpoint)") else {
            throw ArchieAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            if let token = try await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArchieAPIError.networkError(underlying: URLError(.badServerResponse))
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                #if DEBUG
                if endpoint == "/api/analyze" {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📦 [ArchieAPI] /api/analyze response body:")
                        print(jsonString)
                    }
                }
                #endif
                
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(T.self, from: data)
                } catch {
                    #if DEBUG
                    print("❌ [ArchieAPI] Decoding error for \(endpoint)")
                    print("   Target type: \(T.self)")
                    if let decodingError = error as? DecodingError {
                        print("   \(Self.formatDecodingError(decodingError))")
                    } else {
                        print("   Error: \(error)")
                    }
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📦 [ArchieAPI] Raw response that failed to decode:")
                        print(jsonString)
                    }
                    #endif
                    throw ArchieAPIError.decodingFailed(underlying: error)
                }
            case 401:
                throw ArchieAPIError.unauthorized
            case 404:
                throw ArchieAPIError.notFound
            default:
                let message = extractErrorMessage(from: data)
                throw ArchieAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as ArchieAPIError {
            throw error
        } catch {
            throw ArchieAPIError.networkError(underlying: error)
        }
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["message"] as? String ?? json["error"] as? String
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Formats a DecodingError for debug logging
    private static func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Missing key '\(key.stringValue)' at path: \(path.isEmpty ? "root" : path)"
            
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Type mismatch: expected '\(type)' at path: \(path.isEmpty ? "root" : path). \(context.debugDescription)"
            
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Missing value of type '\(type)' at path: \(path.isEmpty ? "root" : path)"
            
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Data corrupted at path: \(path.isEmpty ? "root" : path). \(context.debugDescription)"
            
        @unknown default:
            return error.localizedDescription
        }
    }
    
    // MARK: - Authentication API
    
    struct LoginRequest: Encodable {
        let idToken: String
    }
    
    struct LoginResponse: Decodable {
        let status: String
        let token: String
        let user: APIUser
    }
    
    struct APIUser: Decodable {
        let uid: String
        let email: String?
        let displayName: String?
        let photoURL: String?
    }
    
    struct MeResponse: Decodable {
        let user: APIUser?
    }
    
    struct ProfileResponse: Decodable {
        let user: APIUserProfile?
    }
    
    struct APIUserProfile: Decodable {
        let uid: String
        let email: String?
        let displayName: String?
        let photoURL: String?
        let createdAt: String?
    }
    
    struct UpdateProfileRequest: Encodable {
        let displayName: String
    }
    
    struct UpdateProfileResponse: Decodable {
        let success: Bool
        let message: String
        let user: PartialUser
        
        struct PartialUser: Decodable {
            let uid: String
            let displayName: String
        }
    }
    
    struct LogoutResponse: Decodable {
        let status: String
        let message: String
    }
    
    func login(idToken: String) async throws -> LoginResponse {
        let body = try JSONEncoder().encode(LoginRequest(idToken: idToken))
        return try await makeRequest(
            endpoint: "/api/auth/login",
            method: "POST",
            body: body,
            responseType: LoginResponse.self
        )
    }
    
    func getCurrentUser() async throws -> MeResponse {
        return try await makeRequest(
            endpoint: "/api/auth/me",
            requiresAuth: true,
            responseType: MeResponse.self
        )
    }
    
    func getProfile() async throws -> ProfileResponse {
        return try await makeRequest(
            endpoint: "/api/auth/profile",
            requiresAuth: true,
            responseType: ProfileResponse.self
        )
    }
    
    func updateProfile(displayName: String) async throws -> UpdateProfileResponse {
        let body = try JSONEncoder().encode(UpdateProfileRequest(displayName: displayName))
        return try await makeRequest(
            endpoint: "/api/auth/profile",
            method: "PATCH",
            body: body,
            requiresAuth: true,
            responseType: UpdateProfileResponse.self
        )
    }
    
    func logout() async throws -> LogoutResponse {
        return try await makeRequest(
            endpoint: "/api/auth/logout",
            method: "POST",
            requiresAuth: true,
            responseType: LogoutResponse.self
        )
    }
    
    // MARK: - Analysis API
    
    struct AnalyzeRequest: Encodable {
        let imageBase64: String
        let options: AnalysisOptions
        
        struct AnalysisOptions: Encodable {
            let includeDogs: Bool
            let includeCats: Bool
            let includeChildren: Bool
        }
    }
    
    func analyze(
        image: UIImage,
        includeDogs: Bool = true,
        includeCats: Bool = true,
        includeChildren: Bool = true
    ) async throws -> ProductAnalysis {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw ArchieAPIError.imageEncodingFailed
        }
        
        // Base64 without data: prefix as per API spec
        let base64Image = imageData.base64EncodedString()
        
        let request = AnalyzeRequest(
            imageBase64: base64Image,
            options: .init(
                includeDogs: includeDogs,
                includeCats: includeCats,
                includeChildren: includeChildren
            )
        )
        
        let body = try JSONEncoder().encode(request)
        
        return try await makeRequest(
            endpoint: "/api/analyze",
            method: "POST",
            body: body,
            responseType: ProductAnalysis.self
        )
    }
    
    // MARK: - History API
    
    struct HistorySaveRequest: Encodable {
        let item: APIHistoryItem
    }
    
    func getHistory() async throws -> [APIHistoryItem] {
        return try await makeRequest(
            endpoint: "/api/history",
            requiresAuth: true,
            responseType: [APIHistoryItem].self
        )
    }
    
    func saveToHistory(item: APIHistoryItem) async throws -> HistorySaveResponse {
        let request = HistorySaveRequest(item: item)
        let body = try JSONEncoder().encode(request)
        
        return try await makeRequest(
            endpoint: "/api/history",
            method: "POST",
            body: body,
            requiresAuth: true,
            responseType: HistorySaveResponse.self
        )
    }
    
    func deleteFromHistory(id: String) async throws -> HistoryDeleteResponse {
        return try await makeRequest(
            endpoint: "/api/history?id=\(id)",
            method: "DELETE",
            requiresAuth: true,
            responseType: HistoryDeleteResponse.self
        )
    }
    
    // MARK: - Sharing API
    
    /// Fetch a shared analysis by ID
    func getSharedAnalysis(id: String) async throws -> ProductAnalysis {
        return try await makeRequest(
            endpoint: "/api/analysis/\(id)",
            responseType: ProductAnalysis.self
        )
    }
}

struct HistorySaveResponse: Decodable {
    let success: Bool
    let message: String
}

struct HistoryDeleteResponse: Decodable {
    let success: Bool
    let message: String
}

struct APIHistoryItem: Codable {
    let id: String
    let createdAt: String
    let name: String
    let score: Int
    let maxScore: Int
    let preview: String?
    let imageUrl: String?
    let labels: [String]
    let category: String?
    let petSafetyOptions: PetSafetyOptions?
    let fullAnalysis: ProductAnalysis?
}
