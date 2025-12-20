//
//  ArchieTests.swift
//  Archie
//
//  End-to-end integration tests for the scan flow.
//

import XCTest
@testable import Archie
import SwiftUI
import UIKit

@MainActor
final class ArchieEndToEndTests: XCTestCase {

    func test_fullScanFlow_addsResultToHistory() async throws {
        let historyService = makeHistoryService()
        let apiService = MockAPIService()
        apiService.stubAnalysis = makeProductAnalysis()
        
        let imageStore = InMemoryImageStore()
        let coordinator = ScanAnalysisCoordinator(
            apiService: apiService,
            storageService: MockStorageService(),
            historyService: historyService,
            imageStore: imageStore,
            userSession: nil
        )
        let viewModel = ScanViewModel(coordinator: coordinator)

        let (image, data) = makeImage()
        viewModel.beginScan(with: data, uiImage: image, includeDog: true, includeCat: false, includeChildren: true)

        try await waitForHistoryCount(on: historyService, expected: 1)

        XCTAssertEqual(historyService.records.count, 1)
        XCTAssertEqual(historyService.records.first?.analysis.productName, apiService.stubAnalysis?.name)
        if case .result = viewModel.phase {
            XCTAssertNotNil(viewModel.resultVM)
        } else {
            XCTFail("Expected scan to finish with a result phase")
        }
    }

    func test_scanAppearsInAccountStats() async throws {
        let historyService = makeHistoryService()
        let apiService = MockAPIService()
        apiService.stubAnalysis = makeProductAnalysis()
        
        let imageStore = InMemoryImageStore()
        let coordinator = ScanAnalysisCoordinator(
            apiService: apiService,
            storageService: MockStorageService(),
            historyService: historyService,
            imageStore: imageStore,
            userSession: nil
        )
        let viewModel = ScanViewModel(coordinator: coordinator)
        let accountVM = AccountViewModel(userSession: MockUserSession(), historyService: historyService)

        let (image, data) = makeImage()
        viewModel.beginScan(with: data, uiImage: image, includeDog: false, includeCat: true, includeChildren: true)

        try await waitForHistoryCount(on: historyService, expected: 1)
        try await waitUntil(
            timeout: 1.0,
            condition: { accountVM.stats.contains(where: { $0.label == "Scans" && $0.value == "1" }) }
        )

        XCTAssertTrue(accountVM.stats.contains(where: { $0.label == "Scans" && $0.value == "1" }))
    }
    
    func test_scanWithAPIError_setsErrorPhase() async throws {
        let historyService = makeHistoryService()
        let apiService = MockAPIService()
        apiService.shouldFail = true
        apiService.failureError = ArchieAPIError.networkError(underlying: URLError(.notConnectedToInternet))
        
        let imageStore = InMemoryImageStore()
        let coordinator = ScanAnalysisCoordinator(
            apiService: apiService,
            storageService: MockStorageService(),
            historyService: historyService,
            imageStore: imageStore,
            userSession: nil
        )
        let viewModel = ScanViewModel(coordinator: coordinator)

        let (image, data) = makeImage()
        viewModel.beginScan(with: data, uiImage: image, includeDog: true, includeCat: false, includeChildren: true)

        try await waitUntil(timeout: 1.0) {
            if case .error = viewModel.phase { return true }
            return false
        }

        if case .error = viewModel.phase {
            XCTAssertNotNil(viewModel.scanError)
        } else {
            XCTFail("Expected error phase after API failure")
        }
    }

    // MARK: - Helpers

    private func makeHistoryService() -> ScanHistoryService {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return ScanHistoryService(fileURL: fileURL)
    }

