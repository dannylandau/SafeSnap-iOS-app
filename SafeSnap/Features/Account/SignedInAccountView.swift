//
//  SignedInAccountView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI
import Clerk

struct SignedInAccountView: View {
    @Environment(Clerk.self) private var clerk

    // Stub stats – replace with real data later
    private let stats = [
        ("Scans", "2"),
        ("Avg Score", "8.2"),
        ("Safe", "89%"),
        ("Days", "30")
    ]

    var body: some View {
        // 1) Ensure we have a signed-in user
        guard let user = clerk.user else {
            // If you ever end up here, fall back to your gate
            return AnyView(Text("No user!"))
        }

        return AnyView(
            List {
                // — API Status —
                Section {
                    HStack {
                        Image(systemName: "eye.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Google Vision Active")
                                .font(.headline)
                            Text("Google Vision API is connected and working properly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Clerk Auth Active")
                                .font(.headline)
                            // 2) Show the user’s primary email
                            Text(user.primaryEmailAddress?.emailAddress ?? user.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // — Profile Header —
                Section {
                    HStack(spacing: 16) {
                        // 3) Avatar if you have one
                        if let url = URL(string: user.imageUrl) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                                .font(.headline)
                            Text(user.primaryEmailAddress?.emailAddress ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Member since \(user.createdAt.formatted(.dateTime.year().month(.wide)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Stats row
                    HStack {
                        ForEach(stats, id: \.0) { label, value in
                            VStack {
                                Text(value).font(.headline)
                                Text(label).font(.caption).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                }

                // … the rest of your sections …

                Section {
                    Button(role: .destructive) {
                        Task { try? await clerk.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right").tint(.red)
                    }
                }
            }
            .navigationTitle("Account")
        )
    }
}
