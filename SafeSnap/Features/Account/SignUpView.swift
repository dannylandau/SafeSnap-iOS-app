import SwiftUI
import Clerk

struct SignUpView: View {
    @State private var email       = ""
    @State private var password    = ""
    @State private var code        = ""
    @State private var isVerifying = false

    // ⏳ Loading & error state
    @State private var isLoading    = false
    @State private var showError    = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(isVerifying ? "Enter Code" : "Sign Up")
                .font(.title2.bold())

            if isVerifying {
                TextField("Verification Code", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                Button(action: {
                    Task { await verify() }
                }) {
                    Label {
                        Text("Verify")
                    } icon: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading || code.isEmpty)

            } else {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(isLoading)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                Button(action: {
                    Task { await signUp() }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.75)
                        }
                        Text(isLoading ? "Signing Up..." : "Continue")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoading ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    func signUp() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let s = try await SignUp.create(
                strategy: .standard(emailAddress: email, password: password)
            )
            try await s.prepareVerification(strategy: .emailCode)
            isVerifying = true

        } catch let apiError as ClerkAPIError {
            switch apiError.code {
            case "form_password_pwned":
                errorMessage = "That password has been in a data breach. Please choose a different one."
            case "form_password_too_short":
                errorMessage = "Passwords must be at least 8 characters."
            default:
                errorMessage = apiError.longMessage ?? apiError.message ?? "Unknown sign-up error."
            }
            showError = true

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func verify() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await Clerk.shared.client!.signUp!.attemptVerification(
                strategy: .emailCode(code: code)
            )
        } catch {
            errorMessage = "Verification failed. Please try again."
            showError = true
        }
    }
}
