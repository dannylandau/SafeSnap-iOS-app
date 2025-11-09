//
//  ScanHeroHeaderView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI
import UIKit

struct ScanHeroHeaderView: View {
    let userSession: UserSession
    let categories: [ScanCategory]
    let onHistory: () -> Void
    let onAccount: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            headerRow
            logoSection
            ScanCategoryGridView(categories: categories)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 20)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 16) {
            Button(action: onAccount) {
                AvatarView(name: userSession.fullName, avatarURL: userSession.avatarURL)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Hello \(userSession.fullName ?? "there")")
                    .font(.headline)
                Text("Welcome back!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onHistory) {
                Image("history")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("View history")
        }
    }

    private var logoSection: some View {
        VStack(spacing: 12) {
            if UIImage(named: "icon") != nil {
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "icon")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }

            Text("SafeSnap")
                .font(.system(size: 34, weight: .bold))

            Text("AI-powered product safety analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AvatarView: View {
    let name: String?
    let avatarURL: URL?

    var body: some View {
        Group {
            if let url = avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var initials: String {
        guard let name, !name.isEmpty else { return "S" }
        let parts = name.split(separator: " ")
        let first = parts.first?.first ?? Character("S")
        let last = parts.dropFirst().first?.first
        if let last {
            return "\(first)\(last)"
        }
        return "\(first)"
    }

    private var placeholder: some View {
        Text(initials)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

#if DEBUG
struct ScanHeroHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        ScanHeroHeaderView(
            userSession: PreviewUserSession(),
            categories: ScanCategory.homeDefaults,
            onHistory: {},
            onAccount: {}
        )
        .padding()
        .background(Color(uiColor: .systemGray5))
    }
}
#endif
