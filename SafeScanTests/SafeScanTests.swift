//
//  SafeScanTests.swift
//  SafeScanTests
//
//  Created by Marcin Grześkowiak on 26/06/2025.
//

import XCTest
@testable import SafeSnap
import SwiftUI

final class SafeSnapEndToEndTests: XCTestCase {

    func test_fullScanFlow_addsResultToHistory() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let historyService = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        let analysisService = MockImageAnalysisService()
        let scanVM = ScanViewModel(historyService: historyService, analysisService: analysisService)

        let dummyImage = UIImage(systemName: "photo")!
        scanVM.handleImage(dummyImage)
        await scanVM.completeAnalysis()

        let recordCount = await MainActor.run { historyService.records.count }
        XCTAssertEqual(recordCount, 1)
    }

    func test_scanAppearsInAccountStats() async {
        // Arrange
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let historyService = await MainActor.run { ScanHistoryService(fileURL: fileURL) }
        let analysisService = MockImageAnalysisService()
        let scanVM = ScanViewModel(historyService: historyService, analysisService: analysisService)
        let userSession = await MockUserSession()
        let accountVM = await MainActor.run { AccountViewModel(userSession: userSession, historyService: historyService) }

        // Act
        let dummyImage = UIImage(systemName: "photo")!
        scanVM.handleImage(dummyImage)
        await scanVM.completeAnalysis()

        // Give Combine some time to publish the changes (or force refresh if needed)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Assert
        let stats = await MainActor.run { accountVM.stats }
        XCTAssertTrue(stats.contains(where: { $0.label == "Scans" && $0.value == "1" }))
    }
}
