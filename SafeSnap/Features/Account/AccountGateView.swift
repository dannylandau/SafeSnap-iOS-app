//
//  AccountGateView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//


import SwiftUI
import Clerk

struct AccountGateView: View {
  @Environment(Clerk.self) private var clerk

  var body: some View {
    if let user = clerk.user {
      SignedInAccountView()
    } else {
      SignUpOrSignInView()
    }
  }
}
