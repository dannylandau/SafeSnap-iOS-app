//
//  ScanDurationTracker.swift
//  Archie
//
//  Created by Coding Assistant on 2025-08-08.
//

import Foundation

@MainActor
protocol ScanDurationTracking: AnyObject {
    var elapsed: Duration? { get }
    func start()
    func stop() -> Duration?
    func reset()
}

@MainActor
final class ScanDurationTracker: ObservableObject, ScanDurationTracking {
    @Published private(set) var elapsed: Duration? = nil

    private let clock: ContinuousClock
    private var startInstant: ContinuousClock.Instant?

    init(clock: ContinuousClock) {
        self.clock = clock
    }

    func start() {
        startInstant = clock.now
        elapsed = nil
    }

    @discardableResult
    func stop() -> Duration? {
        guard let instant = startInstant else { return elapsed }
        let duration = instant.duration(to: .now)
        elapsed = duration
        startInstant = nil
        return duration
    }

    func reset() {
        startInstant = nil
        elapsed = nil
    }
}

protocol ScanDurationFormatting {
    func string(from duration: Duration) -> String
}

struct ScanDurationFormatter: ScanDurationFormatting {
    func string(from duration: Duration) -> String {
        let seconds = duration.timeInterval
        let rounded = (seconds * 10).rounded() / 10
        return String(format: "%.1f s", rounded)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        let attosecondsPerSecond = 1_000_000_000_000_000_000.0
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / attosecondsPerSecond
    }
}
