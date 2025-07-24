//
//  ScanHistoryServiceTests.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import XCTest
@testable import SafeSnap
import UIKit

final class ScanHistoryServiceTests: XCTestCase {
    
    func makeTestItem(name: String = "Item", score: Int = 9) -> ScanHistoryItem {
        ScanHistoryItem(
            product: Product(
                id: UUID().uuidString,
                name: name,
                productType: "Food",
                safetyScore: score,
                safetyLevel: "Safe",
                pros: [],
                cons: [],
                certifications: [],
                hygieneWarnings: []
            ),
            labels: [],
            score: score,
            thumbnail: UIImage()
        )
    }

    func test_add_insertsItem() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        let recordsCount0 = await MainActor.run { service.records.count }
        XCTAssertEqual(recordsCount0, 0)

        let item = makeTestItem()
        await service.add(item)

        let recordsCount1 = await MainActor.run { service.records.count }
        XCTAssertEqual(recordsCount1, 1)
        let firstName = await MainActor.run { service.records.first?.product.name }
        XCTAssertEqual(firstName, item.product.name)
    }

    func test_delete_removesCorrectItem() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        
        let item1 = makeTestItem(name: "Item 1")
        let item2 = makeTestItem(name: "Item 2")
        await service.add(item1)
        await service.add(item2)

        await service.delete(at: IndexSet(integer: 0))

        let recordsCount = await MainActor.run { service.records.count }
        XCTAssertEqual(recordsCount, 1)
        let firstName = await MainActor.run { service.records.first?.product.name }
        XCTAssertEqual(firstName == "Item 1", true)
    }

    func test_clearAll_removesEverything() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        await service.add(makeTestItem())
        await service.add(makeTestItem())
        
        let recordsCount = await MainActor.run { service.records.count }
        XCTAssertEqual(recordsCount, 2)

        await service.clearAll()

        let clearedRecordsCount = await MainActor.run { service.records.count }
        XCTAssertEqual(clearedRecordsCount, 0)
    }

    func test_save_and_load_consistency() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        let item = makeTestItem()
        await service.add(item)
        await service.saveSynchronously()

        let newService = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        let restored = await MainActor.run { newService.records }

        XCTAssertTrue(restored.contains(where: { $0.product.id == item.product.id }))
    }
}
