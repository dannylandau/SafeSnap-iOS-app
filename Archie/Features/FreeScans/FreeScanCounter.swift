import Foundation

/// Tracks how many free scans the current user has used. Stored on device, per user.
@MainActor
final class FreeScanCounter: ObservableObject {
    @Published private(set) var used: Int
    @Published private(set) var limit: Int

    private let defaults: UserDefaults
    private var userId: String

    init(defaults: UserDefaults = .standard, userId: String?, limit: Int = FreeScanPolicy.defaultLimit) {
        self.defaults = defaults
        self.userId = userId ?? Self.anonymousId
        self.limit = limit > 0 ? limit : FreeScanPolicy.defaultLimit
        self.used = defaults.integer(forKey: Self.key(for: userId ?? Self.anonymousId))
    }

    var remaining: Int { max(limit - used, 0) }
    var hasFreeScans: Bool { remaining > 0 }

    func recordScan() {
        used += 1
        defaults.set(used, forKey: Self.key(for: userId))
    }

    func setUser(_ id: String?) {
        userId = id ?? Self.anonymousId
        used = defaults.integer(forKey: Self.key(for: userId))
    }

    func setLimit(_ newLimit: Int?) {
        if let newLimit, newLimit > 0 {
            limit = newLimit
        } else {
            limit = FreeScanPolicy.defaultLimit
        }
    }

    private static let anonymousId = "anonymous"

    private static func key(for userId: String) -> String {
        "com.archie.freeScans.used.\(userId)"
    }
}
