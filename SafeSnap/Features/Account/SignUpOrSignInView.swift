import SwiftUI

struct SignUpOrSignInView: View {
  @State private var isSignUp = true

  var body: some View {
    ScrollView {
      if isSignUp {
        SignUpView()
      } else {
        SignInView()
      }
      Button {
        isSignUp.toggle()
      } label: {
        Text(isSignUp
             ? "Already have an account? Sign in"
             : "Don't have an account? Sign up")
          .font(.footnote)
          .padding()
      }
    }
    .padding()
  }
}
