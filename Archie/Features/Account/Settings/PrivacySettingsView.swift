//
//  PrivacySettingsView.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//


// PrivacySettingsView.swift
import SwiftUI

struct PrivacySettingsView: View {
    var body: some View {
        List {
            Section("Summary") {
                Text("Archie sends scan images to our servers to generate safety results. Scan history is stored on your device, and if you sign in we also sync history and scan images so they are available across devices.")
            }

            Section("Data We Collect") {
                PrivacyBulletList(items: [
                    "Account details when you sign in (name, email, user ID)",
                    "Scan images and derived safety results",
                    "Scan history entries (product name, scores, timestamps)"
                ])
            }

            Section("How We Use It") {
                PrivacyBulletList(items: [
                    "Analyze product safety and generate results",
                    "Sync history and images across devices when signed in",
                    "Show recent scans and improve app functionality"
                ])
            }

            Section("Where It Is Stored") {
                PrivacyBulletList(items: [
                    "On your device for local history and thumbnails",
                    "On our servers and Firebase Storage when signed in"
                ])
            }

            Section("Third-Party Services") {
                PrivacyBulletList(items: [
                    "Google Sign-In for authentication",
                    "Firebase Authentication and Firebase Storage for account and image sync"
                ])
            }

            Section("Your Choices") {
                PrivacyBulletList(items: [
                    "Use the app without signing in",
                    "Sign out to stop syncing",
                    "Delete the app to remove local data"
                ])
            }
        }
        .navigationTitle("Privacy")
    }
}

private struct PrivacyBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text("- \(item)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}
