import Combine
import FirebaseAuth
import Foundation
import UIKit

@MainActor
final class FirebaseAuthViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let auth: Auth
    private var authUIDelegate: FirebaseAuthUIDelegate?

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    func signInWithGoogle(presenting presenter: UIViewController?) async {
        guard let presenter else {
            errorMessage = "Unable to present Google Sign-In. Please try again."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false; authUIDelegate = nil }

        do {
            let provider = makeGoogleProvider()
            authUIDelegate = FirebaseAuthUIDelegate(presenting: presenter)
            let credential = try await fetchCredential(using: provider)
            _ = try await signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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

        var errorDescription: String? {
            switch self {
            case .unknown:
                return "An unknown error occurred while signing in with Google."
            case .missingDelegate:
                return "Unable to present Google Sign-In UI."
            }
        }
    }
}
