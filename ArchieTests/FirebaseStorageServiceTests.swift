//
//  FirebaseStorageServiceTests.swift
//  Archie
//

import XCTest
@testable import Archie

final class FirebaseStorageServiceTests: XCTestCase {
    
    // MARK: - StorageServiceError Tests
    
    func test_imageEncodingFailedError_hasDescription() {
        let error = StorageServiceError.imageEncodingFailed
        
        XCTAssertEqual(error.errorDescription, "Failed to encode image for upload")
    }
    
    func test_uploadFailedError_includesUnderlyingError() {
        let underlyingError = NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network unavailable"])
        let error = StorageServiceError.uploadFailed(underlying: underlyingError)
        
        XCTAssertTrue(error.errorDescription?.contains("Network unavailable") ?? false)
    }
    
    func test_downloadURLFailedError_hasDescription() {
        let error = StorageServiceError.downloadURLFailed
        
        XCTAssertEqual(error.errorDescription, "Failed to get download URL")
    }
    
    func test_invalidPathError_hasDescription() {
        let error = StorageServiceError.invalidPath
        
        XCTAssertEqual(error.errorDescription, "Invalid storage path")
    }
    
    // MARK: - MockStorageService Tests
    
    #if DEBUG
    func test_mockStorageService_uploadsImage() async throws {
        let mockService = MockStorageService()
        let image = createTestImage()
        
        let url = try await mockService.uploadAnalysisImage(image: image, analysisId: "test-123")
        
        XCTAssertEqual(url, mockService.mockURL)
        XCTAssertNotNil(mockService.uploadedImages["test-123"])
    }
    
    func test_mockStorageService_deletesImage() async throws {
        let mockService = MockStorageService()
        let image = createTestImage()
        _ = try await mockService.uploadAnalysisImage(image: image, analysisId: "test-456")
        
        try await mockService.deleteAnalysisImage(analysisId: "test-456")
        
        XCTAssertNil(mockService.uploadedImages["test-456"])
    }
    
    func test_mockStorageService_throwsWhenShouldFail() async {
        let mockService = MockStorageService()
        mockService.shouldFail = true
        let image = createTestImage()
        
        do {
            _ = try await mockService.uploadAnalysisImage(image: image, analysisId: "test-789")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    func test_mockStorageService_deleteThrowsWhenShouldFail() async {
        let mockService = MockStorageService()
        mockService.shouldFail = true
        
        do {
            try await mockService.deleteAnalysisImage(analysisId: "test-abc")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    func test_mockStorageService_customMockURL() async throws {
        let mockService = MockStorageService()
        mockService.mockURL = "https://custom.storage.url/image.jpg"
        let image = createTestImage()
        
        let url = try await mockService.uploadAnalysisImage(image: image, analysisId: "custom-test")
        
        XCTAssertEqual(url, "https://custom.storage.url/image.jpg")
    }
    
    func test_mockStorageService_tracksMultipleUploads() async throws {
        let mockService = MockStorageService()
        let image = createTestImage()
        
        _ = try await mockService.uploadAnalysisImage(image: image, analysisId: "upload-1")
        _ = try await mockService.uploadAnalysisImage(image: image, analysisId: "upload-2")
        _ = try await mockService.uploadAnalysisImage(image: image, analysisId: "upload-3")
        
        XCTAssertEqual(mockService.uploadedImages.count, 3)
        XCTAssertNotNil(mockService.uploadedImages["upload-1"])
        XCTAssertNotNil(mockService.uploadedImages["upload-2"])
        XCTAssertNotNil(mockService.uploadedImages["upload-3"])
    }
    #endif
    
    // MARK: - ImageStorageService Protocol Tests
    
    func test_imageStorageServiceProtocol_hasRequiredMethods() {
        // This test verifies the protocol definition
        let _: any ImageStorageService.Type = MockStorageService.self
        
        // If this compiles, the protocol has the required methods
        XCTAssertTrue(true)
    }
    
    // MARK: - Helpers
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}

// MARK: - Integration Tests (Disabled by default)

// These tests require actual Firebase configuration and are disabled.
// Uncomment to run integration tests locally.

/*
final class FirebaseStorageServiceIntegrationTests: XCTestCase {
    
    func test_uploadAndDeleteImage() async throws {
        let service = FirebaseStorageService.shared
        let image = createTestImage()
        let analysisId = "integration-test-\(UUID().uuidString)"
        
        // Upload
        let url = try await service.uploadAnalysisImage(image: image, analysisId: analysisId)
        XCTAssertFalse(url.isEmpty)
        XCTAssertTrue(url.contains("firebase"))
        
        // Delete
        try await service.deleteAnalysisImage(analysisId: analysisId)
        
        // Verify deleted
        let urlAfterDelete = await service.getImageURL(analysisId: analysisId)
        XCTAssertNil(urlAfterDelete)
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}
*/
