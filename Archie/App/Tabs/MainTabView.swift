//
//  MainTabView.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

@MainActor
struct MainTabView: View {
    let dependencies: AppDependencies
    @ObservedObject private var premiumManager: PremiumManager

    init(initialTab: MainTab = .scan, dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._premiumManager = ObservedObject(wrappedValue: dependencies.premiumManager)
    }

    var body: some View {
        Group {
            if premiumManager.isLoading {
                ProgressView("Loading...")
            } else if premiumManager.isPremium {
                ScanTab(dependencies: dependencies)
            } else {
                RedeemCodeView(premiumManager: premiumManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await premiumManager.checkEntitlement() }
        }
    }
}

enum MainTab {
    case scan
}

// MARK: - Redeem Code View

private struct RedeemCodeView: View {
    @ObservedObject var premiumManager: PremiumManager
    @State private var isRestoring = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "ticket.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Welcome to Archie")
                .font(.title.bold())

            Text("Redeem your VIP invite code to unlock full access.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                premiumManager.redeemCode()
            } label: {
                Text("Redeem Code")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 32)

            Button {
                isRestoring = true
                Task {
                    _ = await premiumManager.restorePurchases()
                    isRestoring = false
                }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                        .font(.subheadline)
                }
            }
            .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#if DEBUG
#Preview {
    MainTabView(dependencies: AppDependencies(userSession: PreviewUserSession()))
}
#endif
