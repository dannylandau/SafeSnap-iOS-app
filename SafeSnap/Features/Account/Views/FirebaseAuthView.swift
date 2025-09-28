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
                Text("Sign in with Google")
                    .font(.largeTitle.bold())

                Text("Connect your Google account to sync SafeSnap history across devices.")
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

            Button {
                Task {
                    let presenter = UIApplication.safesnapKeyWindow?.rootViewController?.topMostViewController
                    await viewModel.signInWithGoogle(presenting: presenter)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.title3)

                    Text(viewModel.isLoading ? "Signing in…" : "Continue with Google")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)

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
