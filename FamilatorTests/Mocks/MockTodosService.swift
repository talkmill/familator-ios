import Foundation
@testable import Familator

final class MockTodosService: TodosServiceProtocol {
    var fetchTodosListHandler: ((Int64) async throws -> [Todo])?
    var fetchTodosListIdsCalls: [[Int64]] = []
    var fetchTodosListIdsHandler: (([Int64]) async throws -> [Todo])?
    var fetchTodoHandler: ((Int64) async throws -> Todo?)?
    var fetchChecklistTodosHandler: ((Int64) async throws -> [Todo])?
    var createTodoHandler: ((Int64, String, String?, String?, Date?, Date?, [Int64]?, String?) async throws -> Todo)?
    var updateTodoHandler: ((Int64, TodoUpdate) async throws -> Void)?
    var deleteTodoHandler: ((Int64) async throws -> Void)?
    var fetchSubtasksHandler: ((Int64) async throws -> [Subtask])?
    var addSubtaskHandler: ((Int64, String) async throws -> Subtask)?
    var updateSubtaskHandler: ((Int64, String?, String?) async throws -> Void)?
    var deleteSubtaskHandler: ((Int64) async throws -> Void)?

    var fetchTodosListCalls: [Int64] = []
    var fetchChecklistTodosCalls: [Int64] = []
    var createTodoCalls: [(listId: Int64, title: String, kind: String?)] = []
    var updateTodoCalls: [(id: Int64, update: TodoUpdate)] = []
    var deleteTodoCalls: [Int64] = []

    func fetchTodos(listId: Int64) async throws -> [Todo] {
        fetchTodosListCalls.append(listId)
        return try await fetchTodosListHandler?(listId) ?? []
    }

    func fetchTodos(listIds: [Int64]) async throws -> [Todo] {
        fetchTodosListIdsCalls.append(listIds)
        return try await fetchTodosListIdsHandler?(listIds) ?? []
    }

    func fetchTodo(id: Int64) async throws -> Todo? {
        try await fetchTodoHandler?(id)
    }

    func fetchChecklistTodos(listId: Int64) async throws -> [Todo] {
        fetchChecklistTodosCalls.append(listId)
        return try await fetchChecklistTodosHandler?(listId) ?? []
    }

    func createTodo(listId: Int64, title: String, description: String?, priority: String?, dueDate: Date?, plannedDate: Date?, noteIds: [Int64]?, kind: String?) async throws -> Todo {
        createTodoCalls.append((listId, title, kind))
        guard let handler = createTodoHandler else {
            fatalError("createTodoHandler not configured")
        }
        return try await handler(listId, title, description, priority, dueDate, plannedDate, noteIds, kind)
    }

    func updateTodo(id: Int64, update: TodoUpdate) async throws {
        updateTodoCalls.append((id, update))
        try await updateTodoHandler?(id, update)
    }

    func deleteTodo(id: Int64) async throws {
        deleteTodoCalls.append(id)
        try await deleteTodoHandler?(id)
    }

    func fetchSubtasks(todoId: Int64) async throws -> [Subtask] {
        try await fetchSubtasksHandler?(todoId) ?? []
    }

    func addSubtask(todoId: Int64, title: String) async throws -> Subtask {
        guard let handler = addSubtaskHandler else {
            fatalError("addSubtaskHandler not configured")
        }
        return try await handler(todoId, title)
    }

    func updateSubtask(id: Int64, title: String?, status: String?) async throws {
        try await updateSubtaskHandler?(id, title, status)
    }

    func deleteSubtask(id: Int64) async throws {
        try await deleteSubtaskHandler?(id)
    }
}
