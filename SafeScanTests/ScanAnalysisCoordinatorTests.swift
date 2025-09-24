//
//  ScanAnalysisCoordinatorTests.swift
//  SafeSnap
//
//  Ensures the coordinator orchestrates injected dependencies so the scan flow stays testable.
//

import XCTest
@testable import SafeSnap
import UIKit

@MainActor
final class ScanAnalysisCoordinatorTests: XCTestCase {

    func test_startGeminiScan_persistsImage_andAddsHistoryItem() async throws {
        let analysis = makeAnalyzedSafety()
        let analyzer = MockAnalyzer(result: analysis)
        let history = MockHistoryService()
        let imageStore = MockImageStore(result: makePersistedImage())
        let coordinator = ScanAnalysisCoordinator(analyzer: analyzer, historyService: history, imageStore: imageStore)

        let image = makeImage()
        let options = SafetyOptions(includeDogs: true, includeCats: false, includeChildren: true)

        try await coordinator.startGeminiScan(image: image, options: options)

        XCTAssertEqual(analyzer.analyzeCallCount, 1)
        XCTAssertEqual(analyzer.capturedOptions?.includeDogs, true)
        XCTAssertEqual(imageStore.persistCalls.count, 1)
        XCTAssertEqual(history.addedItems.count, 1)
        XCTAssertEqual(coordinator.latestHistoryItem, history.addedItems.first)
        XCTAssertEqual(coordinator.currentPhase, .report)
        XCTAssertTrue(coordinator.isComplete)
        XCTAssertEqual(coordinator.explainability?.policy.canonicalCategory, analysis.extras.policy.canonicalCategory)
    }

    func test_cancelAnalysis_resetsPhase_andCancelsAnalyzer() {
        let analyzer = MockAnalyzer(result: makeAnalyzedSafety())
        let history = MockHistoryService()
        let imageStore = MockImageStore(result: makePersistedImage())
        let coordinator = ScanAnalysisCoordinator(analyzer: analyzer, historyService: history, imageStore: imageStore)

        coordinator.currentPhase = .openAI
        coordinator.cancelAnalysis()

        XCTAssertEqual(analyzer.cancelCallCount, 1)
        XCTAssertEqual(coordinator.currentPhase, .preparing)
    }

    // MARK: - Helpers

    private func makeImage(size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeAnalyzedSafety(name: String = "Fruit Snack") -> AnalyzedSafety {
        let pros = [SafetyAnalysisResponse.LabeledItem(label: "High fibre", severity: .low, category: "nutrition")]
        let cons = [SafetyAnalysisResponse.LabeledItem(label: "High sugar", severity: .medium, category: "nutrition")]
        let general = SafetyAnalysisResponse.GeneralSafety(pros: pros, cons: cons)
        let pet = SafetyAnalysisResponse.PetSafety(dogs: [], cats: [])
        let response = SafetyAnalysisResponse(
            productName: name,
            productType: "Snack",
            overallSafetyScore: 70,
            childSafetyScore: 65,
            dogSafetyScore: 50,
            catSafetyScore: 40,
            modelConfidence: 0.9,
            recognitionConfidence: 0.88,
            generalSafety: general,
            petSafety: pet,
            hygieneWarnings: [],
            recalls: []
        )
        let extras = AnalysisExtras(
            evidence: SafetyEvidence(labels: ["snack"], ocrHits: ["Fruit Snack"]),
            policy: PolicyOutcome(canonicalCategory: "snack", rulesTriggered: ["overall_capped_by_child"])
        )
        return AnalyzedSafety(response: response, extras: extras)
    }

    private func makePersistedImage() -> PersistedScanImage {
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("IMG_\(UUID().uuidString).jpg")
        let thumbURL = tempDir.appendingPathComponent("IMG_\(UUID().uuidString)_thumb.jpg")
        return PersistedScanImage(imageURL: imageURL, thumbnailURL: thumbURL, pixelSize: CGSize(width: 400, height: 400), format: .jpg)
    }
}

// MARK: - Test Doubles

private final class MockAnalyzer: SafetyAnalyzing {
    var analyzeCallCount = 0
    var cancelCallCount = 0
    var capturedOptions: SafetyOptions?
    var capturedImages: [UIImage] = []
    var result: AnalyzedSafety

    init(result: AnalyzedSafety) {
        self.result = result
    }

    func analyzeSafetyWithExtras(
        image: UIImage,
        options: SafetyOptions,
        streamToken: @escaping (String) -> Void,
        visionLabels: [String],
        ocrHits: [String]
    ) async throws -> AnalyzedSafety {
        analyzeCallCount += 1
        capturedImages.append(image)
        capturedOptions = options
        streamToken("testing")
        return result
    }

    func cancelAnalysis() {
        cancelCallCount += 1
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
