import Foundation
@testable import Familator

final class MockCurrentListService: CurrentListServiceProtocol {
    var fetchCurrentItemsHandler: ((UUID) async throws -> [CurrentListItem])?
    var fetchOrderedTodoIdsHandler: ((UUID) async throws -> [Int64])?
    var addTodoHandler: ((UUID, Int64) async throws -> Void)?
    var removeTodoHandler: ((UUID, Int64) async throws -> Void)?
    var clearCurrentHandler: ((UUID) async throws -> Void)?
    var reorderCurrentHandler: ((UUID, [Int64]) async throws -> Void)?

    var addTodoCalls: [(userId: UUID, todoId: Int64)] = []
    var removeTodoCalls: [(userId: UUID, todoId: Int64)] = []
    var clearCurrentCalls: [UUID] = []

    func fetchCurrentItems(userId: UUID) async throws -> [CurrentListItem] {
        try await fetchCurrentItemsHandler?(userId) ?? []
    }

    func fetchOrderedTodoIds(userId: UUID) async throws -> [Int64] {
        try await fetchOrderedTodoIdsHandler?(userId) ?? []
    }

    func addTodo(userId: UUID, todoId: Int64) async throws {
        addTodoCalls.append((userId, todoId))
        try await addTodoHandler?(userId, todoId)
    }

    func removeTodo(userId: UUID, todoId: Int64) async throws {
        removeTodoCalls.append((userId, todoId))
        try await removeTodoHandler?(userId, todoId)
    }

    func clearCurrent(userId: UUID) async throws {
        clearCurrentCalls.append(userId)
        try await clearCurrentHandler?(userId)
    }

    func reorderCurrent(userId: UUID, todoIds: [Int64]) async throws {
        try await reorderCurrentHandler?(userId, todoIds)
    }
}
