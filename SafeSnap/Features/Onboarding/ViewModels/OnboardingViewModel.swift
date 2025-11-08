//
//  OnboardingViewModel.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentPageIndex: Int = 0
    let pages: [IntroPage]

    init(pages: [IntroPage] = IntroPage.mockPages) {
        self.pages = pages
    }

    var isOnLastPage: Bool {
        guard let lastIndex = pages.indices.last else { return true }
        return currentPageIndex >= lastIndex
    }

    func advance() {
        guard !isOnLastPage else { return }
        currentPageIndex += 1
    }

    func go(to index: Int) {
        guard pages.indices.contains(index) else { return }
        currentPageIndex = index
    }
}
