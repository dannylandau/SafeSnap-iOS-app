//
//  HistoryView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 21/07/2025.
//


import SwiftUI
import Clerk

@MainActor
struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    let userSession: UserSession
    @State private var isSignedIn: Bool

    init(dependencies: AppDependencies) {
        let session = dependencies.userSession
        self.userSession = session
        self._isSignedIn = State(initialValue: session.isSignedIn)
        _viewModel = StateObject(wrappedValue: HistoryViewModel(service: dependencies.historyService))
    }

    var body: some View {
        content
            .animation(.easeInOut(duration: 0.3), value: isSignedIn)
            .onReceive(userSession.isSignedInPublisher) { newValue in
                withAnimation {
                    isSignedIn = newValue
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isSignedIn {
            SignedInHistoryView()
                .environmentObject(viewModel)
        } else {
            SignUpOrSignInView()
        }
    }
}

#Preview {
    HistoryView(dependencies: AppDependencies(clerk: Clerk.shared))
}
