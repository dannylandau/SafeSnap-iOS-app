//
//  AccountView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//

import SwiftUI
import Clerk

@MainActor
struct AccountView: View {
    @StateObject private var viewModel: AccountViewModel
    
    let userSession: UserSession
    @State private var isSignedIn: Bool

    init(dependencies: AppDependencies) {
        let session = dependencies.userSession
        self.userSession = session
        self._isSignedIn = State(initialValue: session.isSignedIn)
        _viewModel = StateObject(wrappedValue: AccountViewModel(
            userSession: session,
            historyService: dependencies.historyService
        ))
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
    var content: some View {
        if isSignedIn {
            SignedInAccountView(viewModel: viewModel)
        } else {
            SignUpOrSignInView()
        }
    }
}

#Preview {
    AccountView(dependencies: AppDependencies(clerk: Clerk.shared))
}
