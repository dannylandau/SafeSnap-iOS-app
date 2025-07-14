//
//  HelpView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            // FAQ Section with custom styling
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Common Questions")
                        .font(.headline)
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Group {
                            Text("**How accurate is the AI?**")
                            Text("95%+ accuracy using Google Vision API and comprehensive safety databases.")

                            Text("**What products can I scan?**")
                            Text("Food, toys, cosmetics, electronics, household items, and more.")

                            Text("**Is my data secure?**")
                            Text("All data is encrypted and stored locally on your device.")
                        }
                        .font(.subheadline)
                    }
                }
            }

            // Contact options
            Section {
                NavigationLink(destination: Text("Support Chat or Email Screen")) {
                    VStack(alignment: .leading) {
                        Text("Contact Support")
                        Text("Get help from our support team")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(destination: Text("Report Form")) {
                    VStack(alignment: .leading) {
                        Text("Report Issue")
                        Text("Help us improve the app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Help")
    }
}

#Preview {
    NavigationView {
        HelpView()
    }
}
