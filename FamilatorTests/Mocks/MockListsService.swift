import Foundation
@testable import Familator

final class MockListsService: ListsServiceProtocol {
    var fetchListsHandler: ((String, UUID) async throws -> [FamilatorList])?
    var fetchListHandler: ((Int64) async throws -> FamilatorList?)?
    var createListHandler: ((UUID, String, String?, Bool) async throws -> FamilatorList)?
    var updateListHandler: ((Int64, String?, String?, Bool?) async throws -> Void)?
    var deleteListHandler: ((Int64) async throws -> Void)?
    var reorderListsHandler: ((UUID, [Int64]) async throws -> Void)?

    var fetchListsCalls: [(workspaceId: String, userId: UUID)] = []
    var fetchListCalls: [Int64] = []
    var deleteListCalls: [Int64] = []

    func fetchLists(workspaceId: String, userId: UUID) async throws -> [FamilatorList] {
        fetchListsCalls.append((workspaceId, userId))
        return try await fetchListsHandler?(workspaceId, userId) ?? []
    }

    func fetchList(id: Int64) async throws -> FamilatorList? {
        fetchListCalls.append(id)
        return try await fetchListHandler?(id)
    }

    func createList(ownerId: UUID, name: String, description: String?, isInbox: Bool) async throws -> FamilatorList {
        guard let handler = createListHandler else {
            fatalError("createListHandler not configured")
        }
        return try await handler(ownerId, name, description, isInbox)
    }

    func updateList(id: Int64, name: String?, description: String?, isShared: Bool?) async throws {
        try await updateListHandler?(id, name, description, isShared)
    }

    func deleteList(id: Int64) async throws {
        deleteListCalls.append(id)
        try await deleteListHandler?(id)
    }

    func reorderLists(userId: UUID, listIds: [Int64]) async throws {
        try await reorderListsHandler?(userId, listIds)
    }
}
