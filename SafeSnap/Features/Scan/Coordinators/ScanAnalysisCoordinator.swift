//
//  ScanAnalysisCoordinator.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import Foundation
import SwiftUI

@MainActor
final class ScanAnalysisCoordinator: ObservableObject {
    @Published var currentPhase: ScanPhase = .preparing
    @Published var isComplete: Bool = false

    func start() async {
        for phase in ScanPhase.allCases {
            guard !Task.isCancelled else {
                print("⚠️ Task was cancelled — exiting coordinator early")
                return
            }

            currentPhase = phase
            do {
                try await perform(phase)
            } catch is CancellationError {
                print("⚠️ Caught cancellation at phase \(phase)")
                return
            } catch {
                print("❌ Error at phase \(phase): \(error)")
                break
            }
        }

        isComplete = true
    }

    func perform(_ phase: ScanPhase) async throws {
        switch phase {
        case .preparing:
            try await Task.sleep(nanoseconds: 500_000_000)
        case .vision:
            try await simulate("Connecting to Google Vision API")
        case .detecting:
            try await simulate("Detecting objects and labels")
        case .openAI:
            try await simulate("Running OpenAI Vision analysis")
        case .identify:
            try await simulate("Identifying specific product details")
        case .databases:
            try await simulate("Checking safety databases")
        case .openAISafety:
            try await simulate("Running OpenAI safety analysis")
        case .petSafety:
            try await simulate("Analyzing pet safety implications")
        case .report:
            try await simulate("Generating comprehensive safety report")
        }
    }

    private func simulate(_ label: String) async throws {
        print("🔄 \(label)...")
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
