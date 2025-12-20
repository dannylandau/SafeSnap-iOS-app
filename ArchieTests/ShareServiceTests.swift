//
//  ShareServiceTests.swift
//  Archie
//
//  Tests for ShareService
//

import XCTest
@testable import Archie

@MainActor
final class ShareServiceTests: XCTestCase {
    
    private var sut: ShareService!
    
    override func setUp() {
        super.setUp()
        sut = ShareService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - generateShareContent Tests
    
    func test_generateShareContent_withValidAnalysis_returnsCorrectURL() throws {
        let analysis = makeProductAnalysis(id: "apple-123456", name: "Apple", score: 85)
        
        let result = try sut.generateShareContent(for: analysis)
        
        XCTAssertEqual(result.shareURL.absoluteString, "https://archieml.com/share/apple-123456")
        XCTAssertEqual(result.analysisId, "apple-123456")
    }
    
    func test_generateShareContent_withValidAnalysis_returnsCorrectText() throws {
        let analysis = makeProductAnalysis(id: "grapes-789", name: "Green Grapes", score: 43)
        
        let result = try sut.generateShareContent(for: analysis)
        
        XCTAssertEqual(result.shareText, "Archie result for Green Grapes: 43/10")
    }
    
    func test_generateShareContent_withEmptyId_throwsNoAnalysisIdError() {
        let analysis = makeProductAnalysis(id: "", name: "Apple", score: 85)
        
        XCTAssertThrowsError(try sut.generateShareContent(for: analysis)) { error in
            XCTAssertEqual(error as? ShareServiceError, ShareServiceError.noAnalysisId)
        }
    }
    
    func test_generateShareContent_withSpecialCharactersInId_generatesURL() throws {
        let analysis = makeProductAnalysis(id: "product-with-dashes-123", name: "Test Product", score: 50)
        
        let result = try sut.generateShareContent(for: analysis)
        
        XCTAssertEqual(result.shareURL.absoluteString, "https://archieml.com/share/product-with-dashes-123")
    }
    
    // MARK: - generateShareURL Tests
    
    func test_generateShareURL_withValidId_returnsCorrectURL() {
        let url = sut.generateShareURL(for: "test-analysis-id")
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://archieml.com/share/test-analysis-id")
    }
    
    func test_generateShareURL_withEmptyId_returnsNil() {
        let url = sut.generateShareURL(for: "")
        
        XCTAssertNil(url)
    }
    
    // MARK: - formatShareText Tests
    
    func test_formatShareText_formatsCorrectly() {
        let text = sut.formatShareText(name: "Chocolate Bar", score: 7)
        
        XCTAssertEqual(text, "Archie result for Chocolate Bar: 7/10")
    }
    
    func test_formatShareText_withZeroScore_formatsCorrectly() {
        let text = sut.formatShareText(name: "Dangerous Item", score: 0)
        
        XCTAssertEqual(text, "Archie result for Dangerous Item: 0/10")
    }
    
    func test_formatShareText_withMaxScore_formatsCorrectly() {
        let text = sut.formatShareText(name: "Safe Item", score: 10)
        
        XCTAssertEqual(text, "Archie result for Safe Item: 10/10")
    }
    
    // MARK: - Helpers
    
    private func makeProductAnalysis(id: String, name: String, score: Int) -> ProductAnalysis {
        ProductAnalysis(
            id: id,
            name: name,
            image: "",
            imageUrl: nil,
            safetyScore: SafetyScore(overall: score),
            category: "Food",
            recognitionStatus: .success,
            analysis: SafetyAnalysis(
                kidSafety: KidSafety(status: .safe, score: score, benefits: [], concerns: [], narrative: nil),
                petSafety: PetSafetyAnalysis(dogs: nil, cats: nil),
                hygiene: HygieneAnalysis(recommendations: [], warnings: []),
                generalSafety: nil,
                recalls: []
            ),
            petSafetyOptions: nil,
            analysisMetadata: nil
        )
    }
}

