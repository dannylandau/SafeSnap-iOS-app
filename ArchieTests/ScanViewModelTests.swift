//
//  ScanViewModelTests.swift
//  Archie
//
//  Tests the ScanViewModel's orchestration of scan flow and retry behaviour.
//

import XCTest
@testable import Archie
import Combine
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
            recalls: [],
            kidPros: ["Rich in fibre"],
            kidCons: ["High sugar"],
            kidNarrative: "Mock child narrative",
            dogPros: includeDogs ? ["Offer only as treat", "Provide water", "Observe energy levels"] : nil,
            dogCons: includeDogs ? ["Contains xylitol", "High sugar", "Loose stool risk"] : nil,
            dogNarrative: includeDogs ? "Mock dog narrative" : nil,
            catPros: includeCats ? ["Serve tiny nibble", "Monitor appetite", "Consult vet"] : nil,
            catCons: includeCats ? ["Artificial sweetener risk", "High sugar", "Possible vomiting"] : nil,
            catNarrative: includeCats ? "Mock cat narrative" : nil
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
            visionBestGuess: nil,
            visionWebEntities: [],
            analysis: analysis,
            model: "archie-backend",
            promptVersion: "v1",
            productAnalysis: nil,
            appVersion: "1.0"
        )
    }
    
    private func makeProductAnalysis() -> ProductAnalysis {
        ProductAnalysis(
            id: "fruit-snack-123",
            name: "Fruit Snack",
            image: "",
            imageUrl: nil,
            safetyScore: SafetyScore(overall: 7),
            category: "Snack",
            recognitionStatus: .success,
            analysis: SafetyAnalysis(
                kidSafety: KidSafety(status: .safe, score: 70, benefits: [], concerns: [], narrative: nil),
                petSafety: PetSafetyAnalysis(dogs: nil, cats: nil),
                hygiene: HygieneAnalysis(recommendations: [], warnings: []),
                generalSafety: GeneralSafetyAnalysis(pros: [], cons: []),
                recalls: []
            ),
            petSafetyOptions: PetSafetyOptions(includeDogs: true, includeCats: false, includeChildren: true),
            analysisMetadata: nil
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
        coordinator.stubProductAnalysis = makeProductAnalysis()
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
        coordinator.stubProductAnalysis = makeProductAnalysis()
        let viewModel = ScanViewModel(coordinator: coordinator)
        let image = makeImage()
        let data = image.jpegData(compressionQuality: 0.7)!

        viewModel.beginScan(with: data, uiImage: image, includeDog: false, includeCat: false, includeChildren: true)
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(coordinator.startCalls.count, 1)
        XCTAssertEqual(coordinator.startCalls.first?.includeChildren, true)
    }

    @MainActor
    func test_beginScan_recordsDurationWhenFlagEnabled() async {
        let coordinator = MockCoordinator()
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: false, includeCats: false, includeChildren: true)
        coordinator.stubProductAnalysis = makeProductAnalysis()

        let tracker = MockScanDurationTracker()
        tracker.stubbedStopDuration = .nanoseconds(1_500_000_000) // 1.5s
        let formatter = StubDurationFormatter()
        formatter.stubbedValue = "1.5 s"
        let featureFlags = StubFeatureFlags(initialValue: true)

        let viewModel = ScanViewModel(
            coordinator: coordinator,
            durationTracker: tracker,
            durationFormatter: formatter,
            featureFlags: featureFlags
        )

        let image = makeImage()
        let data = image.jpegData(compressionQuality: 0.8)!

        viewModel.beginScan(with: data, uiImage: image, includeDog: false, includeCat: false, includeChildren: true)
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(tracker.startCallCount, 1)
        XCTAssertEqual(tracker.stopCallCount, 1)
        XCTAssertEqual(viewModel.scanDurationText, "1.5 s")
        XCTAssertEqual(viewModel.resultVM?.scanDurationDescription, "1.5 s")
        XCTAssertEqual(formatter.capturedDurations.count, 1)
    }

    @MainActor
    func test_beginScan_skipsDurationWhenFlagDisabled() async {
        let coordinator = MockCoordinator()
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: true, includeCats: false, includeChildren: true)
        coordinator.stubProductAnalysis = makeProductAnalysis()

        let tracker = MockScanDurationTracker()
        tracker.stubbedStopDuration = .nanoseconds(900_000_000)
        let formatter = StubDurationFormatter()
        formatter.stubbedValue = "0.9 s"
        let featureFlags = StubFeatureFlags(initialValue: false)

        let viewModel = ScanViewModel(
            coordinator: coordinator,
            durationTracker: tracker,
            durationFormatter: formatter,
            featureFlags: featureFlags
        )

        let image = makeImage()
        let data = image.jpegData(compressionQuality: 0.8)!

        viewModel.beginScan(with: data, uiImage: image, includeDog: true, includeCat: false, includeChildren: true)
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(tracker.startCallCount, 0, "Timer should not start when flag disabled")
        XCTAssertEqual(tracker.stopCallCount, 0, "Timer should not stop when flag disabled")
        XCTAssertNil(viewModel.scanDurationText)
        XCTAssertNil(viewModel.resultVM?.scanDurationDescription)
        XCTAssertTrue(formatter.capturedDurations.isEmpty)
    }

    @MainActor
    func test_toggleDurationFlag_persistsOverrideAndResetsWhenDisabled() async {
        let featureFlags = StubFeatureFlags(initialValue: true)
        let tracker = MockScanDurationTracker()
        tracker.stubbedStopDuration = .nanoseconds(500_000_000)
        let formatter = StubDurationFormatter()
        formatter.stubbedValue = "0.50 s"

        let viewModel = ScanViewModel(
            coordinator: MockCoordinator(),
            durationTracker: tracker,
            durationFormatter: formatter,
            featureFlags: featureFlags
        )

        XCTAssertTrue(viewModel.scanDurationEnabled)

        await viewModel.setScanDurationTrackingEnabled(false)

        XCTAssertFalse(viewModel.scanDurationEnabled)
        XCTAssertEqual(featureFlags.isEnabled(.scanDurationTimer), false)
        XCTAssertEqual(tracker.resetCallCount, 1)
        XCTAssertNil(viewModel.scanDurationText)
    }

    @MainActor
    func test_retryLastScan_reusesPreviousToggleState() async {
        let coordinator = MockCoordinator()
        coordinator.stubHistoryItem = makeHistoryItem(includeDogs: false, includeCats: true, includeChildren: true)
        coordinator.stubProductAnalysis = makeProductAnalysis()
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
        coordinator.stubProductAnalysis = makeProductAnalysis()
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
private final class MockScanDurationTracker: ScanDurationTracking {
    private(set) var elapsed: Duration? = nil
    var startCallCount = 0
    var stopCallCount = 0
    var resetCallCount = 0
    var stubbedStopDuration: Duration? = nil

    func start() {
        startCallCount += 1
    }

    func stop() -> Duration? {
        stopCallCount += 1
        elapsed = stubbedStopDuration
        return stubbedStopDuration
    }

    func reset() {
        resetCallCount += 1
        elapsed = nil
    }
}

private final class StubDurationFormatter: ScanDurationFormatting {
    var stubbedValue: String = ""
    private(set) var capturedDurations: [Duration] = []

    func string(from duration: Duration) -> String {
        capturedDurations.append(duration)
        return stubbedValue
    }
}

private final class StubFeatureFlags: FeatureFlagProviding {
    private var value: Bool

    init(initialValue: Bool) {
        self.value = initialValue
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        value
    }

    func setEnabled(_ flag: FeatureFlag, value: Bool) {
        self.value = value
    }

    func clearOverride(_ flag: FeatureFlag) {
        value = false
    }
}

@MainActor
private final class MockCoordinator: ScanAnalysisCoordinating {
    var startCalls: [SafetyOptions] = []
    var cancelCallCount = 0
    var stubHistoryItem: ScanHistoryItem?
    var stubProductAnalysis: ProductAnalysis?
    var latestHistoryItem: ScanHistoryItem?
    var latestProductAnalysis: ProductAnalysis?
    var stage: AnalysisStage = .fast
    var fastDuration: TimeInterval? = nil
    var smartDuration: TimeInterval? = nil
    
    private let stageSubject = CurrentValueSubject<AnalysisStage, Never>(.fast)
    private let partialSubject = CurrentValueSubject<String?, Never>(nil)
    private let bestGuessSubject = CurrentValueSubject<String?, Never>(nil)
    private let webEntitiesSubject = CurrentValueSubject<[String], Never>([])

    func startGeminiScan(image: UIImage, options: SafetyOptions) async throws {
        startCalls.append(options)
        latestHistoryItem = stubHistoryItem
        latestProductAnalysis = stubProductAnalysis
    }

    func cancelAnalysis() {
        cancelCallCount += 1
    }

    var stagePublisher: AnyPublisher<AnalysisStage, Never> { stageSubject.eraseToAnyPublisher() }
    var partialPublisher: AnyPublisher<String?, Never> { partialSubject.eraseToAnyPublisher() }
    var visionBestGuessPublisher: AnyPublisher<String?, Never> { bestGuessSubject.eraseToAnyPublisher() }
    var visionWebEntitiesPublisher: AnyPublisher<[String], Never> { webEntitiesSubject.eraseToAnyPublisher() }
}
