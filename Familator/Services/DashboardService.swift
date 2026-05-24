import Foundation
import Supabase

struct DashboardFavoriteInput {
    let itemType: String
    let listId: Int64?
    let filterKey: String?
}

protocol DashboardServiceProtocol {
    func fetchFavorites(userId: UUID) async throws -> [DashboardFavoriteRow]
    func setFavorites(userId: UUID, favorites: [DashboardFavoriteInput]) async throws
}

final class DashboardService: DashboardServiceProtocol {
    private let client = SupabaseManager.client

    func fetchFavorites(userId: UUID) async throws -> [DashboardFavoriteRow] {
        let rows: [DashboardFavoriteRow] = try await client
            .from("dashboard_favorites")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("position")
            .execute()
            .value
        return rows
    }

    func setFavorites(userId: UUID, favorites: [DashboardFavoriteInput]) async throws {
        try await client
            .from("dashboard_favorites")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()

        guard favorites.count <= 5 else { return }
        struct Row: Encodable {
            let userId: UUID
            let position: Int
            let itemType: String
            let listId: Int64?
            let filterKey: String?
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case position
                case itemType = "item_type"
                case listId = "list_id"
                case filterKey = "filter_key"
            }
        }
        let rows = favorites.enumerated().map { i, f in
            Row(userId: userId, position: i, itemType: f.itemType, listId: f.listId, filterKey: f.filterKey)
        }
        if !rows.isEmpty {
            try await client.from("dashboard_favorites").insert(rows).execute()
        }
    }
}
