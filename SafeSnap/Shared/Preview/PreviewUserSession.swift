#if DEBUG
import Foundation

@MainActor
final class PreviewUserSession: UserSession {
    @Published var isSignedIn: Bool = true

    var email: String? = "preview@safesnap.app"
    var fullName: String? = "Preview User"
    var memberSince: String? = "July 2025"
    var avatarURL: URL? = URL(string: "https://example.com/avatar.png")
    var userId: String? = "preview-user-id"

    var isSignedInPublisher: Published<Bool>.Publisher { $isSignedIn }

    func signOut() async throws {
        isSignedIn = false
    }
}
#endif
