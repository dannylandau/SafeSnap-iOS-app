import Foundation
import SwiftUI
import Combine

@MainActor
final class AccountViewModel: ObservableObject {
    // MARK: - Public @Published Properties
    @Published private(set) var stats: [Stat] = []
    @Published var isSignedIn: Bool = false

    // MARK: - Constants
    let appVersion = "v2.1.1"
    let demoMode = true

    // MARK: - Dependencies
    private let userSession: UserSession
    private let historyService: ScanHistoryService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(userSession: UserSession, historyService: ScanHistoryService) {
        self.userSession = userSession
        self.historyService = historyService
        bind()
        isSignedIn = userSession.isSignedIn
    }

    // MARK: - Binding

    private func bind() {
        historyService.$records
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStats(with: $0) }
            .store(in: &cancellables)
    }

    private func refreshAuth() {
        isSignedIn = userSession.isSignedIn
    }

    // MARK: - Stats
    
    struct Stat: Identifiable {
        let id = UUID()
        let label: String
        let value: String

        static let placeholder: [Stat] = [
            Stat(label: "Scans", value: "0"),
            Stat(label: "Avg Score", value: "–"),
            Stat(label: "Safe", value: "–"),
            Stat(label: "Days", value: "–")
        ]
    }

    private func updateStats(with records: [ScanHistoryItem]) {
        guard !records.isEmpty else {
            stats = Stat.placeholder
            return
        }

        let scanCount = records.count
        let avgScore = Double(records.map(\.score).reduce(0, +)) / Double(scanCount)
        let safePercent = Double(records.filter { $0.score >= 7 }.count) / Double(scanCount) * 100

        stats = [
            Stat(label: "Scans", value: "\(scanCount)"),
            Stat(label: "Avg Score", value: String(format: "%.1f", avgScore)),
            Stat(label: "Safe", value: String(format: "%.0f%%", safePercent)),
            Stat(label: "Days", value: "\(uniqueDays(records))")
        ]
    }

    private func uniqueDays(_ records: [ScanHistoryItem]) -> Int {
        let days = Set(records.map { Calendar.current.startOfDay(for: $0.date) })
        return days.count
    }

    // MARK: - Profile Info

    var fullName: String {
        userSession.fullName ?? "Empty User"
    }

    var email: String {
        userSession.email ?? "Empty Email"
    }

    var memberSince: String? {
        userSession.memberSince
    }

    var avatarURL: URL? {
        userSession.avatarURL ?? URL(string: "https://example.com/default-avatar.png")
    }

    func signOut() async {
        try? await userSession.signOut()
        refreshAuth()
    }
}
