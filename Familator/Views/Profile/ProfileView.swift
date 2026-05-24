import SwiftUI

struct ProfileView: View {
    private let maxFeatureRequestTitleLength = 120
    private let maxFeatureRequestDescriptionLength = 2000
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var profile: ProfileViewModel
    @State private var isSigningOut = false
    @State private var featureRequestTitle = ""
    @State private var featureRequestDescription = ""
    @State private var isSubmittingFeatureRequest = false
    @State private var featureRequestError: String?
    @State private var featureRequestSuccess: String?
    private let featureRequestService: FeatureRequestServiceProtocol

    init(featureRequestService: FeatureRequestServiceProtocol = FeatureRequestService()) {
        self.featureRequestService = featureRequestService
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let p = profile.profile {
                        HStack {
                            if let urlString = p.avatarUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.largeTitle)
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                            }
                            VStack(alignment: .leading) {
                                Text(p.displayName ?? "User")
                                    .font(.headline)
                                if let email = auth.currentUser?.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if auth.currentUser != nil {
                        Text(auth.currentUser?.email ?? "Signed in")
                            .font(.headline)
                    }
                }

                if let errorMessage = profile.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Feature Requests") {
                    TextField("Title", text: $featureRequestTitle)
                        .onChange(of: featureRequestTitle) { newValue in
                            if newValue.count > maxFeatureRequestTitleLength {
                                featureRequestTitle = String(newValue.prefix(maxFeatureRequestTitleLength))
                            }
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $featureRequestDescription)
                            .frame(minHeight: 100)
                            .onChange(of: featureRequestDescription) { newValue in
                                if newValue.count > maxFeatureRequestDescriptionLength {
                                    featureRequestDescription = String(newValue.prefix(maxFeatureRequestDescriptionLength))
                                }
                            }
                    }

                    if let featureRequestError {
                        Text(featureRequestError)
                            .foregroundStyle(.red)
                    }

                    if let featureRequestSuccess {
                        Text(featureRequestSuccess)
                            .foregroundStyle(.green)
                    }

                    Button(isSubmittingFeatureRequest ? "Submitting..." : "Submit Feature Request") {
                        Task { await submitFeatureRequest() }
                    }
                    .disabled(isSubmittingFeatureRequest || featureRequestTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await signOut() }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WorkspaceNavButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if profile.isRefreshing {
                        ProgressView()
                    }
                }
            }
            .overlay {
                if profile.isBlockingLoad && profile.profile == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task { await profile.load(userId: auth.currentUser?.id) }
            .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
                Task { await profile.load(userId: auth.currentUser?.id) }
            }
        }
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await auth.signOut()
            profile.reset()
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        } catch {
            profile.errorMessage = error.localizedDescription
        }
    }

    private func submitFeatureRequest() async {
        guard let userId = auth.currentUser?.id else {
            featureRequestError = "You must be signed in to submit a feature request."
            return
        }

        let trimmedTitle = featureRequestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            featureRequestError = "Title is required."
            return
        }

        isSubmittingFeatureRequest = true
        featureRequestError = nil
        featureRequestSuccess = nil
        defer { isSubmittingFeatureRequest = false }

        do {
            try await featureRequestService.submit(
                userId: userId,
                title: trimmedTitle,
                description: featureRequestDescription
            )
            featureRequestTitle = ""
            featureRequestDescription = ""
            featureRequestSuccess = "Thanks! Your feature request was submitted."
        } catch {
            featureRequestError = error.localizedDescription
        }
    }
}
