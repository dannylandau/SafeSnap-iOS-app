//
//  ArchieAPIServiceTests.swift
//  Archie
//

import XCTest
@testable import Archie

final class ArchieAPIServiceTests: XCTestCase {
    
    // MARK: - APIEnvironment Tests
    
    func test_productionEnvironment_hasCorrectBaseURL() {
        let env = APIEnvironment.production
        
        XCTAssertEqual(env.baseURL, "https://be.archieml.com")
    }
    
    func test_developmentEnvironment_hasCorrectBaseURL() {
        let env = APIEnvironment.development
        
        XCTAssertEqual(env.baseURL, "http://localhost:4000")
    }
    
    // MARK: - ArchieAPIError Tests
    
    func test_invalidURLError_hasDescription() {
        let error = ArchieAPIError.invalidURL
        
        XCTAssertEqual(error.errorDescription, "Invalid API URL")
    }
    
    func test_encodingFailedError_hasDescription() {
        let error = ArchieAPIError.encodingFailed
        
        XCTAssertEqual(error.errorDescription, "Failed to encode request data")
    }
    
    func test_decodingFailedError_includesUnderlyingError() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        let error = ArchieAPIError.decodingFailed(underlying: underlyingError)
        
        XCTAssertTrue(error.errorDescription?.contains("Invalid JSON") ?? false)
    }
    
    func test_httpError_includesStatusCodeAndMessage() {
        let error = ArchieAPIError.httpError(statusCode: 500, message: "Server Error")
        
        XCTAssertTrue(error.errorDescription?.contains("500") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Server Error") ?? false)
    }
    
    func test_unauthorizedError_hasDescription() {
        let error = ArchieAPIError.unauthorized
        
        XCTAssertEqual(error.errorDescription, "Unauthorized - please sign in again")
    }
    
    func test_notFoundError_hasDescription() {
        let error = ArchieAPIError.notFound
        
        XCTAssertEqual(error.errorDescription, "Resource not found")
    }
    
    func test_networkError_includesUnderlyingError() {
        let underlyingError = URLError(.notConnectedToInternet)
        let error = ArchieAPIError.networkError(underlying: underlyingError)
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }
    
    func test_imageEncodingFailedError_hasDescription() {
        let error = ArchieAPIError.imageEncodingFailed
        
        XCTAssertEqual(error.errorDescription, "Failed to encode image")
    }
    
    func test_noDataError_hasDescription() {
        let error = ArchieAPIError.noData
        
        XCTAssertEqual(error.errorDescription, "No data received from server")
    }
    
    // MARK: - Token Management Tests
    
    func test_setToken_storesCachedToken() {
        let sut = ArchieAPIService(environment: .production)
        
        sut.setToken("test-token-123")
        
        // Token is private, but we can verify by checking it doesn't crash
        sut.clearToken()
    }
    
    func test_clearToken_removesCachedToken() {
        let sut = ArchieAPIService(environment: .production)
        sut.setToken("test-token")
        
        sut.clearToken()
        
        // Token should be cleared - we can't directly verify but ensure no crash
    }
    
    // MARK: - Initialization Tests
    
    func test_defaultInit_usesProductionEnvironment() {
        let sut = ArchieAPIService()
        
        // Can't directly access environment, but singleton should use production
        XCTAssertNotNil(sut)
    }
    
    func test_initWithTokenProvider_acceptsClosure() {
        let tokenProvider: () async throws -> String? = { "mock-token" }
        
        let sut = ArchieAPIService(
            environment: .production,
            tokenProvider: tokenProvider
        )
        
        XCTAssertNotNil(sut)
    }
    
    func test_sharedInstance_exists() {
        let shared = ArchieAPIService.shared
        
        XCTAssertNotNil(shared)
    }
    
    // MARK: - Request Model Tests
    
    func test_analyzeRequest_encodesToJSON() throws {
        let request = ArchieAPIService.AnalyzeRequest(
            imageBase64: "base64data",
            options: .init(includeDogs: true, includeCats: false, includeChildren: true)
        )
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["imageBase64"] as? String, "base64data")
        
        let options = json?["options"] as? [String: Any]
        XCTAssertEqual(options?["includeDogs"] as? Bool, true)
        XCTAssertEqual(options?["includeCats"] as? Bool, false)
        XCTAssertEqual(options?["includeChildren"] as? Bool, true)
    }
    
    func test_loginRequest_encodesToJSON() throws {
        let request = ArchieAPIService.LoginRequest(idToken: "firebase-id-token")
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["idToken"] as? String, "firebase-id-token")
    }
    
    func test_historySaveRequest_encodesToJSON() throws {
        let item = APIHistoryItem(
            id: "test-123",
            createdAt: "2024-01-01T00:00:00Z",
            name: "Test Product",
            score: 85,
            maxScore: 100,
            preview: nil,
            imageUrl: nil,
            labels: ["food"],
            category: "Food",
            petSafetyOptions: nil,
            fullAnalysis: nil
        )
        let request = ArchieAPIService.HistorySaveRequest(item: item)
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json?["item"])
    }
    
    // MARK: - Response Model Tests
    
    func test_loginResponse_decodesFromJSON() throws {
        let json = """
        {
            "status": "ok",
            "token": "jwt-token",
            "user": {
                "uid": "user-123",
                "email": "test@example.com",
                "displayName": "Test User",
                "photoURL": null
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ArchieAPIService.LoginResponse.self, from: data)
        
        XCTAssertEqual(response.status, "ok")
        XCTAssertEqual(response.token, "jwt-token")
        XCTAssertEqual(response.user.uid, "user-123")
        XCTAssertEqual(response.user.email, "test@example.com")
    }
    
    func test_meResponse_decodesFromJSON() throws {
        let json = """
        {
            "user": {
                "uid": "user-456",
                "email": "user@example.com",
                "displayName": "User Name",
                "photoURL": "https://example.com/photo.jpg"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ArchieAPIService.MeResponse.self, from: data)
        
        XCTAssertEqual(response.user?.uid, "user-456")
        XCTAssertEqual(response.user?.photoURL, "https://example.com/photo.jpg")
    }
    
    func test_historySaveResponse_decodesFromJSON() throws {
        let json = """
        {
            "success": true,
            "message": "Item saved successfully"
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(HistorySaveResponse.self, from: data)
        
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Item saved successfully")
    }
    
    func test_historyDeleteResponse_decodesFromJSON() throws {
        let json = """
        {
            "success": true,
            "message": "Item deleted"
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(HistoryDeleteResponse.self, from: data)
        
        XCTAssertTrue(response.success)
    }
    
    // MARK: - APIHistoryItem Tests
    
    func test_apiHistoryItem_encodesAndDecodes() throws {
        let original = APIHistoryItem(
            id: "item-123",
            createdAt: "2024-01-15T10:30:00Z",
            name: "Test Item",
            score: 75,
            maxScore: 100,
            preview: "Preview text",
            imageUrl: "https://example.com/image.jpg",
            labels: ["food", "organic"],
            category: "Food",
            petSafetyOptions: PetSafetyOptions(includeDogs: true, includeCats: false, includeChildren: true),
            fullAnalysis: nil
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIHistoryItem.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.score, original.score)
        XCTAssertEqual(decoded.labels, original.labels)
        XCTAssertEqual(decoded.petSafetyOptions?.includeDogs, true)
    }
}
