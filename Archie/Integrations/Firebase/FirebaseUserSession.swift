import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import UIKit

@MainActor
final class FirebaseUserSession: UserSession {
    @Published private(set) var isSignedIn: Bool

    private let auth: Auth
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cachedUser: User?

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
        let currentUser = auth.currentUser
        self.cachedUser = currentUser
        self.isSignedIn = currentUser != nil

        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.cachedUser = user
                self.isSignedIn = user != nil
            }
        }
    }

    deinit {
        if let authStateListener {
            auth.removeStateDidChangeListener(authStateListener)
        }
    }

    private var currentUser: User? {
        auth.currentUser ?? cachedUser
    }

    var email: String? {
        currentUser?.email
    }

    var fullName: String? {
        currentUser?.displayName
    }

    var memberSince: String? {
        guard let date = currentUser?.metadata.creationDate else { return nil }
        return date.formatted(.dateTime.month().year())
    }

    var avatarURL: URL? {
        currentUser?.photoURL
    }

    var userId: String? {
        currentUser?.uid
    }

    var isSignedInPublisher: Published<Bool>.Publisher { $isSignedIn }

    func getIdToken() async throws -> String? {
        guard let user = currentUser else { return nil }
        return try await user.getIDToken()
    }

    func signOut() async throws {
        try auth.signOut()
    }

    func deleteAccount() async throws {
        guard let user = currentUser else { return }
        do {
            try await user.delete()
        } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            try await reauthenticateAndDelete(user: user)
        }
    }

    // MARK: - Re-authentication

    private var appleSignInDelegate: ReauthAppleDelegate?

    private func reauthenticateAndDelete(user: User) async throws {
        let providerID = user.providerData.first?.providerID ?? ""

        switch providerID {
        case "apple.com":
            try await reauthenticateWithApple(user: user)
        case "google.com":
            try await reauthenticateWithGoogle(user: user)
        default:
            throw AccountDeletionError.unsupportedProvider
        }

        try await user.delete()
    }

    private func reauthenticateWithApple(user: User) async throws {
        let nonce = AppleSignInNonce.randomNonceString()
        let hashedNonce = AppleSignInNonce.sha256(nonce)

        let appleCredential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email]
            request.nonce = hashedNonce

            let window = UIApplication.safesnapKeyWindow
            let delegate = ReauthAppleDelegate(continuation: continuation, window: window)
            self.appleSignInDelegate = delegate

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
        appleSignInDelegate = nil

        guard let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AccountDeletionError.missingToken
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idToken,
            rawNonce: nonce
        )
        try await user.reauthenticate(with: credential)
    }

    private func reauthenticateWithGoogle(user: User) async throws {
        let provider = OAuthProvider(providerID: "google.com")
        provider.scopes = ["email", "profile"]

        guard let window = UIApplication.safesnapKeyWindow,
              let presenter = window.rootViewController?.topMostViewController else {
            throw AccountDeletionError.missingPresenter
        }

        let uiDelegate = FirebaseAuthUIDelegate(presenting: presenter)

        let credential: AuthCredential = try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialWith(uiDelegate) { credential, error in
                if let error { continuation.resume(throwing: error); return }
                if let credential { continuation.resume(returning: credential) }
                else { continuation.resume(throwing: AccountDeletionError.missingToken) }
            }
        }
        try await user.reauthenticate(with: credential)
    }
}

enum AccountDeletionError: LocalizedError {
    case unsupportedProvider
    case missingToken
    case missingPresenter

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            return "Unable to verify your identity. Please sign out, sign back in, and try again."
        case .missingToken:
            return "Unable to retrieve authentication credentials. Please try again."
        case .missingPresenter:
            return "Unable to present sign-in UI. Please try again."
        }
    }
}

private final class ReauthAppleDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private weak var window: UIWindow?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>, window: UIWindow?) {
        self.continuation = continuation
        self.window = window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        window ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AccountDeletionError.missingToken)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
