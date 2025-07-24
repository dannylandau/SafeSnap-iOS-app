//
//  ClerkUserSession.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import Clerk
import Foundation

@MainActor
final class ClerkUserSession: UserSession {
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var currentUser: User?
    
    private let clerk: Clerk
    private var pollTimer: Timer?

    init(clerk: Clerk) {
        self.clerk = clerk
        startPolling()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                let newUser = self.clerk.user

                if newUser?.id != self.currentUser?.id {
                    self.currentUser = newUser
                    self.isSignedIn = newUser != nil
                }
            }
        }
    }

    private func updateSignedInState() async {
        let newUser = clerk.user
        isSignedIn = newUser != nil
        currentUser = newUser
    }

    /// The current signed-in user's id, or nil if not signed in.
    var userId: String? {
        clerk.user?.id
    }

    /// The current signed-in user, or nil if not signed in.
    var user: User? {
        clerk.user
    }

    var email: String? {
        clerk.user?.primaryEmailAddress?.emailAddress
    }

    var fullName: String? {
        [clerk.user?.firstName, clerk.user?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var memberSince: String? {
        guard let date = clerk.user?.createdAt else { return nil }
        return date.formatted(.dateTime.month().year())
    }

    var avatarURL: URL? {
        guard let urlStr = clerk.user?.imageUrl else { return nil }
        return URL(string: urlStr)
    }

    func signOut() async throws {
        try await clerk.signOut()
    }

    var isSignedInPublisher: Published<Bool>.Publisher {
        $isSignedIn
    }
}
