//
//  ScanTab.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import SwiftUI

@MainActor
struct ScanTab: View {
    @StateObject private var viewModel: ScanViewModel
    @ObservedObject private var premiumManager: PremiumManager
    @State private var showHistory = false
    @State private var showAccount = false
    @State private var showRedeemCode = false
    @State private var pendingAction: PendingAction?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._premiumManager = ObservedObject(wrappedValue: dependencies.premiumManager)
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
                onCaptureGate: {
                    guard premiumManager.isPremium else {
                        pendingAction = .camera
                        showRedeemCode = true
                        return false
                    }
                    return true
                },
                onGalleryGate: {
                    guard premiumManager.isPremium else {
                        pendingAction = .gallery
                        showRedeemCode = true
                        return false
                    }
                    return true
                },
                onShowHistory: {
                    gatedAction(.history) { showHistory = true }
                },
                onShowAccount: {
                    gatedAction(.account) { showAccount = true }
                }
            )
        }
        .sheet(isPresented: $showHistory) {
            HistoryTab(dependencies: dependencies)
        }
        .sheet(isPresented: $showAccount) {
            AccountTab(dependencies: dependencies)
        }
        .sheet(isPresented: $showRedeemCode, onDismiss: handleRedeemDismiss) {
            RedeemCodeView(
                premiumManager: premiumManager,
                onDismiss: { showRedeemCode = false }
            )
        }
    }

    private func gatedAction(_ action: PendingAction, perform: @escaping () -> Void) {
        if premiumManager.isPremium {
            perform()
        } else {
            pendingAction = action
            showRedeemCode = true
        }
    }

    private func handleRedeemDismiss() {
        guard premiumManager.isPremium, let action = pendingAction else {
            pendingAction = nil
            return
        }
        pendingAction = nil
        switch action {
        case .history: showHistory = true
        case .account: showAccount = true
        case .camera, .gallery: break
        }
    }

    private enum PendingAction {
        case history, account, camera, gallery
    }
}
