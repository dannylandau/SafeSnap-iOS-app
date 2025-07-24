//
//  ScanViewModelTests.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import XCTest
@testable import SafeSnap
import UIKit

final class ScanViewModelTests: XCTestCase {

    // MARK: - Mocks

    class MockScanHistoryService: ScanHistoryService {
        @Published var testRecords: [ScanHistoryItem] = []
        override var records: [ScanHistoryItem] { testRecords }

        override func add(_ item: ScanHistoryItem) {
            testRecords.append(item)
        }
    }

    class MockAnalysisService: ImageAnalysisService {
        var wasCalled = false
        func analyze(image: UIImage) async -> AnalysisResult {
            wasCalled = true
            let dummyImage = UIImage(systemName: "photo")!
            let resultVM = RecognitionResultViewModel(
                image: dummyImage,
                productName: "Test",
                category: "Test",
                score: 9,
                safetyLabel: "Safe",
                safeBenefits: [],
                safetyConcerns: [],
                dataSources: [],
                date: Date()
            )
            let item = ScanHistoryItem(
                product: Product(id: UUID().uuidString, name: "Test", productType: "Test", safetyScore: 9, safetyLevel: "Safe", pros: [], cons: [], certifications: [], hygieneWarnings: []),
                labels: [],
                score: 9,
                thumbnail: dummyImage
            )
            return AnalysisResult(resultVM: resultVM, historyItem: item)
        }
    }

    // MARK: - Tests

    @MainActor func test_handleImage_setsPhaseToAnalyzing() {
        let vm = ScanViewModel(historyService: MockScanHistoryService())
        let image = UIImage(systemName: "photo")!

        vm.handleImage(image)

        if case let .analyzing(processedImage) = vm.phase {
            XCTAssertEqual(processedImage.pngData(), image.pngData())
        } else {
            XCTFail("Expected phase to be .analyzing")
        }
    }

    func test_completeAnalysis_updatesPhaseAndHistory() async {
        let historyService = await MockScanHistoryService()
        let analysisService = MockAnalysisService()
        let vm = ScanViewModel(historyService: historyService, analysisService: analysisService)

        let image = UIImage(systemName: "photo")!
        vm.handleImage(image)
        await vm.completeAnalysis()

        let count = await MainActor.run { historyService.testRecords.count }
        XCTAssertEqual(count, 1)
        if case .result = vm.phase {
            XCTAssertNotNil(vm.resultVM)
        } else {
            XCTFail("Expected phase to be .result")
        }
        XCTAssertTrue(analysisService.wasCalled)
    }
}
