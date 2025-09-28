//
//  SafeScanApp.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 26/06/2025.
//

import SwiftUI
import FirebaseCore

@main
struct SafeSnapApp: App {
    init() {
        Self.configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: AppDependencies.shared)
        }
    }

    private static func configureFirebase() {
        guard FirebaseApp.app() == nil else { return }

        let bundle = Bundle.main
        let candidatePaths = [
            bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
            bundle.path(forResource: "GoogleService-Info", ofType: "plist", inDirectory: "Resources")
        ]

        if let plistPath = candidatePaths.compactMap({ $0 }).first,
           let options = FirebaseOptions(contentsOfFile: plistPath) {
            guard validate(options: options) else {
                fatalError("❌ GoogleService-Info.plist still contains placeholder values. Replace them with your Firebase project's configuration.")
            }

            FirebaseApp.configure(options: options)
        } else {
            fatalError("❌ GoogleService-Info.plist not found. Add your Firebase configuration file to the project.")
        }
    }

    private static func validate(options: FirebaseOptions) -> Bool {
        let placeholders: Set<String> = [
            "REPLACE_WITH_API_KEY",
            "REPLACE_WITH_PROJECT_ID",
            "REPLACE_WITH_IOS_GOOGLE_APP_ID",
            "REPLACE_WITH_SENDER_ID",
            "REPLACE_WITH_CLIENT_ID.apps.googleusercontent.com",
            "REPLACE_WITH_ANDROID_CLIENT_ID.apps.googleusercontent.com",
            "REPLACE_WITH_STORAGE_BUCKET.appspot.com",
            "https://REPLACE_WITH_PROJECT_ID.firebaseio.com"
        ]

        let valuesToCheck = [
            options.apiKey,
            options.projectID,
            options.googleAppID,
            options.gcmSenderID,
            options.storageBucket,
            options.databaseURL,
            options.clientID
        ].compactMap { $0 }

        return valuesToCheck.allSatisfy { !placeholders.contains($0) }
    }
}
