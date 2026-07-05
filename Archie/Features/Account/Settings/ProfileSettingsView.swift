import SwiftUI

struct ProfileSettingsView: View {
    let userSession: UserSession

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                Text(userSession.fullName ?? "Not set")
                    .foregroundColor(userSession.fullName == nil ? .secondary : .primary)
            }

            Section(header: Text("Email")) {
                Text(userSession.email ?? "Not set")
                    .foregroundColor(.secondary)
            }

            if let memberSince = userSession.memberSince {
                Section(header: Text("Member Since")) {
                    Text(memberSince)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Profile")
    }
}

#if DEBUG
#Preview {
    NavigationView {
        ProfileSettingsView(userSession: PreviewUserSession())
    }
}
#endif
