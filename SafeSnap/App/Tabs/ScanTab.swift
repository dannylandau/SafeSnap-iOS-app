//
//  ScanTab.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import SwiftUI

@MainActor
struct ScanTab: View {
    @StateObject private var viewModel: ScanViewModel

    init(dependencies: AppDependencies) {
        let coordinator = ScanAnalysisCoordinator(
            geminiService: dependencies.geminiService,
            historyService: dependencies.historyService
        )
        _viewModel = StateObject(
            wrappedValue: ScanViewModel(coordinator: coordinator, durationTracker: ScanDurationTracker())
        )
    }

    var body: some View {
        NavigationStack {
            ScanView(viewModel: viewModel)
        }
    }
}
