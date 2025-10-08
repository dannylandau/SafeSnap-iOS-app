//
//  ScanHistoryServiceTests.swift
//  SafeSnap
//
//  Updated to exercise the persistence model introduced by ScanHistoryItem v2.
//

import XCTest
@testable import SafeSnap
import UIKit

@MainActor
final class ScanHistoryServiceTests: XCTestCase {

    private func makeAnalysis(productName: String, productType: String = "Snack", score: Int = 70) -> SafetyAnalysisResponse {
        let pros = [SafetyAnalysisResponse.LabeledItem(label: "Nutritious", severity: .low, category: "nutrition")]
        let cons = [SafetyAnalysisResponse.LabeledItem(label: "Sugary", severity: .medium, category: "nutrition")]
        let general = SafetyAnalysisResponse.GeneralSafety(pros: pros, cons: cons)
        let petWarnings = SafetyAnalysisResponse.PetSafety(
            dogs: [SafetyAnalysisResponse.PetWarning(severity: .low, warning: "Monitor intake", reason: "Contains sugar")],
            cats: []
        )
        return SafetyAnalysisResponse(
            productName: productName,
            productType: productType,
            overallSafetyScore: score,
            childSafetyScore: score,
            dogSafetyScore: score,
            catSafetyScore: score,
            modelConfidence: 0.8,
            recognitionConfidence: 0.9,
            generalSafety: general,
            petSafety: petWarnings,
            hygieneWarnings: [],
            recalls: [],
            kidPros: ["Nutritious"],
            kidCons: ["Sugary"],
            kidNarrative: "Mock narrative",
            dogPros: ["Offer sparingly", "Pair with water", "Observe for symptoms"],
            dogCons: ["Contains sugar", "Monitor weight", "Possible hyperactivity"],
            dogNarrative: "Mock dog narrative",
            catPros: ["Rare treat only", "Tiny nibble portions", "Monitor litter habits"],
            catCons: ["Too much sugar", "No cat benefit", "Potential diarrhea"],
            catNarrative: "Mock cat narrative"
        )
    }

    private func makeHistoryItem(name: String = "Item", score: Int = 70) -> ScanHistoryItem {
        let analysis = makeAnalysis(productName: name, score: score)
        return ScanHistoryItem(
            imageFilename: "IMG_stub.jpg",
            imageHash: UUID().uuidString,
            userToggles: .init(includeDogs: true, includeCats: false, includeChildren: true),
            productName: analysis.productName,
            productType: analysis.productType,
            categoryName: analysis.productType,
            brand: "SnackCo",
            confidence: 0.92,
            visionContextRef: nil,
            analysis: analysis,
            model: "gemini-1.5-flash",
            promptVersion: "v1",
            appVersion: "1.0"
        )
    }

    func test_add_insertsItem() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = ScanHistoryService(fileURL: fileURL)
        XCTAssertEqual(service.records.count, 0)

        let item = makeHistoryItem()
        service.add(item)

        XCTAssertEqual(service.records.count, 1)
        XCTAssertEqual(service.records.first?.productName, item.productName)
    }

    func test_delete_removesCorrectItem() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = ScanHistoryService(fileURL: fileURL)

        let item1 = makeHistoryItem(name: "Item 1")
        let item2 = makeHistoryItem(name: "Item 2")
        service.add(item1)
        service.add(item2)

        service.delete(at: IndexSet(integer: 0))

        XCTAssertEqual(service.records.count, 1)
        XCTAssertEqual(service.records.first?.productName, "Item 1")
    }

    func test_clearAll_removesEverything() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = ScanHistoryService(fileURL: fileURL)
        service.add(makeHistoryItem())
        service.add(makeHistoryItem())

        XCTAssertEqual(service.records.count, 2)

        service.clearAll()

        XCTAssertEqual(service.records.count, 0)
    }

    func test_save_and_load_consistency() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = ScanHistoryService(fileURL: fileURL)
        let item = makeHistoryItem(name: "Persisted")
        service.add(item)
        await service.saveSynchronously()

        let newService = ScanHistoryService(fileURL: fileURL)
        let restoredNames = newService.records.map(\.productName)

        XCTAssertTrue(restoredNames.contains("Persisted"))
    }
}
