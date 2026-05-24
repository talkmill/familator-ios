import Foundation
import Supabase

protocol SignedURLProviding: Sendable {
    func signedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL
}

final class SupabaseSignedURLProvider: SignedURLProviding {
    private let client = SupabaseManager.client

    func signedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL {
        try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }
}
