//
//  HistoryView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 21/07/2025.
//


import SwiftUI
import Clerk

struct HistoryView: View {
  // ① pull the Clerk SDK instance
  @Environment(Clerk.self) private var clerk

  var body: some View {
    Group {
      if let _ = clerk.user {
        // ② user is signed in → show your SignedInAccountView
        NavigationView {
          SignedInHistoryView()
        }
      } else {
        // ③ no user → show Clerk’s sign-up / sign-in UI
        SignUpOrSignInView()
      }
    }
  }
}

#Preview {
  AccountView()
    .environment(Clerk.shared)  // for preview
}

#Preview {
    AccountView()
}
