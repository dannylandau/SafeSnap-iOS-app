//
//  MockUserSession.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 24/07/2025.
//


import Foundation
@testable import Archie

final class MockUserSession: UserSession, ObservableObject {
    @Published var isSignedIn: Bool = true
    var isSignedInPublisher: Published<Bool>.Publisher { $isSignedIn }
    var email: String? = "jane@example.com"
    var fullName: String? = "Jane Doe"
    var memberSince: String? = "Feb 1974"
    var avatarURL: URL? = nil
    var userId: String? = "test-id"
    var mockIdToken: String? = "mock-test-token"
    
    func getIdToken() async throws -> String? {
        return isSignedIn ? mockIdToken : nil
    }
    
    func signOut() async throws {}
}
