import XCTest
@testable import Familator

private enum MockError: Error { case notConfigured }

final class MockContextsService: ContextsServiceProtocol {
    var contextsToReturn: [TaskContext] = []
    var createdContextToReturn: TaskContext?
    var renamedContextToReturn: TaskContext?
    var errorToThrow: Error?
    var fetchContextsCalls: [UUID] = []
    var createContextCalls: [(userId: UUID, name: String)] = []
    var renameContextCalls: [(id: Int64, userId: UUID, name: String)] = []
    var deleteContextCalls: [(id: Int64, userId: UUID)] = []
    var setTodoContextsCalls: [(todoId: Int64, userId: UUID, contextIds: [Int64])] = []

    func fetchContexts(userId: UUID) async throws -> [TaskContext] {
        fetchContextsCalls.append(userId)
        if let error = errorToThrow { throw error }
        return contextsToReturn
    }

    func createContext(userId: UUID, name: String) async throws -> TaskContext {
        createContextCalls.append((userId, name))
        if let error = errorToThrow { throw error }
        guard let ctx = createdContextToReturn else { throw MockError.notConfigured }
        return ctx
    }

    func renameContext(id: Int64, userId: UUID, name: String) async throws -> TaskContext {
        renameContextCalls.append((id, userId, name))
        if let error = errorToThrow { throw error }
        guard let ctx = renamedContextToReturn else { throw MockError.notConfigured }
        return ctx
    }

    func deleteContext(id: Int64, userId: UUID) async throws {
        deleteContextCalls.append((id, userId))
        if let error = errorToThrow { throw error }
    }

    func setTodoContexts(todoId: Int64, userId: UUID, contextIds: [Int64]) async throws {
        setTodoContextsCalls.append((todoId, userId, contextIds))
        if let error = errorToThrow { throw error }
    }
}

final class ContextsServiceSeamTests: XCTestCase {
    private let testUserId = UUID()

    func testMockReturnsContexts() async throws {
        let mock = MockContextsService()
        let ctx = TaskContext(id: 1, name: "Work", createdAt: Date(), updatedAt: Date())
        mock.contextsToReturn = [ctx]

        let result = try await mock.fetchContexts(userId: testUserId)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Work")
        XCTAssertEqual(mock.fetchContextsCalls.count, 1)
    }

    func testMockRecordsCreateContext() async throws {
        let mock = MockContextsService()
        mock.createdContextToReturn = TaskContext(id: 2, name: "Personal", createdAt: Date(), updatedAt: Date())

        let result = try await mock.createContext(userId: testUserId, name: "Personal")

        XCTAssertEqual(result.name, "Personal")
        XCTAssertEqual(mock.createContextCalls.count, 1)
        XCTAssertEqual(mock.createContextCalls.first?.name, "Personal")
    }

    func testMockRecordsSetTodoContexts() async throws {
        let mock = MockContextsService()

        try await mock.setTodoContexts(todoId: 5, userId: testUserId, contextIds: [1, 2])

        XCTAssertEqual(mock.setTodoContextsCalls.count, 1)
        XCTAssertEqual(mock.setTodoContextsCalls.first?.contextIds, [1, 2])
    }

    func testMockThrowsConfiguredError() async {
        let mock = MockContextsService()
        mock.errorToThrow = ContextsServiceError.duplicateName

        do {
            _ = try await mock.createContext(userId: testUserId, name: "Dup")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? ContextsServiceError, .duplicateName)
        }
    }
}
