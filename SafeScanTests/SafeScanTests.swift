//
//  SafeScanTests.swift
//  SafeScanTests
//
//  Created by Marcin Grześkowiak on 26/06/2025.
//

import XCTest
@testable import SafeSnap
import SwiftUI
import UIKit

@MainActor
final class SafeSnapEndToEndTests: XCTestCase {

    func test_fullScanFlow_addsResultToHistory() async throws {
        let historyService = makeHistoryService()
        let analyzer = MockAnalyzer(result: makeAnalyzedSafety())
        let imageStore = InMemoryImageStore()
        let coordinator = ScanAnalysisCoordinator(analyzer: analyzer, historyService: historyService, imageStore: imageStore)
        let viewModel = ScanViewModel(coordinator: coordinator)

        let (image, data) = makeImage()
        viewModel.beginScan(with: data, uiImage: image, includeDog: true, includeCat: false, includeChildren: true)

        try await waitForHistoryCount(on: historyService, expected: 1)

        XCTAssertEqual(historyService.records.count, 1)
        XCTAssertEqual(historyService.records.first?.analysis.productName, analyzer.result.response.productName)
        if case .result = viewModel.phase {
            XCTAssertNotNil(viewModel.resultVM)
        } else {
            XCTFail("Expected scan to finish with a result phase")
        }
    }

    func test_scanAppearsInAccountStats() async throws {
        let historyService = makeHistoryService()
        let analyzer = MockAnalyzer(result: makeAnalyzedSafety())
        let imageStore = InMemoryImageStore()
        let coordinator = ScanAnalysisCoordinator(analyzer: analyzer, historyService: historyService, imageStore: imageStore)
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

    // MARK: - Helpers

    private func makeHistoryService() -> ScanHistoryService {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return ScanHistoryService(fileURL: fileURL)
    }

    private func makeAnalyzedSafety(name: String = "Fruit Snack") -> AnalyzedSafety {
        let pros = [SafetyAnalysisResponse.LabeledItem(label: "High fibre", severity: .low, category: "nutrition")]
        let cons = [SafetyAnalysisResponse.LabeledItem(label: "High sugar", severity: .medium, category: "nutrition")]
        let general = SafetyAnalysisResponse.GeneralSafety(pros: pros, cons: cons)
        let pet = SafetyAnalysisResponse.PetSafety(
            dogs: [SafetyAnalysisResponse.PetWarning(severity: .medium, warning: "Limit treats", reason: "Contains xylitol")],
            cats: []
        )
        let response = SafetyAnalysisResponse(
            productName: name,
            productType: "Snack",
            overallSafetyScore: 70,
            childSafetyScore: 65,
            dogSafetyScore: 40,
            catSafetyScore: 80,
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

private final class MockAnalyzer: SafetyAnalyzing {
    var analyzeCallCount = 0
    var cancelCallCount = 0
    let result: AnalyzedSafety

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
        streamToken("testing")
        return result
    }

    func cancelAnalysis() {
        cancelCallCount += 1
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
