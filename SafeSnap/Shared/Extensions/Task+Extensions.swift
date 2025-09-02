extension Task where Success == Never, Failure == Never {
    static func timeout(_ duration: Duration) async throws {
        try await Task.sleep(nanoseconds: UInt64(duration.components.seconds) * 1_000_000_000)
    }
}

func withTimeout<T>(_ duration: Duration, _ work: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.timeout(duration)
            throw NSError(domain: "timeout", code: -1)
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}