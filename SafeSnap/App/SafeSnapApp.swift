//
//  SafeScanApp.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 26/06/2025.
//

import SwiftUI
import Clerk

@main
struct SafeSnapApp: App {
    @State private var clerk = Clerk.shared
    @State private var dependencies: AppDependencies?

    var body: some Scene {
        WindowGroup {
            Group {
                if let deps = dependencies {
                    RootView(dependencies: deps)
                } else {
                    ProgressView()
                }
            }
            .environment(clerk)
            .task {
                await configureClerk()
            }
        }
    }

    @MainActor
    private func configureClerk() async {
        guard let apiKey = Bundle.main.infoDictionaryValue(for: "ClerkPublishableKey") else {
            fatalError("❌ ClerkPublishableKey not found in Info.plist")
        }

        clerk.configure(publishableKey: apiKey)

        do {
            try await clerk.load()
            dependencies = AppDependencies(clerk: clerk)
        } catch {
            print("❌ Clerk failed to load: \(error)")

            // Retry once if it's a rate limit (HTTP 429)
            if let urlError = error as? URLError, urlError.code == .badServerResponse {
                print("⏳ Retrying Clerk load after short delay...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                do {
                    try await clerk.load()
                    dependencies = AppDependencies(clerk: clerk)
                } catch {
                    print("🚫 Retry failed: \(error)")
                }
            }
        }
    }
}
