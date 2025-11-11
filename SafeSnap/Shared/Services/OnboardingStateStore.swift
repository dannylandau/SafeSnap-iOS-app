//
//  OnboardingStateStore.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import Foundation

@MainActor
final class OnboardingStateStore: ObservableObject {
    @Published private(set) var hasCompletedOnboarding: Bool

    private let defaults: UserDefaults
    private let key = "hasCompletedOnboarding"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: key)
    }

    func markCompleted() {
        updateCompletionState(true)
    }

    func reset() {
        updateCompletionState(false)
    }

    private func updateCompletionState(_ newValue: Bool) {
        guard hasCompletedOnboarding != newValue else { return }
        hasCompletedOnboarding = newValue
        defaults.set(newValue, forKey: key)
    }
}
