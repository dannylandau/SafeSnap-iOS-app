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
            } else {
                ScanTab(dependencies: dependencies)
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

#if DEBUG
#Preview {
    MainTabView(dependencies: AppDependencies(userSession: PreviewUserSession()))
}
#endif
