import Foundation

/// Client decisions for the free-scan allowance. Each constant maps to a question
/// in docs/superpowers/specs/2026-11-02-free-scans-design.md.
enum FreeScanPolicy {
    enum CountTrigger {
        /// Scan counts only when analysis returns a result.
        case successfulResult
        /// Scan counts as soon as analysis starts.
        case scanStart
    }

    /// Decision 1: when a scan uses up a free scan.
    static let countTrigger: CountTrigger = .successfulResult

    /// Decision 2: whether History is locked once free scans run out. Account is never locked.
    static let gatesHistory = false

    /// Decision 3: whether the limit comes from RevenueCat offering metadata.
    static let usesRemoteLimit = true

    static let defaultLimit = 10
    static let remoteLimitMetadataKey = "free_scan_limit"

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://archieml.com/privacy")!
}
