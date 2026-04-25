import SwiftUI
import UIKit

struct FirebaseAuthView: View {
    @StateObject private var viewModel: FirebaseAuthViewModel

    init(viewModel: FirebaseAuthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign In")
                    .font(.largeTitle.bold())

                Text("Sign in to sync your Archie history across devices.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 12) {
                AppleSignInButton {
                    Task {
                        let window = UIApplication.safesnapKeyWindow
                        _ = await viewModel.signInWithApple(presenting: window)
                    }
                }
                .frame(height: 50)
                .allowsHitTesting(!viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.6 : 1)

                GoogleSignInButton(
                    title: "Continue with Google",
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        let presenter = UIApplication.safesnapKeyWindow?.rootViewController?.topMostViewController
                        _ = await viewModel.signInWithGoogle(presenting: presenter)
                    }
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

#if DEBUG
#Preview {
    FirebaseAuthView(viewModel: FirebaseAuthViewModel())
}
#endif
