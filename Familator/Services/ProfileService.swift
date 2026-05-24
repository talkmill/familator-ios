import Foundation
import Supabase

protocol ProfileServiceProtocol {
    func fetchProfile(userId: UUID) async throws -> Profile?
    func updateProfile(userId: UUID, displayName: String?, avatarUrl: String?) async throws
}

final class ProfileService: ProfileServiceProtocol {
    private let client = SupabaseManager.client

    func fetchProfile(userId: UUID) async throws -> Profile? {
        let response: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return response.first
    }

    func updateProfile(userId: UUID, displayName: String?, avatarUrl: String?) async throws {
        struct Payload: Encodable {
            var displayName: String?
            var avatarUrl: String?
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case avatarUrl = "avatar_url"
            }
        }
        let payload = Payload(displayName: displayName, avatarUrl: avatarUrl)
        try await client
            .from("profiles")
            .update(payload)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}
