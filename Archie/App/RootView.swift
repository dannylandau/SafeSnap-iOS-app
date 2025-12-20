//
//  RootView.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies
    @ObservedObject private var onboardingState: OnboardingStateStore
    @State private var isSignedIn: Bool

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._onboardingState = ObservedObject(wrappedValue: dependencies.onboardingState)
        self._isSignedIn = State(initialValue: dependencies.userSession.isSignedIn)
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(viewModel: OnboardingViewModel()) {
                    onboardingState.markCompleted()
                }
            } else {
                MainTabView(dependencies: dependencies)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowOnboarding)
        .onReceive(dependencies.userSession.isSignedInPublisher) { newValue in
            isSignedIn = newValue
        }
    }

    private var shouldShowOnboarding: Bool {
        !onboardingState.hasCompletedOnboarding && !isSignedIn
    }
}
