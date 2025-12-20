//
//  ScanHistoryBuilderTests.swift
//  Archie
//
//  Validates that the builder normalises images and hashes consistently.
//

import XCTest
@testable import Archie
import CryptoKit

final class ScanHistoryBuilderTests: XCTestCase {

    func test_build_capturesImageFilenameAndHash() {
        let (imageURL, data) = makeImageArtifacts()
        let product = ProductIdentification(
            productType: "Snack",
            productName: "Fruit Snack",
            brandCandidates: ["SnackCo"],
            labels: ["fruit"],
            objects: ["bar"],
            detectedText: "Fruit Snack",
            confidence: 0.92,
            bestGuess: "fruit snack",
            webEntities: ["fruit snack"]
        )
        let analysis = makeAnalysis()
        let toggles = ScanHistoryItem.UserToggles(includeDogs: true, includeCats: false, includeChildren: true)

        let item = ScanHistoryBuilder.build(
            product: product,
            analysis: analysis,
            imageRef: imageURL,
            imageData: data,
            userToggles: toggles,
            visionContextRef: nil,
            model: "gemini-test",
            promptVersion: "v-test"
        )

        XCTAssertEqual(item.imageFilename, imageURL.lastPathComponent)
        XCTAssertEqual(item.brand, product.brandCandidates.first)
        XCTAssertEqual(item.userToggles, toggles)
        XCTAssertEqual(item.model, "gemini-test")
        XCTAssertEqual(item.promptVersion, "v-test")
        XCTAssertEqual(item.analysis.productName, analysis.productName)
        XCTAssertEqual(item.visionBestGuess, product.bestGuess)
        XCTAssertEqual(item.visionWebEntities, product.webEntities)

        let expectedHash = sha256Hex(data)
        XCTAssertEqual(item.imageHash, expectedHash)
    }

    // MARK: - Helpers

    private func makeImageArtifacts() -> (URL, Data) {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("IMG_\(UUID().uuidString).jpg")
        let data = Data([0, 1, 2, 3, 4, 5])
        return (url, data)
    }

    private func makeAnalysis() -> SafetyAnalysisResponse {
        let pros = [SafetyAnalysisResponse.LabeledItem(label: "High fibre", severity: .low, category: "nutrition")]
        let cons = [SafetyAnalysisResponse.LabeledItem(label: "High sugar", severity: .medium, category: "nutrition")]
        return SafetyAnalysisResponse(
            productName: "Fruit Snack",
            productType: "Snack",
            overallSafetyScore: 70,
            childSafetyScore: 65,
            dogSafetyScore: 50,
            catSafetyScore: 40,
            modelConfidence: 0.9,
            recognitionConfidence: 0.8,
            generalSafety: .init(pros: pros, cons: cons),
            petSafety: .init(dogs: [], cats: []),
            hygieneWarnings: [],
            recalls: [],
            kidPros: ["High fibre"],
            kidCons: ["High sugar"],
            kidNarrative: "Mock narrative",
            dogPros: ["Serve with water", "Offer only occasionally", "Watch for sugar crashes"],
            dogCons: ["High sugar", "Possible choking risk", "Artificial flavors irritate"],
            dogNarrative: "Mock dog narrative",
            catPros: ["Only as rare treat", "Break into tiny pieces", "Monitor appetite"],
            catCons: ["Sugar overload", "No nutritional value", "Possible vomiting"],
            catNarrative: "Mock cat narrative"
        )
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
