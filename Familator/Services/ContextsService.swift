import Foundation
import Supabase

protocol ContextsServiceProtocol {
    func fetchContexts(userId: UUID) async throws -> [TaskContext]
    func createContext(userId: UUID, name: String) async throws -> TaskContext
    func renameContext(id: Int64, userId: UUID, name: String) async throws -> TaskContext
    func deleteContext(id: Int64, userId: UUID) async throws
    func setTodoContexts(todoId: Int64, userId: UUID, contextIds: [Int64]) async throws
}

final class ContextsService: ContextsServiceProtocol {
    private let client = SupabaseManager.client

    func fetchContexts(userId: UUID) async throws -> [TaskContext] {
        try await client
            .from("contexts")
            .select("id,name,created_at,updated_at")
            .eq("user_id", value: userId.uuidString)
            .order("name")
            .execute()
            .value
    }

    func createContext(userId: UUID, name: String) async throws -> TaskContext {
        struct Payload: Encodable {
            let userId: UUID
            let name: String

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case name
            }
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ContextsServiceError.invalidName
        }
        guard trimmed.count <= 80 else {
            throw ContextsServiceError.nameTooLong
        }

        do {
            return try await client
                .from("contexts")
                .insert(Payload(userId: userId, name: trimmed))
                .select("id,name,created_at,updated_at")
                .single()
                .execute()
                .value
        } catch {
            if Self.isDuplicateConstraint(error) {
                throw ContextsServiceError.duplicateName
            }
            throw error
        }
    }

    func renameContext(id: Int64, userId: UUID, name: String) async throws -> TaskContext {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ContextsServiceError.invalidName
        }
        guard trimmed.count <= 80 else {
            throw ContextsServiceError.nameTooLong
        }

        do {
            return try await client
                .from("contexts")
                .update(["name": trimmed])
                .eq("id", value: Int(id))
                .eq("user_id", value: userId.uuidString)
                .select("id,name,created_at,updated_at")
                .single()
                .execute()
                .value
        } catch {
            if Self.isDuplicateConstraint(error) {
                throw ContextsServiceError.duplicateName
            }
            throw error
        }
    }

    func deleteContext(id: Int64, userId: UUID) async throws {
        try await client
            .from("contexts")
            .delete()
            .eq("id", value: Int(id))
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func setTodoContexts(todoId: Int64, userId: UUID, contextIds: [Int64]) async throws {
        let payload = SyncContextPayload(todoId: todoId, userId: userId, contextIds: contextIds)
        _ = try await client
            .rpc("update_todo_atomic", params: payload)
            .execute()
    }

    private struct SyncContextPayload: Encodable {
        let pTodoId: Int64
        let pUserId: UUID
        let pSyncContextIds: Bool
        let pContextIds: [Int64]
        let pSetListId: Bool
        let pListId: Int64?
        let pSetTitle: Bool
        let pTitle: String?
        let pSetDescription: Bool
        let pDescription: String?
        let pSetStatus: Bool
        let pStatus: String?
        let pSetPriority: Bool
        let pPriority: String?
        let pSetPlannedDate: Bool
        let pPlannedDate: Date?
        let pSetDueDate: Bool
        let pDueDate: Date?
        let pSetRecurrence: Bool
        let pRecurrence: TodoRecurrenceJSON?
        let pSetRecurrencePaused: Bool
        let pRecurrencePaused: Bool?
        let pSetRecurrenceSeriesId: Bool
        let pRecurrenceSeriesId: UUID?
        let pSetCompletedAt: Bool
        let pCompletedAt: Date?
        let pSyncNoteIds: Bool
        let pNoteIds: [Int64]

        init(todoId: Int64, userId: UUID, contextIds: [Int64]) {
            pTodoId = todoId
            pUserId = userId
            pSyncContextIds = true
            pContextIds = contextIds
            pSetListId = false
            pListId = nil
            pSetTitle = false
            pTitle = nil
            pSetDescription = false
            pDescription = nil
            pSetStatus = false
            pStatus = nil
            pSetPriority = false
            pPriority = nil
            pSetPlannedDate = false
            pPlannedDate = nil
            pSetDueDate = false
            pDueDate = nil
            pSetRecurrence = false
            pRecurrence = nil
            pSetRecurrencePaused = false
            pRecurrencePaused = nil
            pSetRecurrenceSeriesId = false
            pRecurrenceSeriesId = nil
            pSetCompletedAt = false
            pCompletedAt = nil
            pSyncNoteIds = false
            pNoteIds = []
        }

        enum CodingKeys: String, CodingKey {
            case pTodoId = "p_todo_id"
            case pUserId = "p_user_id"
            case pSyncContextIds = "p_sync_context_ids"
            case pContextIds = "p_context_ids"
            case pSetListId = "p_set_list_id"
            case pListId = "p_list_id"
            case pSetTitle = "p_set_title"
            case pTitle = "p_title"
            case pSetDescription = "p_set_description"
            case pDescription = "p_description"
            case pSetStatus = "p_set_status"
            case pStatus = "p_status"
            case pSetPriority = "p_set_priority"
            case pPriority = "p_priority"
            case pSetPlannedDate = "p_set_planned_date"
            case pPlannedDate = "p_planned_date"
            case pSetDueDate = "p_set_due_date"
            case pDueDate = "p_due_date"
            case pSetRecurrence = "p_set_recurrence"
            case pRecurrence = "p_recurrence"
            case pSetRecurrencePaused = "p_set_recurrence_paused"
            case pRecurrencePaused = "p_recurrence_paused"
            case pSetRecurrenceSeriesId = "p_set_recurrence_series_id"
            case pRecurrenceSeriesId = "p_recurrence_series_id"
            case pSetCompletedAt = "p_set_completed_at"
            case pCompletedAt = "p_completed_at"
            case pSyncNoteIds = "p_sync_note_ids"
            case pNoteIds = "p_note_ids"
        }
    }

    private static func isDuplicateConstraint(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "PostgrestError",
           let code = nsError.userInfo["code"] as? String {
            return code == "23505"
        }
        return error.localizedDescription.contains("23505")
    }
}

enum ContextsServiceError: LocalizedError {
    case invalidName
    case nameTooLong
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Context name is required."
        case .nameTooLong:
            return "Context name must be 80 characters or less."
        case .duplicateName:
            return "That context already exists."
        }
    }
}
