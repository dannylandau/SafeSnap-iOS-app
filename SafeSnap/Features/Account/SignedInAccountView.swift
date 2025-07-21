//
//  SignedInAccountView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//

import SwiftUI
import Clerk

struct SignedInAccountView: View {
    @Environment(Clerk.self) private var clerk

    // App metadata
    private let appVersion = "v2.1.1"
    private let demoMode   = true

    // Stubbed stats (wire to real data later)
    private let stats = [
        ("Scans", "2"),
        ("Avg Score", "8.2"),
        ("Safe", "89%"),
        ("Days", "30")
    ]

    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationView {
            List {
                // MARK: API Status
                Section("API Status") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Google Vision API is connected and working properly")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: Demo Banner
                if demoMode {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Demo Account Active")
                                    .font(.headline)
                                Text("You’re using a demonstration account. All features are fully functional for testing purposes.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.green.opacity(0.1))
                }

                // MARK: Profile + Stats
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        if let urlStr = clerk.user?.imageUrl,
                           let url    = URL(string: urlStr) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.gray)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(clerk.user?.firstName ?? "") \(clerk.user?.lastName ?? "")")
                                .font(.title3.bold())
                            Text(clerk.user?.primaryEmailAddress?.emailAddress ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let date = clerk.user?.createdAt {
                                Text("Member since \(date.formatted(.dateTime.month().year()))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Stats Row
                    HStack {
                        ForEach(stats, id: \.0) { label, value in
                            VStack {
                                Text(value)
                                    .font(.headline)
                                Text(label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                }

                // MARK: Account Settings
                Section(header: Text("Account")) {
                    NavigationLink(destination: ProfileSettingsView()) {
                        Label("Profile", systemImage: "person")
                    }
                    NavigationLink(destination: NotificationsSettingsView()) {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                // MARK: Preferences
                Section(header: Text("Preferences")) {
                    Toggle(isOn: $isDarkMode) {
                        Label("Dark Mode", systemImage: "moon.fill")
                    }
                    NavigationLink(destination: LanguageSettingsView()) {
                        Label("Language", systemImage: "globe")
                    }
                }

                // MARK: Data & Privacy
                Section(header: Text("Data & Privacy")) {
                    NavigationLink(destination: PrivacySettingsView()) {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                    NavigationLink(destination: ExportDataView()) {
                        Label("Export Data", systemImage: "square.and.arrow.down")
                    }
                }

                // MARK: Support
                Section(header: Text("Support")){
                    NavigationLink(destination: HelpView()) {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    Button {
                        // share sheet
                    } label: {
                        Label("Share App", systemImage: "square.and.arrow.up")
                    }
                }

                // MARK: Sign Out
                Section {
                    Button(role: .destructive) {
                        Task { try? await clerk.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // MARK: Footer
                Section {
                    VStack(spacing: 4) {
                        Text("SafeSnap \(appVersion)")
                        Text("Powered by Google Vision AI")
                        if demoMode {
                            Text("Demo Version – All features functional")
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
        }
    }
}
