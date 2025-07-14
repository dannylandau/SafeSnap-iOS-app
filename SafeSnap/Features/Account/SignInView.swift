//
//  SignInView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//


import SwiftUI
import Clerk

struct SignInView: View {
  @State private var email    = ""
  @State private var password = ""

  var body: some View {
    VStack(spacing: 16) {
      Text("Sign In")
        .font(.title2.bold())

      TextField("Email", text: $email)
        .textFieldStyle(.roundedBorder)
      SecureField("Password", text: $password)
        .textFieldStyle(.roundedBorder)

      Button("Continue") {
        Task { await submit() }
      }
    }
    .padding()
  }

  func submit() async {
    do {
      try await SignIn.create(
        strategy: .identifier(email, password: password)
      )
    } catch {
      print(error)
    }
  }
}