    private func makeProductAnalysis() -> ProductAnalysis {
        ProductAnalysis(
            id: "fruit-snack-123456",
            name: "Fruit Snack",
            image: "",
            imageUrl: nil,
            safetyScore: SafetyScore(overall: 7),
            category: "Snack",
            recognitionStatus: .success,
            analysis: SafetyAnalysis(
                kidSafety: KidSafety(
                    status: .safe,
                    score: 65,
                    benefits: ["High fibre"],
                    concerns: ["High sugar"],
                    narrative: "Mock child narrative"
                ),
                petSafety: PetSafetyAnalysis(
                    dogs: PetSafetyItem(
                        status: .warning,
                        score: 40,
                        warnings: ["Contains xylitol"],
                        pros: ["Offer sparingly", "Provide water", "Monitor for symptoms"],
                        cons: ["Contains xylitol", "High sugar", "May cause hypoglycemia"],
                        narrative: "Mock dog narrative",
                        details: [
                            PetSafetyDetail(severity: .medium, warning: "Limit treats", reason: "Contains xylitol")
                        ]
                    ),
                    cats: PetSafetyItem(
                        status: .safe,
                        score: 80,
                        warnings: [],
                        pros: ["No direct cat benefit", "Only under vet guidance", "Provide alternatives"],
                        cons: ["Artificial sweeteners", "High sugar", "Potential vomiting"],
                        narrative: "Mock cat narrative",
                        details: []
                    )
                ),
                hygiene: HygieneAnalysis(recommendations: [], warnings: []),
                generalSafety: GeneralSafetyAnalysis(pros: [], cons: []),
                recalls: []
            ),
            petSafetyOptions: PetSafetyOptions(
                includeDogs: true,
                includeCats: true,
                includeChildren: true
            ),
            analysisMetadata: AnalysisMetadata(
                modelConfidence: 0.9,
                recognitionConfidence: 0.88
            )
        )
    }

    private func makeImage(size: CGSize = CGSize(width: 40, height: 40)) -> (UIImage, Data) {
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            fatalError("Failed to encode test image")
        }
        return (image, data)
    }

    private func waitForHistoryCount(on service: ScanHistoryService, expected: Int, timeout: TimeInterval = 1.0) async throws {
        try await waitUntil(timeout: timeout) {
            service.records.count == expected
        }
    }

    private func waitUntil(timeout: TimeInterval = 1.0, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

// MARK: - Test Doubles

private final class MockAPIService: ProductAnalyzing {
    var analyzeCallCount = 0
    var stubAnalysis: ProductAnalysis?
    var shouldFail = false
    var failureError: Error = ArchieAPIError.networkError(underlying: URLError(.unknown))
    
    func analyze(
        image: UIImage,
        includeDogs: Bool,
        includeCats: Bool,
        includeChildren: Bool
    ) async throws -> ProductAnalysis {
        analyzeCallCount += 1
        
        if shouldFail {
            throw failureError
        }
        
        guard let analysis = stubAnalysis else {
            throw ArchieAPIError.noData
        }
        return analysis
    }
    
    func saveToHistory(item: Archie.APIHistoryItem) async throws -> Archie.HistorySaveResponse {
        let saveResponse = HistorySaveResponse(success: true, message: "Great success!")
        return saveResponse
    }
}

private final class InMemoryImageStore: ScanImageStoring {
    private(set) var persistCalls: Int = 0

    func persist(image: UIImage, data: Data?) async throws -> PersistedScanImage {
        persistCalls += 1
        let base = FileManager.default.temporaryDirectory
        let imageURL = base.appendingPathComponent("IMG_\(UUID().uuidString).jpg")
        let thumbURL = base.appendingPathComponent("IMG_\(UUID().uuidString)_thumb.jpg")
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        return PersistedScanImage(imageURL: imageURL, thumbnailURL: thumbURL, pixelSize: pixelSize, format: .jpg)
    }
}

private final class MockStorageService: ImageStorageService {
    func uploadAnalysisImage(image: UIImage, analysisId: String) async throws -> String {
        "https://storage.example.com/\(analysisId).jpg"
    }
    
    func deleteAnalysisImage(analysisId: String) async throws {}
}
