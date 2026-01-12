//
//  ShareServiceTests.swift
//  Archie
//

import XCTest
@testable import Archie

@MainActor
final class ShareServiceTests: XCTestCase {
    
    private var sut: ShareService!
    
    override func setUp() async throws {
        sut = ShareService()
    }
    
    override func tearDown() async throws {
        sut = nil
    }
    
    // MARK: - Test Fixtures
    
    private func makeProductAnalysis(
        id: String = "apple-1234567890",
        name: String = "Green Apple",
        score: Int = 85
    ) -> ProductAnalysis {
        ProductAnalysis(
            id: id,
            name: name,
            image: "",
            imageUrl: nil,
            safetyScore: SafetyScore(overall: score),
            category: "Food",
            recognitionStatus: .success,
            analysis: SafetyAnalysis(
                kidSafety: KidSafety(status: .safe),
                petSafety: PetSafetyAnalysis(),
                hygiene: HygieneAnalysis()
            )
        )
    }
    
    // MARK: - generateShareContent Tests
    
    func test_generateShareContent_producesCorrectURL() throws {
        let analysis = makeProductAnalysis(id: "test-product-123")
        
        let result = try sut.generateShareContent(for: analysis)
        
        XCTAssertEqual(result.shareURL.absoluteString, "https://archieml.com/share/test-product-123")
    }
    
    func test_generateShareContent_producesCorrectText() throws {
        let analysis = makeProductAnalysis(name: "Organic Banana", score: 72)
        
        let result = try sut.generateShareContent(for: analysis)
        
        XCTAssertEqual(result.shareText, "Archie result for Organic Banana: 7/10")
    }
    
    func test_generateShareContent_includesAnalysisId() throws {
        let analysis = makeProductAnalysis(id: "my-unique-id-456")
        
        let result = try sut.generateShareContent(for: analysis)
        
        XCTAssertEqual(result.analysisId, "my-unique-id-456")
    }
    
    func test_generateShareContent_throwsForEmptyId() {
        let analysis = makeProductAnalysis(id: "")
        
        XCTAssertThrowsError(try sut.generateShareContent(for: analysis)) { error in
            guard let shareError = error as? ShareServiceError else {
                XCTFail("Expected ShareServiceError")
                return
            }
            XCTAssertEqual(shareError, ShareServiceError.noAnalysisId)
        }
    }
    
    // MARK: - generateShareURL Tests
    
    func test_generateShareURL_producesCorrectURL() {
        let url = sut.generateShareURL(for: "grape-juice-789")
        
        XCTAssertEqual(url?.absoluteString, "https://archieml.com/share/grape-juice-789")
    }
    
    func test_generateShareURL_returnsNilForEmptyId() {
        let url = sut.generateShareURL(for: "")
        
        XCTAssertNil(url)
    }
    
    func test_generateShareURL_handlesSpecialCharacters() {
        // URL encoding is handled by URL(string:)
        let url = sut.generateShareURL(for: "product-with-spaces")
        
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("product-with-spaces"))
    }
    
    // MARK: - formatShareText Tests
    
    func test_formatShareText_producesCorrectFormat() {
        let text = sut.formatShareText(name: "Test Product", score: 8)
        
        XCTAssertEqual(text, "Archie result for Test Product: 8/10")
    }
    
    func test_formatShareText_handlesZeroScore() {
        let text = sut.formatShareText(name: "Dangerous Item", score: 0)
        
        XCTAssertEqual(text, "Archie result for Dangerous Item: 0/10")
    }
    
    func test_formatShareText_handlesPerfectScore() {
        let text = sut.formatShareText(name: "Safe Item", score: 10)
        
        XCTAssertEqual(text, "Archie result for Safe Item: 10/10")
    }
    
    func test_formatShareText_handlesLongProductName() {
        let longName = "Super Deluxe Premium Organic Non-GMO Gluten-Free Product"
        let text = sut.formatShareText(name: longName, score: 7)
        
        XCTAssertTrue(text.contains(longName))
        XCTAssertTrue(text.hasPrefix("Archie result for "))
        XCTAssertTrue(text.hasSuffix(": 7/10"))
    }
    
    // MARK: - Published Properties Tests
    
    func test_initialState_isSharingIsFalse() {
        XCTAssertFalse(sut.isSharing)
    }
    
    func test_initialState_shareErrorIsNil() {
        XCTAssertNil(sut.shareError)
    }
}

// MARK: - ShareServiceError Equatable

extension ShareServiceError: Equatable {
    public static func == (lhs: ShareServiceError, rhs: ShareServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.noAnalysisId, .noAnalysisId): return true
        case (.invalidURL, .invalidURL): return true
        default: return false
        }
    }
}
