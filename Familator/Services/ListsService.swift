import Foundation
import Supabase

final class ListsService {
    private let client = SupabaseManager.client

    func fetchLists(workspaceId: String, userId: UUID) async throws -> [FamilatorList] {
        let lists: [FamilatorList] = try await client
            .from("lists")
            .select()
            .eq("workspace_id", value: workspaceId)
            .execute()
            .value

        let orderRows: [UserListOrder] = try await client
            .from("user_list_order")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("position")
            .execute()
            .value

        let orderMap = Dictionary(uniqueKeysWithValues: orderRows.enumerated().map { ($1.listId, $0) })
        return lists.sorted { (a, b) in
            let posA = orderMap[a.id] ?? Int.max
            let posB = orderMap[b.id] ?? Int.max
            if posA != posB { return posA < posB }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Fetches a single list by ID. RLS on `lists` enforces workspace membership
    /// via `is_workspace_member(workspace_id, auth.uid())`, so this cannot leak
    /// cross-workspace data.
    func fetchList(id: Int64) async throws -> FamilatorList? {
        let rows: [FamilatorList] = try await client
            .from("lists")
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func createList(ownerId: UUID, name: String, description: String?, isInbox: Bool = false) async throws -> FamilatorList {
        struct Payload: Encodable {
            let ownerId: UUID
            let name: String
            let description: String?
            let isShared: Bool
            let isInbox: Bool
            enum CodingKeys: String, CodingKey {
                case ownerId = "owner_id"
                case name
                case description
                case isShared = "is_shared"
                case isInbox = "is_inbox"
            }
        }
        let payload = Payload(ownerId: ownerId, name: name, description: description, isShared: false, isInbox: isInbox)
        let response: FamilatorList = try await client
            .from("lists")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return response
    }

    func updateList(id: Int64, name: String?, description: String?, isShared: Bool?) async throws {
        struct Payload: Encodable {
            var name: String?
            var description: String?
            var isShared: Bool?
            enum CodingKeys: String, CodingKey {
                case name
                case description
                case isShared = "is_shared"
            }
        }
        let payload = Payload(name: name, description: description, isShared: isShared)
        try await client
            .from("lists")
            .update(payload)
            .eq("id", value: Int(id))
            .execute()
    }

    func deleteList(id: Int64) async throws {
        try await client
            .from("lists")
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    func reorderLists(userId: UUID, listIds: [Int64]) async throws {
        struct OrderRow: Encodable {
            let userId: UUID
            let listId: Int64
            let position: Int
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case listId = "list_id"
                case position
            }
        }
        try await client.from("user_list_order").delete().eq("user_id", value: userId.uuidString).execute()
        if listIds.isEmpty { return }
        let rows = listIds.enumerated().map { OrderRow(userId: userId, listId: $1, position: $0) }
        try await client.from("user_list_order").upsert(rows).execute()
    }
}

private extension Array where Element: Identifiable {
    func uniqued(by keyPath: (Element) -> Element.ID) -> [Element] {
        var seen: Set<Element.ID> = []
        return filter { seen.insert(keyPath($0)).inserted }
    }
}
