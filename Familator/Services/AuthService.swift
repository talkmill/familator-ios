import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    private let client = SupabaseManager.client

    var currentSession: Session? {
        client.auth.currentSession
    }

    var currentUser: User? {
        client.auth.currentUser
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        _ = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func session() async throws -> Session {
        try await client.auth.session
    }
}
