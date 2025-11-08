//
//  AppDependencies.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import Foundation
import FirebaseAuth

@MainActor
final class AppDependencies {
    // Shared instances
    let geminiService: GeminiService
    let historyService: ScanHistoryService
    let visionService: VisionService
    let openAIService: OpenAIService
    let userSession: UserSession
    let onboardingState: OnboardingStateStore
    init(userSession: UserSession) {
        self.geminiService = GeminiService(apiKey: Bundle.main.infoDictionaryValue(for: "GoogleGeminiAPIKey")!)
        self.historyService = ScanHistoryService()
        self.historyService.load()
        self.userSession = userSession
        self.openAIService = OpenAIService(apiKey: Bundle.main.infoDictionaryValue(for: "OpenAIAPIKey")!) // TODO: Handle missing key gracefully
        self.visionService = VisionService(apiKey: Bundle.main.infoDictionaryValue(for: "GoogleVisionAPIKey")!) // TODO: Handle missing key gracefully
        self.onboardingState = OnboardingStateStore()
    }

    convenience init(auth: Auth = Auth.auth()) {
        self.init(userSession: FirebaseUserSession(auth: auth))
    }

    // Shared access point
    static var shared = AppDependencies()
}
