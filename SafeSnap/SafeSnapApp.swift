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
    // 1️⃣ Hold your Clerk singleton in @State
    @State private var clerk = Clerk.shared
    @StateObject private var historyVM = HistoryViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if clerk.isLoaded {
                    MainTabView().environmentObject(historyVM)      // ← your TabView root
                } else {
                    ProgressView()     // ← while Clerk spins up
                }
            }
            // 2️⃣ Inject Clerk into SwiftUI’s environment
            .environment(clerk)
            // 3️⃣ Configure & load Clerk in a .task
            .task {
                guard let apiKey = Bundle.main.infoDictionaryValue(for: "ClerkPublishableKey") else {
                    fatalError("ClerkPublishableKey not found in Info.plist")
                }
                clerk.configure(publishableKey: apiKey)
                try? await clerk.load()
            }
        }
    }
}
