import Foundation
import Supabase

struct TodoInsert: Encodable {
    let listId: Int64
    let title: String
    let description: String?
    let status: String
    let priority: String?
    let dueDate: Date?
    let plannedDate: Date?
    let noteIds: [Int64]?
    let kind: String?

    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case title
        case description
        case status
        case priority
        case dueDate = "due_date"
        case plannedDate = "planned_date"
        case noteIds = "note_ids"
        case kind
    }
}

struct TodoUpdate: Encodable {
    var title: String?
    var description: String?
    var status: String?
    var priority: String?
    var dueDate: Date?
    var plannedDate: Date?
    var listId: Int64?
    /// When true, clears `recurrence`, `recurrence_series_id`, and sets `recurrence_paused` false (matches web API).
    var removeRecurrence: Bool = false
    var recurrence: TodoRecurrenceJSON?
    var recurrenceSeriesId: UUID?
    var recurrencePaused: Bool?
    var noteIds: [Int64]?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case status
        case priority
        case dueDate = "due_date"
        case plannedDate = "planned_date"
        case listId = "list_id"
        case recurrence
        case recurrenceSeriesId = "recurrence_series_id"
        case recurrencePaused = "recurrence_paused"
        case noteIds = "note_ids"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(priority, forKey: .priority)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(plannedDate, forKey: .plannedDate)
        try c.encodeIfPresent(listId, forKey: .listId)
        if removeRecurrence {
            try c.encodeNil(forKey: .recurrence)
            try c.encodeNil(forKey: .recurrenceSeriesId)
            try c.encode(false, forKey: .recurrencePaused)
        } else {
            try c.encodeIfPresent(recurrence, forKey: .recurrence)
            try c.encodeIfPresent(recurrenceSeriesId, forKey: .recurrenceSeriesId)
            try c.encodeIfPresent(recurrencePaused, forKey: .recurrencePaused)
        }
        try c.encodeIfPresent(noteIds, forKey: .noteIds)
    }
}

final class TodosService {
    private let client = SupabaseManager.client

    func fetchTodos(listId: Int64) async throws -> [Todo] {
        var todos: [Todo] = try await client
            .from("todos")
            .select()
            .eq("list_id", value: Int(listId))
            .order("created_at", ascending: false)
            .execute()
            .value
        try await attachContexts(to: &todos)
        return todos
    }

    /// Fetch todos from multiple lists (e.g. for "All tasks" or time-based filters).
    func fetchTodos(listIds: [Int64]) async throws -> [Todo] {
        guard !listIds.isEmpty else { return [] }
        var todos: [Todo] = try await client
            .from("todos")
            .select()
            .in("list_id", values: listIds.map { Int($0) as any PostgrestFilterValue })
            .order("due_date", ascending: true)
            .order("created_at", ascending: false)
            .execute()
            .value
        try await attachContexts(to: &todos)
        return todos
    }

    func fetchTodo(id: Int64) async throws -> Todo? {
        var rows: [Todo] = try await client
            .from("todos")
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .execute()
            .value
        try await attachContexts(to: &rows)
        return rows.first
    }

    /// Fetches todos for a trip checklist. Skips `attachContexts` intentionally —
    /// checklist items don't use task contexts.
    func fetchChecklistTodos(listId: Int64) async throws -> [Todo] {
        let todos: [Todo] = try await client
            .from("todos")
            .select()
            .eq("list_id", value: Int(listId))
            .order("created_at", ascending: true)
            .execute()
            .value
        return todos
    }

    func createTodo(listId: Int64, title: String, description: String?, priority: String?, dueDate: Date?, plannedDate: Date?, noteIds: [Int64]? = nil, kind: String? = nil) async throws -> Todo {
        let payload = TodoInsert(
            listId: listId,
            title: title,
            description: description,
            status: Todo.statusPending,
            priority: priority ?? Todo.priorityMedium,
            dueDate: dueDate,
            plannedDate: plannedDate,
            noteIds: noteIds,
            kind: kind
        )
        var todo: Todo = try await client
            .from("todos")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        var todos = [todo]
        try await attachContexts(to: &todos)
        todo = todos[0]
        return todo
    }

    func updateTodo(id: Int64, update: TodoUpdate) async throws {
        try await client
            .from("todos")
            .update(update)
            .eq("id", value: Int(id))
            .execute()
    }

    func deleteTodo(id: Int64) async throws {
        try await client
            .from("todos")
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }

    func fetchSubtasks(todoId: Int64) async throws -> [Subtask] {
        try await client
            .from("subtasks")
            .select()
            .eq("todo_id", value: Int(todoId))
            .order("created_at")
            .execute()
            .value
    }

    func addSubtask(todoId: Int64, title: String) async throws -> Subtask {
        struct Payload: Encodable {
            let todoId: Int64
            let title: String
            let status: String
            enum CodingKeys: String, CodingKey {
                case todoId = "todo_id"
                case title
                case status
            }
        }
        let payload = Payload(todoId: todoId, title: title, status: Subtask.statusPending)
        return try await client
            .from("subtasks")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateSubtask(id: Int64, title: String?, status: String?) async throws {
        struct Payload: Encodable {
            var title: String?
            var status: String?
        }
        var p = Payload(title: title, status: status)
        if title == nil { p.title = nil }
        if status == nil { p.status = nil }
        try await client.from("subtasks").update(p).eq("id", value: Int(id)).execute()
    }

    func deleteSubtask(id: Int64) async throws {
        try await client.from("subtasks").delete().eq("id", value: Int(id)).execute()
    }

    private func attachContexts(to todos: inout [Todo]) async throws {
        guard !todos.isEmpty else { return }
        let todoIds = todos.map(\.id)
        let links: [TaskContextLinkRow] = try await client
            .from("task_contexts")
            .select("task_id,contexts(id,name,created_at,updated_at)")
            .in("task_id", values: todoIds.map { Int($0) as any PostgrestFilterValue })
            .execute()
            .value

        var contextsByTodoId: [Int64: [TaskContext]] = [:]
        for link in links {
            guard let context = link.contextValue else { continue }
            contextsByTodoId[link.taskId, default: []].append(context)
        }

        for index in todos.indices {
            todos[index].contexts = contextsByTodoId[todos[index].id] ?? []
        }
    }
}

private struct TaskContextLinkRow: Decodable {
    let taskId: Int64
    let contexts: TaskContextReference

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case contexts
    }

    var contextValue: TaskContext? {
        contexts.first
    }
}

private enum TaskContextReference: Decodable {
    case one(TaskContext)
    case many([TaskContext])

    init(from decoder: Decoder) throws {
        if let single = try? TaskContext(from: decoder) {
            self = .one(single)
            return
        }
        let many = try [TaskContext](from: decoder)
        self = .many(many)
    }

    var first: TaskContext? {
        switch self {
        case .one(let context):
            return context
        case .many(let contexts):
            return contexts.first
        }
    }
}
