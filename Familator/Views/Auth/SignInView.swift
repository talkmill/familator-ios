import SwiftUI

struct SignInView: View {
    @EnvironmentObject var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showSignUp = false
    var onSignedIn: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Sign In") {
                        Task { await signIn() }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button("Sign in with Google") {
                        Task { await signInWithGoogle() }
                    }
                    .disabled(isLoading)

                    Button("Create account") {
                        showSignUp = true
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Familator")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView(onSignedUp: {
                    showSignUp = false
                    onSignedIn()
                })
                .environmentObject(auth)
            }
        }
    }

    private func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signIn(email: email, password: password)
            onSignedIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signInWithGoogle() async {
        errorMessage = nil
        guard let clientID = AppConfig.googleClientID, !clientID.isEmpty else {
            errorMessage = "Google Sign-In is not configured. Add GOOGLE_CLIENT_ID in Info.plist or Config.xcconfig (see ios/README.md)."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let idToken = await GoogleSignInHelper.signIn(), let accessToken = await GoogleSignInHelper.accessToken() else {
                errorMessage = "Google Sign-In was cancelled or failed."
                return
            }
            try await auth.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            onSignedIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
