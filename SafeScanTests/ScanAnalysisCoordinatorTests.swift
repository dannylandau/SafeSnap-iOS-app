//
//  ScanAnalysisCoordinatorTests.swift
//  Archie
//
//  Tests the coordinator's orchestration of API-based analysis flow.
//

import XCTest
@testable import SafeSnap
import UIKit

@MainActor
final class ScanAnalysisCoordinatorTests: XCTestCase {

    // MARK: - Tests
    
    func test_startGeminiScan_persistsImage_andAddsHistoryItem() async throws {
        let apiService = MockAPIService()
        apiService.stubAnalysis = makeProductAnalysis()
        
        let history = MockHistoryService()
        let imageStore = MockImageStore(result: makePersistedImage())
        
        let coordinator = ScanAnalysisCoordinator(
            apiService: apiService,
            storageService: MockStorageService(),
            historyService: history,
            imageStore: imageStore,
            userSession: nil
        )

        let image = makeImage()
        let options = SafetyOptions(includeDogs: true, includeCats: false, includeChildren: true)

        try await coordinator.startGeminiScan(image: image, options: options)

        XCTAssertEqual(apiService.analyzeCallCount, 1)
        XCTAssertEqual(apiService.capturedOptions?.includeDogs, true)
        XCTAssertEqual(apiService.capturedOptions?.includeCats, false)
        XCTAssertEqual(imageStore.persistCalls.count, 1)
        XCTAssertEqual(history.addedItems.count, 1)
        XCTAssertEqual(coordinator.latestHistoryItem, history.addedItems.first)
        XCTAssertNotNil(coordinator.latestProductAnalysis)
        XCTAssertEqual(coordinator.latestProductAnalysis?.id, apiService.stubAnalysis?.id)
    }

    func test_cancelAnalysis_resetsPhase() {
        let coordinator = ScanAnalysisCoordinator(
            apiService: MockAPIService(),
            storageService: MockStorageService(),
            historyService: MockHistoryService(),
            imageStore: MockImageStore(result: makePersistedImage()),
            userSession: nil
        )

        coordinator.currentPhase = .analyzing
        coordinator.cancelAnalysis()

        XCTAssertEqual(coordinator.currentPhase, .preparing)
    }

    func test_startGeminiScan_propagatesAPIFailure() async {
        let apiService = MockAPIService()
        apiService.shouldFail = true
        apiService.failureError = ArchieAPIError.networkError(underlying: URLError(.notConnectedToInternet))
        
        let coordinator = ScanAnalysisCoordinator(
            apiService: apiService,
            storageService: MockStorageService(),
            historyService: MockHistoryService(),
            imageStore: MockImageStore(result: makePersistedImage()),
            userSession: nil
        )

        let image = makeImage()

        do {
            try await coordinator.startGeminiScan(
                image: image,
                options: SafetyOptions(includeDogs: false, includeCats: false, includeChildren: true)
            )
            XCTFail("Expected API failure to throw")
        } catch {
            // Expected - API failure should propagate
            XCTAssertTrue(error is ScanError)
        }
    }
    
    func test_startGeminiScan_updatesPhasesDuringFlow() async throws {
        let apiService = MockAPIService()
        apiService.stubAnalysis = makeProductAnalysis()
        
        let coordinator = ScanAnalysisCoordinator(
            apiService: apiService,
            storageService: MockStorageService(),
            historyService: MockHistoryService(),
            imageStore: MockImageStore(result: makePersistedImage()),
            userSession: nil
        )
        
        XCTAssertEqual(coordinator.currentPhase, .preparing)
        
        let image = makeImage()
        try await coordinator.startGeminiScan(
            image: image,
            options: SafetyOptions(includeDogs: true, includeCats: true, includeChildren: true)
        )
        
        // After completion, should be at report phase
        XCTAssertTrue(coordinator.isComplete)
    }
    
    func test_startGeminiScan_populatesExplainability() async throws {
        let apiService = MockAPIService()
        let analysis = makeProductAnalysis()
        apiService.stubAnalysis = analysis
        
        let coordinator = ScanAnalysisCoordinator(
            apiService: apiService,
            storageService: MockStorageService(),
            historyService: MockHistoryService(),
            imageStore: MockImageStore(result: makePersistedImage()),
            userSession: nil
        )
        
        let image = makeImage()
        try await coordinator.startGeminiScan(
            image: image,
            options: SafetyOptions(includeDogs: true, includeCats: false, includeChildren: true)
        )
        
        XCTAssertNotNil(coordinator.explainability)
        XCTAssertEqual(coordinator.visionBestGuess, analysis.name)
    }

    // MARK: - Helpers

    private func makeImage(size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
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
                        score: 50,
                        warnings: ["Contains xylitol"],
                        pros: ["Offer sparingly"],
                        cons: ["High sugar"],
                        narrative: "Mock dog narrative",
                        details: []
                    ),
                    cats: nil
                ),
                hygiene: HygieneAnalysis(recommendations: [], warnings: []),
                generalSafety: GeneralSafetyAnalysis(pros: [], cons: []),
                recalls: []
            ),
            petSafetyOptions: PetSafetyOptions(
                includeDogs: true,
                includeCats: false,
                includeChildren: true
            ),
            analysisMetadata: AnalysisMetadata(
                modelConfidence: 0.9,
                recognitionConfidence: 0.88
            )
        )
    }

    private func makePersistedImage() -> PersistedScanImage {
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("IMG_\(UUID().uuidString).jpg")
        let thumbURL = tempDir.appendingPathComponent("IMG_\(UUID().uuidString)_thumb.jpg")
        return PersistedScanImage(imageURL: imageURL, thumbnailURL: thumbURL, pixelSize: CGSize(width: 400, height: 400), format: .jpg)
    }
}

// MARK: - Test Doubles

private final class MockAPIService: ProductAnalyzing {
    var analyzeCallCount = 0
    var capturedOptions: (includeDogs: Bool, includeCats: Bool, includeChildren: Bool)?
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
        capturedOptions = (includeDogs, includeCats, includeChildren)
        
        if shouldFail {
            throw failureError
        }
        
        guard let analysis = stubAnalysis else {
            throw ArchieAPIError.noData
        }
        return analysis
    }
}

@MainActor
private final class MockHistoryService: ScanHistoryRecording {
    private(set) var addedItems: [ScanHistoryItem] = []

    func add(_ item: ScanHistoryItem) {
        addedItems.append(item)
    }
}

private final class MockImageStore: ScanImageStoring {
    private(set) var persistCalls: [(image: UIImage, data: Data?)] = []
    let result: PersistedScanImage

    init(result: PersistedScanImage) {
        self.result = result
    }

    func persist(image: UIImage, data: Data?) async throws -> PersistedScanImage {
        persistCalls.append((image, data))
        return result
    }
}

private final class MockStorageService: ImageStorageService {
    var uploadedImages: [String: UIImage] = [:]
    
    func uploadAnalysisImage(image: UIImage, analysisId: String) async throws -> String {
        uploadedImages[analysisId] = image
        return "https://storage.example.com/\(analysisId).jpg"
    }
    
    func deleteAnalysisImage(analysisId: String) async throws {
        uploadedImages.removeValue(forKey: analysisId)
    }
}
