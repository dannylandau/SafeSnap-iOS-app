//
//  ScanViewModelTests.swift
//  SafeSnap
//
//  Updated to exercise the Gemini-based scan pipeline and retry behaviour.
//

import XCTest
@testable import SafeSnap
import UIKit

final class ScanViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
        }
    }

    private func makeHistoryItem(includeDogs: Bool, includeCats: Bool, includeChildren: Bool) -> ScanHistoryItem {
        let pros = [SafetyAnalysisResponse.LabeledItem(label: "Rich in fibre", severity: .low, category: "nutrition")]
        let cons = [SafetyAnalysisResponse.LabeledItem(label: "High sugar", severity: .medium, category: "nutrition")]
        let general = SafetyAnalysisResponse.GeneralSafety(pros: pros, cons: cons)
        let petWarnings = SafetyAnalysisResponse.PetSafety(
            dogs: includeDogs ? [SafetyAnalysisResponse.PetWarning(severity: .medium, warning: "Limit treats", reason: "Contains xylitol")] : [],
            cats: includeCats ? [SafetyAnalysisResponse.PetWarning(severity: .high, warning: "Toxic", reason: "Artificial sweetener")] : []
        )
        let analysis = SafetyAnalysisResponse(
            productName: "Fruit Snack",
            productType: "Snack",
            overallSafetyScore: 70,
            childSafetyScore: includeChildren ? 55 : 70,
            dogSafetyScore: includeDogs ? 40 : 90,
            catSafetyScore: includeCats ? 30 : 90,
            modelConfidence: 0.88,
            recognitionConfidence: 0.8,
            generalSafety: general,
            petSafety: petWarnings,
            hygieneWarnings: [],
            recalls: []
        )

        return ScanHistoryItem(
            imageFilename: "IMG_stub.jpg",
            imageHash: UUID().uuidString,
            userToggles: .init(includeDogs: includeDogs, includeCats: includeCats, includeChildren: includeChildren),
            productName: analysis.productName,
            productType: analysis.productType,
            categoryName: analysis.productType,
            brand: "SnackCo",
            confidence: 0.9,
            visionContextRef: nil,
            analysis: analysis,
            model: "gemini-1.5-flash",
            promptVersion: "v1",
            appVersion: "1.0"
        )
    }

    // MARK: - Tests

    @MainActor
    func test_handleImage_setsPhaseToAnalyzing() async {
        let coordinator = MockCoordinator()
        let viewModel = ScanViewModel(coordinator: coordinator)
        let image = makeImage()

        viewModel.handleImage(image)
        try? await Task.sleep(nanoseconds: 50_000_000)

        if case let .analyzing(liveImage) = viewModel.phase {
            XCTAssertNotNil(liveImage)
        } else {
            XCTFail("Expected phase to become .analyzing after handleImage")
        }
    }

    @MainActor
    func test_beginScan_populatesResult_andRecordsToggles() async {
        let coordinator = MockCoordinator()
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: true, includeCats: false, includeChildren: true)
        let viewModel = ScanViewModel(coordinator: coordinator)

        let image = makeImage()
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return XCTFail("Failed to encode sample image")
        }

        viewModel.beginScan(with: data, uiImage: image, includeDog: true, includeCat: false, includeChildren: true)

        try? await Task.sleep(nanoseconds: 150_000_000) // allow async task to finish

        XCTAssertEqual(coordinator.startCalls.count, 1)
        XCTAssertTrue(coordinator.startCalls.first?.includeDogs ?? false)
        XCTAssertEqual(coordinator.startCalls.first?.includeCats, false)
        XCTAssertEqual(coordinator.startCalls.first?.includeChildren, true)
        XCTAssertNotNil(viewModel.resultVM, "Result view model should be populated after coordinator returns")
        if case .result = viewModel.phase {
            // expected
        } else {
            XCTFail("Expected phase to be .result after successful scan")
        }
    }

    @MainActor
    func test_beginScan_forwardsChildToggleToCoordinator() async {
        let coordinator = MockCoordinator()
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: false, includeCats: false, includeChildren: true)
        let viewModel = ScanViewModel(coordinator: coordinator)
        let image = makeImage()
        let data = image.jpegData(compressionQuality: 0.7)!

        viewModel.beginScan(with: data, uiImage: image, includeDog: false, includeCat: false, includeChildren: true)
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(coordinator.startCalls.count, 1)
        XCTAssertEqual(coordinator.startCalls.first?.includeChildren, true)
    }

    @MainActor
    func test_retryLastScan_reusesPreviousToggleState() async {
        let coordinator = MockCoordinator()
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: false, includeCats: true, includeChildren: true)
        let viewModel = ScanViewModel(coordinator: coordinator)
        let image = makeImage()
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            return XCTFail("Failed to encode sample image")
        }

        viewModel.beginScan(with: data, uiImage: image, includeDog: false, includeCat: true, includeChildren: true)
        try? await Task.sleep(nanoseconds: 150_000_000)

        // Trigger retry
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: false, includeCats: true, includeChildren: true)
        viewModel.retryLastScan()
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(coordinator.startCalls.count, 2)
        let first = coordinator.startCalls.first
        let second = coordinator.startCalls.last
        XCTAssertEqual(first?.includeDogs, second?.includeDogs)
        XCTAssertEqual(first?.includeCats, second?.includeCats)
        XCTAssertEqual(first?.includeChildren, second?.includeChildren)
    }

    @MainActor
    func test_cancelScan_clearsState() async {
        let coordinator = MockCoordinator()
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: false, includeCats: false, includeChildren: true)
        let viewModel = ScanViewModel(coordinator: coordinator)
        let image = makeImage()
        let data = image.jpegData(compressionQuality: 0.8)!

        viewModel.beginScan(with: data, uiImage: image, includeDog: false, includeCat: false, includeChildren: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        viewModel.cancelScan()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(coordinator.cancelCallCount, 1)
        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertNil(viewModel.resultVM)
    }
}

// MARK: - Mocks

@MainActor
private final class MockCoordinator: ScanAnalysisCoordinating {
    var startCalls: [SafetyOptions] = []
    var cancelCallCount = 0
    var stubHistoryItem: ScanHistoryItem?
    var latestHistoryItem: ScanHistoryItem?
    var stage: SafetyAnalyzer.Stage = .fast

    func startGeminiScan(image: UIImage, options: SafetyOptions) async throws {
        startCalls.append(options)
        latestHistoryItem = stubHistoryItem
    }

    func cancelAnalysis() {
        cancelCallCount += 1
    }
}
