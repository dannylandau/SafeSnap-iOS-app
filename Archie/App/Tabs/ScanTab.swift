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
    @ObservedObject private var freeScans: FreeScanCounter
    @State private var showHistory = false
    @State private var showAccount = false
    @State private var showPaywall = false
    @State private var pendingAction: PendingAction?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._premiumManager = ObservedObject(wrappedValue: dependencies.premiumManager)
        self._freeScans = ObservedObject(wrappedValue: dependencies.freeScanCounter)
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
                onCaptureGate: { scanGate(.camera) },
                onGalleryGate: { scanGate(.gallery) },
                freeScanStatus: freeScanStatus,
                onShowHistory: {
                    if FreeScanPolicy.gatesHistory, !canScan {
                        pendingAction = .history
                        showPaywall = true
                    } else {
                        showHistory = true
                    }
                },
                onShowAccount: { showAccount = true }
            )
        }
        .sheet(isPresented: $showHistory) {
            HistoryTab(dependencies: dependencies)
        }
        .sheet(isPresented: $showAccount) {
            AccountTab(dependencies: dependencies)
        }
        .sheet(isPresented: $showPaywall, onDismiss: handlePaywallDismiss) {
            PaywallView(
                premiumManager: premiumManager,
                freeScanLimit: freeScans.limit,
                onDismiss: { showPaywall = false }
            )
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            recordScanIfNeeded(for: newPhase)
        }
        .onChange(of: premiumManager.freeScanLimit, initial: true) { _, newLimit in
            guard FreeScanPolicy.usesRemoteLimit else { return }
            freeScans.setLimit(newLimit)
        }
    }

    private var canScan: Bool {
        premiumManager.isPremium || freeScans.hasFreeScans
    }

    private var freeScanStatus: String? {
        guard !premiumManager.isPremium else { return nil }
        guard freeScans.hasFreeScans else { return "No free scans left" }
        return "\(freeScans.remaining) of \(freeScans.limit) free scans left"
    }

    private func scanGate(_ action: PendingAction) -> Bool {
        guard canScan else {
            pendingAction = action
            showPaywall = true
            return false
        }
        return true
    }

    private func recordScanIfNeeded(for phase: ScanPhase) {
        guard !premiumManager.isPremium else { return }
        switch (FreeScanPolicy.countTrigger, phase) {
        case (.successfulResult, .result), (.scanStart, .analyzing):
            freeScans.recordScan()
        default:
            break
        }
    }

    private func handlePaywallDismiss() {
        guard premiumManager.isPremium, let action = pendingAction else {
            pendingAction = nil
            return
        }
        pendingAction = nil
        switch action {
        case .history: showHistory = true
        case .camera, .gallery: break
        }
    }

    private enum PendingAction {
        case history, camera, gallery
    }
}
