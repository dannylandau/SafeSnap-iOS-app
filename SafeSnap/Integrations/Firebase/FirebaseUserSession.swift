import FirebaseAuth
import Foundation

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

    func signOut() async throws {
        try auth.signOut()
    }
}
