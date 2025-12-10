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
    @State private var showHistory = false
    @State private var showAccount = false

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let coordinator = ScanAnalysisCoordinator(
            historyService: dependencies.historyService
        )
        _viewModel = StateObject(
            wrappedValue: ScanViewModel(coordinator: coordinator)
        )
    }

    var body: some View {
        NavigationStack {
            ScanView(
                viewModel: viewModel,
                userSession: dependencies.userSession,
                onShowHistory: { showHistory = true },
                onShowAccount: { showAccount = true }
            )
        }
        .sheet(isPresented: $showHistory) {
            HistoryTab(dependencies: dependencies)
        }
        .sheet(isPresented: $showAccount) {
            AccountTab(dependencies: dependencies)
        }
    }
}
