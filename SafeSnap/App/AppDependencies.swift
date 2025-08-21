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
    let visionService: VisionService
    let openAIService: OpenAIService
    let userSession: UserSession
    private let clerk: Clerk

    init(clerk: Clerk) {
        self.clerk = clerk
        self.historyService = ScanHistoryService()
        self.historyService.load()
        self.userSession = ClerkUserSession(clerk: clerk)
        self.openAIService = OpenAIService(apiKey: Bundle.main.infoDictionaryValue(for: "OpenAIAPIKey")!) // TODO: Handle missing key gracefully
        self.visionService = VisionService(apiKey: Bundle.main.infoDictionaryValue(for: "GoogleVisionAPIKey")!) // TODO: Handle missing key gracefully
    }

    // Shared access point
    static var shared = AppDependencies(clerk: .shared)
}
