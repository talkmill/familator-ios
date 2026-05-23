import Foundation
import Supabase

struct NoteInsert: Encodable {
    let listId: Int64
    let title: String
    let content: JSONValue

    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case title
        case content
    }
}

struct NoteUpdate: Encodable {
    var title: String?
    var content: JSONValue?

    enum CodingKeys: String, CodingKey {
        case title
        case content
    }
}

final class NotesService {
    private let client = SupabaseManager.client

    func fetchNoteSummaries(listId: Int64) async throws -> [NoteSummary] {
        try await client
            .from("notes")
            .select("id,title,updated_at")
            .eq("list_id", value: Int(listId))
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches summaries for specific note ids (order matches `noteIds`).
    func fetchNoteSummaries(noteIds: [Int64]) async throws -> [NoteSummary] {
        guard !noteIds.isEmpty else { return [] }
        let rows: [NoteSummary] = try await client
            .from("notes")
            .select("id,title,updated_at")
            .in("id", values: noteIds.map { Int($0) as any PostgrestFilterValue })
            .execute()
            .value
        let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        return noteIds.compactMap { byId[$0] }
    }

    func fetchNote(id: Int64) async throws -> Note? {
        let rows: [Note] = try await client
            .from("notes")
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func createNote(listId: Int64, title: String, content: JSONValue) async throws -> Note {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = NoteInsert(
            listId: listId,
            title: trimmed.isEmpty ? Note.untitledTitle : trimmed,
            content: content
        )
        return try await client
            .from("notes")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateNote(id: Int64, update: NoteUpdate) async throws {
        try await client
            .from("notes")
            .update(update)
            .eq("id", value: Int(id))
            .execute()
    }

    func deleteNote(id: Int64) async throws {
        try await client
            .from("notes")
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    func fetchLinkedTodos(noteId: Int64) async throws -> [LinkedTodoSummary] {
        let linkRows: [NoteTodoLink] = try await client
            .from("note_todos")
            .select("note_id,todo_id")
            .eq("note_id", value: Int(noteId))
            .order("todo_id", ascending: true)
            .execute()
            .value
        guard !linkRows.isEmpty else { return [] }
        let todoIds = linkRows.map(\.todoId)
        let todos: [LinkedTodoSummary] = try await client
            .from("todos")
            .select("id,title,status")
            .in("id", values: todoIds.map { Int($0) as any PostgrestFilterValue })
            .execute()
            .value
        let byId = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        return todoIds.compactMap { byId[$0] }
    }

    func fetchLinkedNoteIds(todoId: Int64) async throws -> [Int64] {
        let links: [NoteTodoLink] = try await client
            .from("note_todos")
            .select("note_id,todo_id")
            .eq("todo_id", value: Int(todoId))
            .execute()
            .value
        return links.map(\.noteId).sorted()
    }

    /// Syncs `note_todos` for one todo by applying only add/remove deltas (avoids wiping all links if the insert step fails).
    func replaceNoteLinks(todoId: Int64, listId: Int64, noteIds: [Int64]) async throws {
        let desired = Self.normalizeNoteIds(noteIds)
        let current = try await fetchLinkedNoteIds(todoId: todoId)
        let desiredSet = Set(desired)
        let currentSet = Set(current)
        let toAdd = desiredSet.subtracting(currentSet)
        let toRemove = currentSet.subtracting(desiredSet)

        if !toAdd.isEmpty {
            let validCount = try await client
                .from("notes")
                .select("id", head: true, count: .exact)
                .eq("list_id", value: Int(listId))
                .in("id", values: toAdd.map { Int($0) as any PostgrestFilterValue })
                .execute()
                .count ?? 0
            guard validCount == toAdd.count else {
                throw NotesServiceError.invalidLinkedNotes
            }
        }

        for noteId in toRemove {
            try await client
                .from("note_todos")
                .delete()
                .eq("todo_id", value: Int(todoId))
                .eq("note_id", value: Int(noteId))
                .execute()
        }

        guard !toAdd.isEmpty else { return }
        struct LinkInsert: Encodable {
            let noteId: Int64
            let todoId: Int64
            enum CodingKeys: String, CodingKey {
                case noteId = "note_id"
                case todoId = "todo_id"
            }
        }
        let rows = toAdd.map { LinkInsert(noteId: $0, todoId: todoId) }
        try await client.from("note_todos").insert(rows).execute()
    }

    func canWrite(list: FamilatorList, userId: UUID) async throws -> Bool {
        // With workspace-level membership, all workspace members can write to lists
        // within that workspace. RLS enforces access at the DB level.
        return true
    }

    private static func normalizeNoteIds(_ raw: [Int64]) -> [Int64] {
        var seen: Set<Int64> = []
        return raw.filter { $0 > 0 && seen.insert($0).inserted }
    }
}

enum NotesServiceError: LocalizedError {
    case invalidLinkedNotes

    var errorDescription: String? {
        switch self {
        case .invalidLinkedNotes:
            return "Each linked note must belong to the same list as the task."
        }
    }
}
