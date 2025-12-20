//
//  AppDependencies.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import Foundation
import FirebaseAuth

@MainActor
final class AppDependencies {
    
    // MARK: - Core Services
    
    let userSession: UserSession
    let onboardingState: OnboardingStateStore
    
    // MARK: - API Services (Backend-based)
    
    let apiService: ArchieAPIService
    let storageService: FirebaseStorageService
    let historyService: ScanHistoryService
    
    // MARK: - Init
    
    init(userSession: UserSession) {
        self.userSession = userSession
        self.onboardingState = OnboardingStateStore()
        
        // Configure API service with token provider
        self.apiService = ArchieAPIService(
            environment: .production,
            tokenProvider: { [weak userSession] in
                try await userSession?.getIdToken()
            }
        )
        
        // Storage service for image uploads
        self.storageService = FirebaseStorageService.shared
        
        // History service (will sync with backend when user is signed in)
        self.historyService = ScanHistoryService()
        self.historyService.load()
    }

    convenience init(auth: Auth = Auth.auth()) {
        self.init(userSession: FirebaseUserSession(auth: auth))
    }

    // MARK: - Shared Instance
    
    static var shared = AppDependencies()
}
