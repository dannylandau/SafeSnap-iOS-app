import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import Foundation
import UIKit

@MainActor
final class FirebaseAuthViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let auth: Auth
    private var authUIDelegate: FirebaseAuthUIDelegate?
    private var appleSignInDelegate: AppleSignInDelegate?

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    // MARK: - Google Sign-In

    @discardableResult
    func signInWithGoogle(presenting presenter: UIViewController?) async -> Bool {
        guard let presenter else {
            errorMessage = "Unable to present Google Sign-In. Please try again."
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false; authUIDelegate = nil }

        do {
            let provider = makeGoogleProvider()
            authUIDelegate = FirebaseAuthUIDelegate(presenting: presenter)
            let credential = try await fetchCredential(using: provider)
            _ = try await signIn(with: credential)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Apple Sign-In

    @discardableResult
    func signInWithApple(presenting window: UIWindow?) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; appleSignInDelegate = nil }

        do {
            let nonce = AppleSignInNonce.randomNonceString()
            let hashedNonce = AppleSignInNonce.sha256(nonce)

            let appleCredential = try await performAppleAuthorization(
                hashedNonce: hashedNonce,
                window: window
            )

            guard let tokenData = appleCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw SignInError.missingAppleToken
            }

            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idToken,
                rawNonce: nonce
            )

            let result = try await signIn(with: credential)

            // Apple only provides the name on first sign-in; save it to Firebase profile
            if let fullName = appleCredential.fullName {
                let displayName = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
                if !displayName.isEmpty, result.user.displayName == nil {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                }
            }

            return true
        } catch let error as ASAuthorizationError where error.code == .canceled {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Private Helpers

    private func makeGoogleProvider() -> OAuthProvider {
        let provider = OAuthProvider(providerID: "google.com")
        provider.scopes = ["email", "profile"]
        provider.customParameters = ["prompt": "select_account"]
        return provider
    }

    private func fetchCredential(using provider: OAuthProvider) async throws -> AuthCredential {
        guard let delegate = authUIDelegate else {
            throw SignInError.missingDelegate
        }

        return try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialWith(delegate) { credential, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let credential {
                    continuation.resume(returning: credential)
                } else {
                    continuation.resume(throwing: SignInError.unknown)
                }
            }
        }
    }

    private func performAppleAuthorization(
        hashedNonce: String,
        window: UIWindow?
    ) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let delegate = AppleSignInDelegate(continuation: continuation, window: window)
            self.appleSignInDelegate = delegate

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

    private func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            auth.signIn(with: credential) { authResult, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let authResult {
                    continuation.resume(returning: authResult)
                } else {
                    continuation.resume(throwing: SignInError.unknown)
                }
            }
        }
    }

    private enum SignInError: LocalizedError {
        case unknown
        case missingDelegate
        case missingAppleToken

        var errorDescription: String? {
            switch self {
            case .unknown:
                return "An unknown error occurred while signing in."
            case .missingDelegate:
                return "Unable to present Sign-In UI."
            case .missingAppleToken:
                return "Unable to retrieve Apple ID credentials. Please try again."
            }
        }
    }
}

// MARK: - Apple Sign-In Delegate

private final class AppleSignInDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private weak var window: UIWindow?

    init(
        continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>,
        window: UIWindow?
    ) {
        self.continuation = continuation
        self.window = window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        window ?? UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: NSError(
                domain: "AppleSignIn",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential type"]
            ))
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
