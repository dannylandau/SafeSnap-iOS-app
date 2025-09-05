//
//  AlertAction.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 05/09/2025.
//


import SwiftUI
import Combine

public struct AlertAction: Identifiable, Equatable {
    public enum Role: Equatable { case normal, cancel, destructive }
    public let id = UUID()
    public var title: String
    public var role: Role = .normal
    public var perform: () -> Void = {}

    public static func == (lhs: AlertAction, rhs: AlertAction) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.role == rhs.role
    }
}

public struct AppAlert: Identifiable, Equatable {
    public let id = UUID()
    public var title: String
    public var message: String?
    public var actions: [AlertAction] = [.init(title: "OK")]
    /// Used for de-duping identical alerts fired repeatedly
    public var fingerprint: String {
        [title, message ?? "", actions.map(\.title).joined(separator: "|")].joined(separator: "•")
    }
}

extension AppAlert {
    static func retryable(
        title: String,
        message: String? = nil,
        retry: @escaping () -> Void
    ) -> AppAlert {
        AppAlert(
            title: title,
            message: message,
            actions: [
                .init(title: "Retry", role: .normal, perform: retry),
                .init(title: "Cancel", role: .cancel)
            ]
        )
    }

    static func from(error: Error, retry: (() -> Void)? = nil) -> AppAlert {
        // Customize to your domain errors
        let message: String
        switch error {
        case let e as URLError where e.code == .notConnectedToInternet:
            message = "You appear to be offline. Check your connection and try again."
        case let e as DecodingError:
            message = decodingMessage(e)
        case let e as NSError where e.domain == NSURLErrorDomain && e.code == NSURLErrorTimedOut:
            message = "The request timed out. Please try again."
        default:
            message = error.localizedDescription
        }

        if let retry = retry {
            return .retryable(title: "Something went wrong", message: message, retry: retry)
        } else {
            return AppAlert(title: "Something went wrong", message: message)
        }
    }

    private static func decodingMessage(_ e: DecodingError) -> String {
        switch e {
        case .keyNotFound(let key, let ctx):
            return "Missing key '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(let type, let ctx):
            return "Type mismatch for \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let ctx):
            return "Value not found for \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let ctx):
            return "Data corrupted: \(ctx.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}
