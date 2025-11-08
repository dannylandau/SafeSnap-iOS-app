//
//  OnboardingView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI
import UIKit

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @StateObject private var authViewModel = FirebaseAuthViewModel()

    let onFinished: () -> Void

    init(viewModel: OnboardingViewModel, onFinished: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onFinished()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                TabView(selection: $viewModel.currentPageIndex) {
                    ForEach(viewModel.pages.indices, id: \.self) { index in
                        let page = viewModel.pages[index]
                        IntroPageCardView(page: page) {
                            if let ctaTitle = page.ctaTitle {
                                GoogleSignInButton(
                                    title: ctaTitle,
                                    isLoading: authViewModel.isLoading,
                                    action: handleGoogleSignIn
                                )
                                .padding(.top, 12)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                PageDotsView(currentIndex: viewModel.currentPageIndex, total: viewModel.pages.count)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 32)
            }
        }
    }

    private func handleGoogleSignIn() {
        Task {
            let presenter = UIApplication.safesnapKeyWindow?.rootViewController?.topMostViewController
            let success = await authViewModel.signInWithGoogle(presenting: presenter)
            if success {
                await MainActor.run {
                    onFinished()
                }
            }
        }
    }
}

private struct PageDotsView: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: index == currentIndex ? 12 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
    }
}

//#if DEBUG
//#Preview {
//    OnboardingView {
//        // preview
//    }
//}
//#endif
