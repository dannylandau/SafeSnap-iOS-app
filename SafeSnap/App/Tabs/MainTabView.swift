//
//  MainTabView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

@MainActor
struct MainTabView: View {
    let dependencies: AppDependencies

    init(initialTab: MainTab = .scan, dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        ScanTab(dependencies: dependencies)
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
