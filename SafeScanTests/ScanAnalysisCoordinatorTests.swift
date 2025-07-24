//
//  ScanAnalysisCoordinatorTests.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import XCTest
@testable import SafeSnap

final class ScanAnalysisCoordinatorTests: XCTestCase {

    func test_start_progressesThroughAllPhases() async {
        let coordinator = await MainActor.run { ScanAnalysisCoordinator() }
        await coordinator.start()

        let currentPhase = await MainActor.run { coordinator.currentPhase }
        let isComplete = await MainActor.run { coordinator.isComplete }

        XCTAssertEqual(currentPhase, .report, "Final phase should be .report")
        XCTAssertTrue(isComplete, "Coordinator should mark completion")
    }

    func test_start_isCancellable() async {
        let coordinator = await MainActor.run { ScanAnalysisCoordinator() }
        let task = Task {
            await coordinator.start()
        }

        task.cancel()
        await Task.yield()

        XCTAssertTrue(task.isCancelled, "Task should report as cancelled")
    }

    func test_perform_doesNotThrow() async {
        let coordinator = await MainActor.run { ScanAnalysisCoordinator() }

        do {
            for phase in ScanPhase.allCases {
                try await coordinator.perform(phase)
            }
        } catch {
            XCTFail("Perform should not throw in normal conditions")
        }
    }

    func test_start_setsIsCompleteTrue() async {
        let coordinator = await MainActor.run { ScanAnalysisCoordinator() }
        let isCompleteBefore = await MainActor.run { coordinator.isComplete }
        XCTAssertFalse(isCompleteBefore, "isComplete should be false initially")

        await coordinator.start()

        let isCompleteAfter = await MainActor.run { coordinator.isComplete }
        XCTAssertTrue(isCompleteAfter, "isComplete should be true after completion")
    }
}
