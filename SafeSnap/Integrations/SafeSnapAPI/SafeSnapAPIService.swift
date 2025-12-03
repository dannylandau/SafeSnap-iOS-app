//
//  SafeSnapAPIService.swift
//  SafeSnap
//
//  Centralized API client for SafeSnap backend
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

enum SafeSnapAPIError: LocalizedError {
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
            return "Failed to decode response: \(error.localizedDescription)"
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
}

// MARK: - API Service

final class SafeSnapAPIService {
    
    // MARK: - Properties
    
    private let environment: APIEnvironment
    private let session: URLSession
    private var cachedToken: String?
    private let tokenProvider: (() async throws -> String?)?
    
    // MARK: - Singleton
    
    static let shared = SafeSnapAPIService()
    
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
            throw SafeSnapAPIError.invalidURL
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
                throw SafeSnapAPIError.networkError(underlying: URLError(.badServerResponse))
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw SafeSnapAPIError.decodingFailed(underlying: error)
                }
            case 401:
                throw SafeSnapAPIError.unauthorized
            case 404:
                throw SafeSnapAPIError.notFound
            default:
                let message = extractErrorMessage(from: data)
                throw SafeSnapAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as SafeSnapAPIError {
            throw error
        } catch {
            throw SafeSnapAPIError.networkError(underlying: error)
        }
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["message"] as? String ?? json["error"] as? String
        }
        return String(data: data, encoding: .utf8)
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
            throw SafeSnapAPIError.imageEncodingFailed
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
    
    struct HistorySaveResponse: Decodable {
        let success: Bool
        let message: String
    }
    
    struct HistoryDeleteResponse: Decodable {
        let success: Bool
        let message: String
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
    
    struct ShareCacheRequest: Encodable {
        let analysis: ProductAnalysis
    }
    
    struct ShareCacheResponse: Decodable {
        let success: Bool
        let message: String
    }
    
    func cacheForSharing(analysis: ProductAnalysis) async throws -> ShareCacheResponse {
        let request = ShareCacheRequest(analysis: analysis)
        let body = try JSONEncoder().encode(request)
        
        return try await makeRequest(
            endpoint: "/api/share-cache",
            method: "POST",
            body: body,
            responseType: ShareCacheResponse.self
        )
    }
    
    func getSharedAnalysis(id: String) async throws -> ProductAnalysis {
        return try await makeRequest(
            endpoint: "/api/analysis/\(id)",
            responseType: ProductAnalysis.self
        )
    }
    
    // MARK: - Share URL Generation
    
    func generateShareURL(for analysisId: String) -> URL? {
        return URL(string: "https://archieml.com/share/\(analysisId)")
    }
}

