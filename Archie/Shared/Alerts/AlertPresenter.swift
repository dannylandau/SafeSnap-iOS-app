//
//  AlertPresenter.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 05/09/2025.
//

import SwiftUI

struct AlertPresenter: ViewModifier {
    @ObservedObject var center: AlertCenter
    @State private var showDetails = false
    @State private var detailsText = ""
    @State private var showCopyToast = false

    func body(content: Content) -> some View {
        let messageText: String = {
            if let error = center.current?.error {
                // Prefer rich LocalizedError presentation if available
                if let le = error as? LocalizedError {
                    var parts: [String] = []
                    if let description = le.errorDescription, !description.isEmpty { parts.append(description) }
                    if let r = le.failureReason, !r.isEmpty { parts.append("Reason: \(r)") }
                    if let s = le.recoverySuggestion, !s.isEmpty { parts.append("What to try: \(s)") }
                    if !parts.isEmpty { return parts.joined(separator: "\n\n") }
                }
                return error.localizedDescription
            }
            return center.current?.message ?? ""
        }()
        return content.alert(
            center.current?.title ?? "",
            isPresented: Binding(
                get: { center.current != nil },
                set: { isPresented in
                    if !isPresented { center.dismiss() }
                }
            ),
            actions: {
                let actions = (center.current?.actions).nonEmpty ?? [AlertAction(title: "OK")]
                if let error = center.current?.error {
                    Button("Details…") {
                        let ns = error as NSError
                        self.detailsText = buildDebugDetails(for: error, composedMessage: messageText, nsError: ns)
                        self.showDetails = true
                    }
                }
                ForEach(actions) { action in
                    switch action.role {
                    case .normal:
                        Button(action.title) {
                            action.perform()
                            center.dismiss()
                        }
                    case .cancel:
                        Button(action.title, role: .cancel) {
                            action.perform()
                            center.dismiss()
                        }
                    case .destructive:
                        Button(action.title, role: .destructive) {
                            action.perform()
                            center.dismiss()
                        }
                    }
                }
            },
            message: {
                if !messageText.isEmpty {
                    Text(messageText)
                }
            }
        )
        .sheet(isPresented: $showDetails) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Error Details").font(.title3).bold()
                ScrollView { Text(detailsText).font(.footnote).textSelection(.enabled) }
                HStack {
                    Button("Copy") {
                        UIPasteboard.general.string = detailsText
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        withAnimation { showCopyToast = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_200_000_000) // ~1.2s
                            await MainActor.run { withAnimation { showCopyToast = false } }
                        }
                    }
                    Spacer()
                    Button("Close") { showDetails = false }
                }
            }
            .padding()
            .overlay(
                Group {
                    if showCopyToast {
                        Text("Copied to clipboard")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                    }
                }, alignment: .bottom
            )
        }
    }
    
    /// Compose a rich debug report for the provided error, including LocalizedError fields,
    /// NSError metadata, HTTP hints, and recursively traversing underlying errors.
    private func buildDebugDetails(for error: Error, composedMessage: String, nsError: NSError) -> String {
        var lines: [String] = []

        // Top-level summary
        lines.append("Description: \(composedMessage)")
        lines.append("Type: \(String(reflecting: type(of: error)))")

        // LocalizedError fields
        if let le = error as? LocalizedError {
            if let d = le.errorDescription, !d.isEmpty { lines.append("errorDescription: \(d)") }
            if let r = le.failureReason, !r.isEmpty { lines.append("failureReason: \(r)") }
            if let s = le.recoverySuggestion, !s.isEmpty { lines.append("recoverySuggestion: \(s)") }
            if let h = le.helpAnchor, !h.isEmpty { lines.append("helpAnchor: \(h)") }
        }

        // AnalyzerError specifics (stage, status, etc.) if available
//        if let ae = error as? AnalyzerError {
//            switch ae {
//            case .recognitionFailed(let reason):
//                lines.append("AnalyzerError: recognitionFailed(reason=\(reason))")
//            case .timedOut(let stage, let seconds):
//                lines.append("AnalyzerError: timedOut(stage=\(stage.rawValue), seconds=\(seconds))")
//            case .cancelled(let stage):
//                lines.append("AnalyzerError: cancelled(stage=\(stage.rawValue))")
//            case .network(let stage, let underlying):
//                lines.append("AnalyzerError: network(stage=\(stage.rawValue))")
//                lines.append(contentsOf: formatUnderlyingHeader())
//                lines.append(contentsOf: dumpErrorChain(underlying))
//            case .rateLimited(let stage, let retryAfter, let underlying):
//                lines.append("AnalyzerError: rateLimited(stage=\(stage.rawValue), retryAfter=\(retryAfter.map(String.init) ?? "nil"))")
//                lines.append(contentsOf: formatUnderlyingHeader())
//                lines.append(contentsOf: dumpErrorChain(underlying))
//            case .server(let stage, let status, let underlying):
//                lines.append("AnalyzerError: server(stage=\(stage.rawValue), status=\(status))")
//                lines.append(contentsOf: formatUnderlyingHeader())
//                lines.append(contentsOf: dumpErrorChain(underlying))
//            case .invalidModelResponse(let stage, let reason):
//                lines.append("AnalyzerError: invalidModelResponse(stage=\(stage.rawValue), reason=\(reason))")
//            case .other(let stage, let underlying):
//                lines.append("AnalyzerError: other(stage=\(stage.rawValue))")
//                lines.append(contentsOf: formatUnderlyingHeader())
//                lines.append(contentsOf: dumpErrorChain(underlying))
//            }
//        }

        // NSError basics
        lines.append("Domain: \(nsError.domain)")
        lines.append("Code: \(nsError.code)")

        // HTTP hints
        if let status = nsError.userInfo["HTTPStatusCode"] as? Int {
            lines.append("HTTPStatusCode: \(status)")
        }
        if let retry = nsError.userInfo["RetryAfter"] { lines.append("Retry-After: \(retry)") }
        if let requestID = nsError.userInfo["RequestID"] { lines.append("Request-ID: \(requestID)") }

        // URL-related NSError keys (if present)
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] { lines.append("FailingURL: \(failingURL)") }
        if let failingURLString = nsError.userInfo[NSURLErrorFailingURLErrorKey] { lines.append("FailingURLString: \(failingURLString)") }

        // Debug description style keys
        if let dbg = nsError.userInfo[NSDebugDescriptionErrorKey] { lines.append("DebugDescription: \(dbg)") }
        if let locFail = nsError.userInfo[NSLocalizedFailureReasonErrorKey] { lines.append("NSLocalizedFailureReason: \(locFail)") }
        if let locRec = nsError.userInfo[NSLocalizedRecoverySuggestionErrorKey] { lines.append("NSLocalizedRecoverySuggestion: \(locRec)") }

        // Whole userInfo
        if !nsError.userInfo.isEmpty {
            lines.append("userInfo: \(nsError.userInfo)")
        }

        // Underlying chain (from NSError)
        if let underlyingAny = nsError.userInfo[NSUnderlyingErrorKey] {
            lines.append(contentsOf: formatUnderlyingHeader())
            if let undErr = underlyingAny as? Error {
                lines.append(contentsOf: dumpErrorChain(undErr))
            } else {
                lines.append("Underlying(raw): \(underlyingAny)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatUnderlyingHeader() -> [String] { ["", "— Underlying —"] }

    /// Dump an error and recursively follow common underlying links
    private func dumpErrorChain(_ error: Error, level: Int = 0, maxDepth: Int = 6) -> [String] {
        guard level < maxDepth else { return [indent(level) + "(max depth reached)"] }
        var out: [String] = []
        let prefix = indent(level)
        let ns = error as NSError
        out.append(prefix + "Type: \(String(reflecting: type(of: error)))")
        out.append(prefix + "Desc: \(error.localizedDescription)")
        out.append(prefix + "Domain: \(ns.domain) Code: \(ns.code)")

        if let le = error as? LocalizedError {
            if let r = le.failureReason, !r.isEmpty { out.append(prefix + "failureReason: \(r)") }
            if let s = le.recoverySuggestion, !s.isEmpty { out.append(prefix + "recoverySuggestion: \(s)") }
        }

        // Recurse into AnalyzerError-assigned underlying where possible
//        if let ae = error as? SafetyAnalyzer.AnalyzerError {
//            switch ae {
//            case .network(_, let underlying),
//                 .rateLimited(_, _, let underlying),
//                 .server(_, _, let underlying),
//                 .other(_, let underlying):
//                out.append(prefix + "→ underlying:")
//                out.append(contentsOf: dumpErrorChain(underlying, level: level + 1, maxDepth: maxDepth))
//            default: break
//            }
//        }

        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            out.append(prefix + "→ underlying(NSUnderlyingErrorKey):")
            out.append(contentsOf: dumpErrorChain(underlying, level: level + 1, maxDepth: maxDepth))
        }

        return out
    }

    private func indent(_ n: Int) -> String { String(repeating: "  ", count: n) }
}

extension View {
    func alerts(using center: AlertCenter) -> some View {
        modifier(AlertPresenter(center: center))
    }
}

// Small convenience so we can do `.nonEmpty ?? [...]`
private extension Optional where Wrapped: Collection {
    var nonEmpty: Wrapped? { self?.isEmpty == false ? self : nil }
}
