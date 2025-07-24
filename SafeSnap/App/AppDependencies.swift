//
//  AppDependencies.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import Foundation
import Clerk

@MainActor
final class AppDependencies {
    // Shared instances
    let historyService: ScanHistoryService
    let analysisService: ImageAnalysisService
    let userSession: UserSession
    private let clerk: Clerk

    init(clerk: Clerk) {
        self.clerk = clerk
        self.historyService = ScanHistoryService()
        self.analysisService = MockImageAnalysisService()
        self.userSession = ClerkUserSession(clerk: clerk)
    }

    // Shared access point
    static var shared = AppDependencies(clerk: .shared)
}
