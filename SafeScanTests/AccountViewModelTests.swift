//
//  AccountViewModelTests.swift
//  SafeSnap
//  Created by Marcin Grześkowiak on 23/07/2025.

import XCTest
@testable import SafeSnap

@MainActor
final class AccountViewModelTests: XCTestCase {

    func test_statsAreCalculatedCorrectly() async throws {
        // 60, 70, 90 => avg ≈ 7.3 after normalisation in AccountViewModel
        let historyService = makeHistoryService()
        historyService.add(makeTestItem(score: 60))
        historyService.add(makeTestItem(score: 70))
        historyService.add(makeTestItem(score: 90))

        let viewModel = AccountViewModel(userSession: MockUserSession(), historyService: historyService)

        try await waitUntil(timeout: 1.0) { viewModel.stats.contains(where: { $0.label == "Scans" }) }

        let stats = viewModel.stats
        let scanCount = stats.first(where: { $0.label == "Scans" })?.value
        let avgScore = stats.first(where: { $0.label == "Avg Score" })?.value

        XCTAssertEqual(scanCount, "3")
        XCTAssertEqual(avgScore, "7.3")
    }

    func test_userDetails_areExposed() {
        let historyService = makeHistoryService()
        let viewModel = AccountViewModel(userSession: MockUserSession(), historyService: historyService)

        XCTAssertEqual(viewModel.fullName, "Jane Doe")
        XCTAssertEqual(viewModel.email, "jane@example.com")
        XCTAssertEqual(viewModel.memberSince, "Feb 1974")
    }

    // MARK: - Helpers

    private func makeHistoryService() -> ScanHistoryService {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return ScanHistoryService(fileURL: fileURL)
    }

    private func makeTestItem(score: Int = 90) -> ScanHistoryItem {
        let analysis = SafetyAnalysisResponse(
            productName: "Mock Product",
            productType: "Snack",
            overallSafetyScore: score,
            childSafetyScore: score,
            dogSafetyScore: score,
            catSafetyScore: score,
            modelConfidence: 0.9,
            recognitionConfidence: 0.8,
            generalSafety: .init(pros: [], cons: []),
            petSafety: .init(dogs: [], cats: []),
            hygieneWarnings: [],
            recalls: [],
            kidPros: ["Tastes good"],
            kidCons: ["High sugar"],
            kidNarrative: "Mock narrative"
        )

        return ScanHistoryItem(
            imageFilename: nil,
            imageHash: UUID().uuidString,
            userToggles: .init(includeDogs: false, includeCats: false, includeChildren: false),
            productName: analysis.productName,
            productType: analysis.productType,
            categoryName: analysis.productType,
            brand: "TestCo",
            confidence: 0.9,
            visionContextRef: nil,
            analysis: analysis,
            model: "test-model",
            promptVersion: "test-prompt",
            appVersion: "1.0-test"
        )
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
