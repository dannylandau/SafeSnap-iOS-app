//
//  SignedInAccountView.swift
//  SafeSnap
//

import SwiftUI

struct SignedInAccountView: View {
    @StateObject private var viewModel: AccountViewModel
    @State private var showProfileEditor = false
    @State private var sharePayload: SharePayload?

    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    init(viewModel: AccountViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                accountCard
                signOutButton
            }
            .padding(.bottom, 48)
        }
        .background(Color(red: 0.93, green: 0.94, blue: 0.96).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
        .background(
            NavigationLink(destination: ProfileSettingsView(), isActive: $showProfileEditor) {
                EmptyView()
            }
            .hidden()
        )
    }

    private var accountCard: some View {
        VStack(alignment: .center, spacing: 24) {
            dragIndicator
                .padding(.top, -8)
            profileHeader
            settingsStack
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            Text("My Account")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            ZStack(alignment: .bottomTrailing) {
                avatarView
                Button {
                    showProfileEditor = true
                } label: {
                    Image("edit")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.green)
                        .clipShape(Circle())
                        .shadow(radius: 4, y: 2)
                }
            }
            Text(viewModel.fullName)
                .font(.title2.weight(.semibold))
            Text(viewModel.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let memberSince = viewModel.memberSince {
                Text("Member since \(memberSince)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var settingsStack: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: ProfileSettingsView()) {
                AccountActionRow(
                    iconName: "person.crop.circle.fill",
                    iconTint: Color.blue.opacity(0.9),
                    title: "Profile",
                    subtitle: "Personal information"
                )
            }
            dividerInset
            NavigationLink(destination: NotificationsSettingsView()) {
                AccountActionRow(
                    iconName: "bell.fill",
                    iconTint: Color.purple.opacity(0.9),
                    title: "Notifications",
                    subtitle: "Alerts & updates"
                )
            }
            dividerInset
            NavigationLink(destination: PrivacySettingsView()) {
                AccountActionRow(
                    iconName: "lock.shield.fill",
                    iconTint: Color.orange.opacity(0.9),
                    title: "Privacy",
                    subtitle: "Security settings"
                )
            }
            dividerInset
            NavigationLink(destination: HelpView()) {
                AccountActionRow(
                    iconName: "questionmark.circle.fill",
                    iconTint: Color.teal.opacity(0.9),
                    title: "Help",
                    subtitle: "Get support"
                )
            }
            dividerInset
            Button(action: shareApp) {
                AccountActionRow(
                    iconName: "square.and.arrow.up",
                    iconTint: Color.green.opacity(0.9),
                    title: "Share App",
                    subtitle: "Tell friends",
                    showChevron: false
                )
            }
        }
        .padding(12)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var dividerInset: some View {
        Divider()
            .padding(.leading, 64)
    }

    private var avatarView: some View {
        Group {
            if let url = viewModel.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.gray.opacity(0.3)
                    case .empty:
                        Color.gray.opacity(0.15)
                    @unknown default:
                        Color.gray.opacity(0.15)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .frame(width: 130, height: 130)
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private var signOutButton: some View {
        Button {
            Task { await viewModel.signOut() }
        } label: {
            Text("Sign Out")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.green)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 20)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("SafeSnap \(viewModel.appVersion)")
            Text("Powered by Google Gemini AI")
            if viewModel.demoMode {
                Text("Demo version – all features functional")
            }
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func shareApp() {
        sharePayload = SharePayload(items: ["Check out SafeSnap — keeping families and pets safe."])
    }

    private var dragIndicator: some View {
        Capsule()
            .fill(Color.black.opacity(0.15))
            .frame(width: 44, height: 5)
            .accessibilityHidden(true)
    }
}

private struct AccountActionRow: View {
    let iconName: String
    let iconTint: Color
    let title: String
    let subtitle: String
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(iconTint.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconTint)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}
