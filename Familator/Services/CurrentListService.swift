import Foundation
import Supabase

final class CurrentListService {
    private let client = SupabaseManager.client
    private func userKey(_ userId: UUID) -> String { userId.uuidString.lowercased() }

    func fetchCurrentItems(userId: UUID) async throws -> [CurrentListItem] {
        let userIdKey = userKey(userId)
        return try await client
            .from("current_list_items")
            .select()
            .eq("user_id", value: userIdKey)
            .order("position", ascending: true)
            .order("id", ascending: true)
            .execute()
            .value
    }

    func fetchOrderedTodoIds(userId: UUID) async throws -> [Int64] {
        try await fetchCurrentItems(userId: userId).map(\.todoId)
    }

    func addTodo(userId: UUID, todoId: Int64) async throws {
        let userIdKey = userKey(userId)
        let existing: [CurrentListItem] = try await client
            .from("current_list_items")
            .select()
            .eq("user_id", value: userIdKey)
            .eq("todo_id", value: Int(todoId))
            .limit(1)
            .execute()
            .value
        if !existing.isEmpty { return }

        let rows: [CurrentListItem] = try await client
            .from("current_list_items")
            .select()
            .eq("user_id", value: userIdKey)
            .order("position", ascending: false)
            .limit(1)
            .execute()
            .value
        let nextPosition = (rows.first?.position ?? -1) + 1

        struct CurrentInsert: Encodable {
            let userId: UUID
            let todoId: Int64
            let position: Int

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case todoId = "todo_id"
                case position
            }
        }

        let payload = CurrentInsert(userId: userId, todoId: todoId, position: nextPosition)
        try await client.from("current_list_items").insert(payload).execute()
    }

    func removeTodo(userId: UUID, todoId: Int64) async throws {
        let userIdKey = userKey(userId)
        try await client
            .from("current_list_items")
            .delete()
            .eq("user_id", value: userIdKey)
            .eq("todo_id", value: Int(todoId))
            .execute()
    }

    func clearCurrent(userId: UUID) async throws {
        let userIdKey = userKey(userId)
        try await client
            .from("current_list_items")
            .delete()
            .eq("user_id", value: userIdKey)
            .execute()
    }

    func reorderCurrent(userId: UUID, todoIds: [Int64]) async throws {
        guard !todoIds.isEmpty else { return }

        struct CurrentOrderRow: Encodable {
            let userId: UUID
            let todoId: Int64
            let position: Int

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case todoId = "todo_id"
                case position
            }
        }

        let orderedUnique = todoIds.reduce(into: [Int64]()) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
        let rows = orderedUnique.enumerated().map { CurrentOrderRow(userId: userId, todoId: $1, position: $0) }
        try await client.from("current_list_items").upsert(rows, onConflict: "user_id,todo_id").execute()
    }
}

