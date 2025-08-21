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
            visionService: dependencies.visionService,
            openAIService: dependencies.openAIService,
            historyService: dependencies.historyService
        )
        _viewModel = StateObject(wrappedValue:
                                    ScanViewModel(coordinator:
                                                    coordinator))
    }

    var body: some View {
        NavigationStack {
            ScanView(viewModel: viewModel)
        }
    }
}
