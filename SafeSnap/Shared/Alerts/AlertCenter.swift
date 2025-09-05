//
//  AlertCenter.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 05/09/2025.
//

import Foundation

@MainActor
public final class AlertCenter: ObservableObject {
    @Published public private(set) var current: AppAlert?
    private var queue: [AppAlert] = []
    private var lastShownAt: [String: Date] = [:]
    private let dedupeWindow: TimeInterval = 1.0

    public init() {}

    public func show(_ alert: AppAlert) {
        // De-dupe identical alerts within a short window
        let now = Date()
        if let last = lastShownAt[alert.fingerprint], now.timeIntervalSince(last) < dedupeWindow {
            return
        }
        lastShownAt[alert.fingerprint] = now

        // If nothing on screen, present immediately; else enqueue
        if current == nil {
            current = alert
        } else {
            queue.append(alert)
        }
    }

    public func dismiss() {
        current = nil
        // Present next after a small microtask to let SwiftUI finish transition
        Task { @MainActor in
            if !queue.isEmpty {
                current = queue.removeFirst()
            }
        }
    }

    public func clearAll() {
        queue.removeAll()
        current = nil
    }
}
