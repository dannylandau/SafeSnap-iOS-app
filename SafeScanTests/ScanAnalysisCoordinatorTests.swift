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
        let vision = MockVisionService(result: makeVisionAnalysisResult())
        let coordinator = ScanAnalysisCoordinator(analyzer: analyzer, visionService: vision, historyService: history, imageStore: imageStore)

        let image = makeImage()
        let options = SafetyOptions(includeDogs: true, includeCats: false, includeChildren: true)

        try await coordinator.startGeminiScan(image: image, options: options)

        XCTAssertEqual(analyzer.analyzeCallCount, 1)
        XCTAssertEqual(vision.analyzeCallCount, 1)
        XCTAssertEqual(analyzer.capturedOptions?.includeDogs, true)
        XCTAssertEqual(imageStore.persistCalls.count, 1)
        XCTAssertEqual(history.addedItems.count, 1)
        XCTAssertEqual(coordinator.latestHistoryItem, history.addedItems.first)
        XCTAssertEqual(coordinator.currentPhase, .report)
        XCTAssertTrue(coordinator.isComplete)
        XCTAssertEqual(coordinator.explainability?.policy.canonicalCategory, analysis.extras.policy.canonicalCategory)
        XCTAssertEqual(analyzer.capturedVisionContext?.guessName, vision.result.guess.name)
    }

    func test_cancelAnalysis_resetsPhase_andCancelsAnalyzer() {
        let analyzer = MockAnalyzer(result: makeAnalyzedSafety())
        let history = MockHistoryService()
        let imageStore = MockImageStore(result: makePersistedImage())
        let vision = MockVisionService(result: makeVisionAnalysisResult())
        let coordinator = ScanAnalysisCoordinator(analyzer: analyzer, visionService: vision, historyService: history, imageStore: imageStore)

        coordinator.currentPhase = .openAI
        coordinator.cancelAnalysis()

        XCTAssertEqual(analyzer.cancelCallCount, 1)
        XCTAssertEqual(coordinator.currentPhase, .preparing)
    }

    func test_startGeminiScan_propagatesVisionFailure() async {
        let analyzer = MockAnalyzer(result: makeAnalyzedSafety())
        let history = MockHistoryService()
        let imageStore = MockImageStore(result: makePersistedImage())
        let failingVision = FailingVisionService(error: VisionError.failedRequest)
        let coordinator = ScanAnalysisCoordinator(analyzer: analyzer, visionService: failingVision, historyService: history, imageStore: imageStore)

        let image = makeImage()

        do {
            try await coordinator.startGeminiScan(image: image, options: SafetyOptions(includeDogs: false, includeCats: false, includeChildren: true))
            XCTFail("Expected vision failure to throw")
        } catch let error as ScanError {
            switch error {
            case .visionFailed:
                break
            default:
                XCTFail("Expected visionFailed, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(analyzer.analyzeCallCount, 0)
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
            recalls: [],
            kidPros: ["High fibre"],
            kidCons: ["High sugar"],
            kidNarrative: "Mock child narrative",
            dogPros: ["Offer sparingly", "Serve with water", "Check label for xylitol"],
            dogCons: ["Contains xylitol", "High sugar load", "Possible GI upset"],
            dogNarrative: "Mock dog narrative",
            catPros: ["Provide alternative treats", "Consult vet first", "Keep portions minimal"],
            catCons: ["Sweeteners upset cats", "High sugar", "Potential digestive distress"],
            catNarrative: "Mock cat narrative"
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

    private func makeVisionAnalysisResult() -> VisionAnalysisResult {
        let guess = ProductGuess(name: "Fruit Snack", type: "Snack", confidence: 0.82, brand: "SnackCo")
        return VisionAnalysisResult(
            guess: guess,
            labels: ["fruit", "snack"],
            objects: ["box"],
            detectedText: "SnackCo Fruit Snack",
            brandCandidates: ["SnackCo"],
            confidence: guess.confidence,
            sanitizedContext: "{\"labels\":[\"fruit\",\"snack\"]}",
            bestGuess: "Fruit Snack"
        )
    }
}

// MARK: - Test Doubles

private final class MockAnalyzer: SafetyAnalyzing {
    var analyzeCallCount = 0
    var cancelCallCount = 0
    var capturedOptions: SafetyOptions?
    var capturedImages: [UIImage] = []
    var result: AnalyzedSafety
    var capturedVisionContext: VisionContextPayload?

    init(result: AnalyzedSafety) {
        self.result = result
    }

    func analyzeSafetyWithExtras(
        image: UIImage,
        options: SafetyOptions,
        streamToken: @escaping (String) -> Void,
        visionLabels: [String],
        ocrHits: [String],
        visionContext: VisionContextPayload?
    ) async throws -> AnalyzedSafety {
        analyzeCallCount += 1
        capturedImages.append(image)
        capturedOptions = options
        streamToken("testing")
        capturedVisionContext = visionContext
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

private final class MockVisionService: VisionServiceType {
    var analyzeCallCount = 0
    let result: VisionAnalysisResult

    init(result: VisionAnalysisResult) {
        self.result = result
    }

    func recognizeProduct(from image: CGImage) async throws -> ProductGuess {
        result.guess
    }

    func analyze(image: UIImage) async throws -> VisionAnalysisResult {
        analyzeCallCount += 1
        return result
    }
}

private final class FailingVisionService: VisionServiceType {
    let error: Error

    init(error: Error) {
        self.error = error
    }

    func recognizeProduct(from image: CGImage) async throws -> ProductGuess {
        throw error
    }

    func analyze(image: UIImage) async throws -> VisionAnalysisResult {
        throw error
    }
}
