//
//  HelpView.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

struct HelpView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
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
                            Text("Scans are sent to our servers to generate safety results. Your history is stored on your device, and if you sign in we also sync history and scan images so they’re available across devices.")
                        }
                        .font(.subheadline)
                    }
                }
            }

            Section {
                Button {
                    if let url = URL(string: "mailto:support@archieml.com?subject=Archie%20Support") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Contact Support")
                            Text("Get help from our support team")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    if let url = URL(string: "mailto:support@archieml.com?subject=Archie%20Bug%20Report") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Report Issue")
                            Text("Help us improve the app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "envelope")
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
