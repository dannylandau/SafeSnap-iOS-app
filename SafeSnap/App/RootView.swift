//
//  RootView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import SwiftUI
import Clerk

struct RootView: View {
    @Environment(Clerk.self) var clerk
    let dependencies: AppDependencies

    var body: some View {
            if clerk.isLoaded {
                MainTabView(dependencies: dependencies)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}
