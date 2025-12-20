//
//  FirebaseStorageServiceTests.swift
//  Archie
//
//  Tests for FirebaseStorageService and MockStorageService
//

import XCTest
@testable import Archie

final class FirebaseStorageServiceTests: XCTestCase {
    
    // MARK: - StorageServiceError Tests
    
    func test_imageEncodingFailedError_hasCorrectDescription() {
        let error = StorageServiceError.imageEncodingFailed
        XCTAssertEqual(error.errorDescription, "Failed to encode image for upload")
    }
    
    func test_downloadURLFailedError_hasCorrectDescription() {
        let error = StorageServiceError.downloadURLFailed
        XCTAssertEqual(error.errorDescription, "Failed to get download URL")
    }
    
    func test_invalidPathError_hasCorrectDescription() {
        let error = StorageServiceError.invalidPath
        XCTAssertEqual(error.errorDescription, "Invalid storage path")
    }
    
    func test_uploadFailedError_includesUnderlyingError() {
        let underlyingError = NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])
        let error = StorageServiceError.uploadFailed(underlying: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Network timeout") ?? false)
    }
    
    // MARK: - MockStorageService Tests
    
    #if DEBUG
    func test_mockStorageService_uploadsImage() async throws {
        let mockService = MockStorageService()
        let image = makeTestImage()
        
        let url = try await mockService.uploadAnalysisImage(image: image, analysisId: "test-123")
        
        XCTAssertEqual(url, mockService.mockURL)
        XCTAssertNotNil(mockService.uploadedImages["test-123"])
    }
    
    func test_mockStorageService_deletesImage() async throws {
        let mockService = MockStorageService()
        let image = makeTestImage()
        
        _ = try await mockService.uploadAnalysisImage(image: image, analysisId: "test-456")
        XCTAssertNotNil(mockService.uploadedImages["test-456"])
        
        try await mockService.deleteAnalysisImage(analysisId: "test-456")
        XCTAssertNil(mockService.uploadedImages["test-456"])
    }
    
    func test_mockStorageService_throwsWhenShouldFail() async {
        let mockService = MockStorageService()
        mockService.shouldFail = true
        let image = makeTestImage()
        
        do {
            _ = try await mockService.uploadAnalysisImage(image: image, analysisId: "test-789")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    func test_mockStorageService_deleteThrowsWhenShouldFail() async {
        let mockService = MockStorageService()
        mockService.shouldFail = true
        
        do {
            try await mockService.deleteAnalysisImage(analysisId: "test-999")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is StorageServiceError)
        }
    }
    
    func test_mockStorageService_tracksMultipleUploads() async throws {
        let mockService = MockStorageService()
        
        _ = try await mockService.uploadAnalysisImage(image: makeTestImage(), analysisId: "image-1")
        _ = try await mockService.uploadAnalysisImage(image: makeTestImage(), analysisId: "image-2")
        _ = try await mockService.uploadAnalysisImage(image: makeTestImage(), analysisId: "image-3")
        
        XCTAssertEqual(mockService.uploadedImages.count, 3)
        XCTAssertNotNil(mockService.uploadedImages["image-1"])
        XCTAssertNotNil(mockService.uploadedImages["image-2"])
        XCTAssertNotNil(mockService.uploadedImages["image-3"])
    }
    
    func test_mockStorageService_customMockURL() async throws {
        let mockService = MockStorageService()
        mockService.mockURL = "https://custom-storage.example.com/my-image.jpg"
        
        let url = try await mockService.uploadAnalysisImage(image: makeTestImage(), analysisId: "custom-1")
        
        XCTAssertEqual(url, "https://custom-storage.example.com/my-image.jpg")
    }
    #endif
    
    // MARK: - ImageStorageService Protocol Tests
    
    func test_imageStorageServiceProtocol_exists() {
        // Verify protocol can be used as type constraint
        func useService(_ service: ImageStorageService) async throws {
            // Protocol requires these methods
            let image = makeTestImage()
            _ = try await service.uploadAnalysisImage(image: image, analysisId: "test")
            try await service.deleteAnalysisImage(analysisId: "test")
        }
        // Compilation success means protocol is correctly defined
    }
    
    // MARK: - Helpers
    
    private func makeTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}

