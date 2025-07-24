//
//  UserSession.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import Foundation

@MainActor
protocol UserSession: AnyObject {
    var email: String? { get }
    var fullName: String? { get }
    var memberSince: String? { get }
    var avatarURL: URL? { get }
    var userId: String? { get }
    var isSignedIn: Bool { get }
    var isSignedInPublisher: Published<Bool>.Publisher { get }
    func signOut() async throws
}
