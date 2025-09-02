//
//  AccountViewModelTests.swift
//  SafeSnap
//  Created by Marcin Grześkowiak on 23/07/2025.

import XCTest
import UIKit
@testable import SafeSnap

final class AccountViewModelTests: XCTestCase {

    func test_statsAreCalculatedCorrectly() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let historyService = await MainActor.run { ScanHistoryService(fileURL: fileURL) }

        // 6, 7, 9 => avg = 7.33 -> "7.3"
        await historyService.add(makeTestItem(score: 6))
        await historyService.add(makeTestItem(score: 7))
        await historyService.add(makeTestItem(score: 9))

        let vm = await AccountViewModel(userSession: MockUserSession(), historyService: historyService)
        try? await Task.sleep(nanoseconds: 200_000_000) // allow stats to load

        let stats = await MainActor.run { vm.stats }

        let scanCount = stats.first(where: { $0.label == "Scans" })?.value
        let avgScore  = stats.first(where: { $0.label == "Avg Score" })?.value

        XCTAssertEqual(scanCount, "3", "Expected scan count to match number of records")
        XCTAssertEqual(avgScore, "7.3", "Expected average score to be correctly calculated")
    }

    @MainActor func test_userDetails_areCorrect() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let historyService = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        let vm = AccountViewModel(userSession: MockUserSession(), historyService: historyService)

        let fullName = await MainActor.run { vm.fullName }
        let email = await MainActor.run { vm.email }
        let memberSince = await MainActor.run { vm.memberSince }

        XCTAssertEqual(fullName, "Jane Doe")
        XCTAssertEqual(email, "jane@example.com")
        XCTAssertEqual(memberSince, "Feb 1974") // adjust if your formatter differs
    }

    // MARK: - Helpers
    /// Build a minimal but valid `ScanHistoryItem` using the new canonical pipeline.
    func makeTestItem(score: Int = 9) -> ScanHistoryItem {
        // Minimal product-identification stub
        let product = ProductIdentification(
            productName: "Mock Product",
            categoryName: "Food",
            specificType: "Item",
            productType: "food",
            brand: nil,
            confidence: 0.9,
            labels: ["Mock"],
            detectedText: nil,
            objects: nil,
            webEntities: nil
        )

        // Minimal OpenAI safety analysis stub
        let analysis = SafetyAnalysisResponse(
            overallSafetyScore: score,
            generalSafety: .init(
                pros: [],
                cons: []
            ),
            petSafety: nil, // toggles off in tests
            hygieneWarnings: [],
            recalls: []
        )

        // Signals summary (compact)
        let signals = ScanHistoryItem.SignalsSummary(
            labels: ["Mock"],
            objects: [],
            webEntities: [],
            bestGuess: nil,
            detectedTextExcerpt: nil
        )

        // User toggles (none for these tests)
        let toggles = ScanHistoryItem.UserToggles(
            includeDogs: false,
            includeCats: false,
            includeChildren: false
        )

        // Build canonical snapshot (no image needed for tests)
        let item = ScanHistoryBuilder.build(
            product: product,
            analysis: analysis,
            imageRef: nil,
            imageData: Data(),
            userToggles: toggles,
            signals: signals,
            visionContextRef: nil,
            model: "test",
            promptVersion: "test"
        )
        return item
    }
}
