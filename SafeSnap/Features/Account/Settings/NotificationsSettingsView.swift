//
//  NotificationsSettingsView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

struct NotificationsSettingsView: View {
    @AppStorage("recallAlerts") var recallAlerts: Bool = true
    @AppStorage("appUpdates") var appUpdates: Bool = false
    @AppStorage("tipsAndRecs") var tipsAndRecs: Bool = false

    var body: some View {
        Form {
            Section() {
                Toggle(isOn: $recallAlerts) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Product recall alerts")
                            .font(.body)
                        Text("Get notified about product safety alerts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Section() {
                Toggle(isOn: $appUpdates) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App updates & features")
                            .font(.body)
                        Text("New features and improvements")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Section() {
                Toggle(isOn: $tipsAndRecs) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tips & recommendations")
                            .font(.body)
                        Text("Safety tips and product recommendations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
    }
}

#Preview {
    NavigationView {
        NotificationsSettingsView()
    }
}
