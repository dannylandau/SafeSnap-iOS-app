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
        _viewModel = StateObject(wrappedValue: ScanViewModel(
            historyService: dependencies.historyService,
            analysisService: dependencies.analysisService
        ))
    }

    var body: some View {
        NavigationStack {
            ScanView(viewModel: viewModel)
        }
    }
}
