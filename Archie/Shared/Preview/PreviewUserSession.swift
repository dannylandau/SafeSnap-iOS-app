#if DEBUG
import Foundation

@MainActor
final class PreviewUserSession: UserSession {
    @Published var isSignedIn: Bool = true

    var email: String? = "preview@archieml.com"
    var fullName: String? = "Preview User"
    var memberSince: String? = "July 2025"
    var avatarURL: URL? = URL(string: "https://example.com/avatar.png")
    var userId: String? = "preview-user-id"

    var isSignedInPublisher: Published<Bool>.Publisher { $isSignedIn }

    func getIdToken() async throws -> String? {
        return isSignedIn ? "preview-mock-token" : nil
    }

    func signOut() async throws {
        isSignedIn = false
    }
}
#endif
