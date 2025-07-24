//
//  AccountViewModelTests.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import XCTest
@testable import SafeSnap

final class AccountViewModelTests: XCTestCase {
    
    func test_statsAreCalculatedCorrectly() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let historyService = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        
        await historyService.add(makeTestItem(score: 6))
        await historyService.add(makeTestItem(score: 7))
        await historyService.add(makeTestItem(score: 9))
        
        let vm = await AccountViewModel(userSession: MockUserSession(), historyService: historyService)
        try? await Task.sleep(nanoseconds: 200_000_000) // allow stats to load

        let stats = await MainActor.run { vm.stats }

        let scanCount = stats.first(where: { $0.label == "Scans" })?.value
        let avgScore = stats.first(where: { $0.label == "Avg Score" })?.value

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
        XCTAssertEqual(memberSince, "Feb 1974") // or your formatter output
    }
    
    func makeTestItem(score: Int = 9) -> ScanHistoryItem {
        return ScanHistoryItem(
            product: Product(
                id: UUID().uuidString,
                name: "Mock Product",
                productType: "Food",
                safetyScore: score,
                safetyLevel: "Good",
                pros: [],
                cons: [],
                certifications: [],
                hygieneWarnings: []
            ),
            labels: ["Mock"],
            score: score,
            thumbnail: UIImage()
        )
    }
}
