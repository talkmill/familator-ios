import Foundation
import Supabase

protocol FeatureRequestServiceProtocol {
    func submit(userId: UUID, title: String, description: String?) async throws
}

final class FeatureRequestService: FeatureRequestServiceProtocol {
    private let client = SupabaseManager.client

    private struct Payload: Encodable {
        let userId: String
        let title: String
        let description: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case title
            case description
        }
    }

    func submit(userId: UUID, title: String, description: String?) async throws {
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = Payload(
            userId: userId.uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedDescription?.isEmpty == true ? nil : trimmedDescription
        )

        try await client
            .from("feature_requests")
            .insert(payload)
            .execute()
    }
}
