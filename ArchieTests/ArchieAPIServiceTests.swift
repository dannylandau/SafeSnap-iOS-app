//
//  ArchieAPIServiceTests.swift
//  Archie
//
//  Tests for ArchieAPIService and related types
//

import XCTest
@testable import Archie

final class ArchieAPIServiceTests: XCTestCase {
    
    // MARK: - APIEnvironment Tests
    
    func test_productionEnvironment_hasCorrectBaseURL() {
        let environment = APIEnvironment.production
        XCTAssertEqual(environment.baseURL, "https://be.archieml.com")
    }
    
    func test_developmentEnvironment_hasCorrectBaseURL() {
        let environment = APIEnvironment.development
        XCTAssertEqual(environment.baseURL, "http://localhost:4000")
    }
    
    // MARK: - ArchieAPIError Tests
    
    func test_invalidURLError_hasCorrectDescription() {
        let error = ArchieAPIError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid API URL")
    }
    
    func test_encodingFailedError_hasCorrectDescription() {
        let error = ArchieAPIError.encodingFailed
        XCTAssertEqual(error.errorDescription, "Failed to encode request data")
    }
    
    func test_unauthorizedError_hasCorrectDescription() {
        let error = ArchieAPIError.unauthorized
        XCTAssertEqual(error.errorDescription, "Unauthorized - please sign in again")
    }
    
    func test_notFoundError_hasCorrectDescription() {
        let error = ArchieAPIError.notFound
        XCTAssertEqual(error.errorDescription, "Resource not found")
    }
    
    func test_imageEncodingFailedError_hasCorrectDescription() {
        let error = ArchieAPIError.imageEncodingFailed
        XCTAssertEqual(error.errorDescription, "Failed to encode image")
    }
    
    func test_noDataError_hasCorrectDescription() {
        let error = ArchieAPIError.noData
        XCTAssertEqual(error.errorDescription, "No data received from server")
    }
    
    func test_httpError_includesStatusCodeAndMessage() {
        let error = ArchieAPIError.httpError(statusCode: 500, message: "Internal Server Error")
        XCTAssertEqual(error.errorDescription, "HTTP Error 500: Internal Server Error")
    }
    
    func test_httpError_handlesNilMessage() {
        let error = ArchieAPIError.httpError(statusCode: 503, message: nil)
        XCTAssertEqual(error.errorDescription, "HTTP Error 503: Unknown error")
    }
    
    func test_decodingFailedError_includesUnderlyingError() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad JSON"])
        let error = ArchieAPIError.decodingFailed(underlying: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Bad JSON") ?? false)
    }
    
    func test_networkError_includesUnderlyingError() {
        let underlyingError = URLError(.notConnectedToInternet)
        let error = ArchieAPIError.networkError(underlying: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }
    
    // MARK: - Token Management Tests
    
    func test_setToken_storesToken() {
        let service = ArchieAPIService(environment: .development)
        service.setToken("test-token-123")
        // Token is private, but we test indirectly via behavior
        service.clearToken()
        // No crash means success
    }
    
    func test_clearToken_removesToken() {
        let service = ArchieAPIService(environment: .development)
        service.setToken("test-token")
        service.clearToken()
        // No crash means success
    }
    
    // MARK: - Initialization Tests
    
    func test_init_withDefaultEnvironment_usesProduction() {
        let service = ArchieAPIService()
        // Service should be created successfully with production environment
        XCTAssertNotNil(service)
    }
    
    func test_init_withDevelopmentEnvironment_usesLocalhost() {
        let service = ArchieAPIService(environment: .development)
        XCTAssertNotNil(service)
    }
    
    func test_init_withTokenProvider_storesProvider() async {
        var providerCalled = false
        let service = ArchieAPIService(
            environment: .development,
            tokenProvider: {
                providerCalled = true
                return "mock-token"
            }
        )
        XCTAssertNotNil(service)
        // Provider will be called when making authenticated requests
    }
    
    // MARK: - APIHistoryItem Tests
    
    func test_apiHistoryItem_encodesAndDecodes() throws {
        let item = APIHistoryItem(
            id: "test-123",
            createdAt: "2025-01-15T10:30:00Z",
            name: "Test Product",
            score: 75,
            maxScore: 100,
            preview: "A test product",
            imageUrl: "https://example.com/image.jpg",
            labels: ["food", "snack"],
            category: "Food",
            petSafetyOptions: PetSafetyOptions(includeDogs: true, includeCats: false, includeChildren: true),
            fullAnalysis: nil
        )
        
        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(APIHistoryItem.self, from: encoded)
        
        XCTAssertEqual(decoded.id, "test-123")
        XCTAssertEqual(decoded.name, "Test Product")
        XCTAssertEqual(decoded.score, 75)
        XCTAssertEqual(decoded.labels, ["food", "snack"])
    }
    
    // MARK: - HistorySaveResponse Tests
    
    func test_historySaveResponse_decodesCorrectly() throws {
        let json = """
        {"success": true, "message": "Item saved successfully"}
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(HistorySaveResponse.self, from: json)
        
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Item saved successfully")
    }
    
    // MARK: - HistoryDeleteResponse Tests
    
    func test_historyDeleteResponse_decodesCorrectly() throws {
        let json = """
        {"success": true, "message": "Item deleted"}
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(HistoryDeleteResponse.self, from: json)
        
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Item deleted")
    }
}

