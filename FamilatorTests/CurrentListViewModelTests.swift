import XCTest
@testable import Familator

@MainActor
final class CurrentListViewModelTests: XCTestCase {
    private var mockLists: MockListsService!
    private var mockTodos: MockTodosService!
    private var mockCurrent: MockCurrentListService!
    private var sut: CurrentListViewModel!
    private let testUserId = UUID()
    private let testWorkspaceId = "ws-1"

    override func setUp() {
        super.setUp()
        mockLists = MockListsService()
        mockTodos = MockTodosService()
        mockCurrent = MockCurrentListService()
        sut = CurrentListViewModel(
            listsService: mockLists,
            todosService: mockTodos,
            currentListService: mockCurrent
        )
    }

    private func makeList(id: Int64 = 1, name: String = "Test") -> FamilatorList {
        let data = try! JSONSerialization.data(withJSONObject: [
            "id": id, "owner_id": testUserId.uuidString, "name": name,
            "is_shared": false,
            "created_at": "2026-01-01T00:00:00+00:00",
            "updated_at": "2026-01-01T00:00:00+00:00",
        ])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(FamilatorList.self, from: data)
    }

    private func makeTodo(id: Int64 = 1, listId: Int64 = 1, status: String = Todo.statusPending) -> Todo {
        let data = try! JSONSerialization.data(withJSONObject: [
            "id": id, "list_id": listId, "title": "Todo \(id)",
            "status": status,
            "created_at": "2026-01-01T00:00:00+00:00",
            "updated_at": "2026-01-01T00:00:00+00:00",
        ])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(Todo.self, from: data)
    }

    private func makeCurrentItem(id: Int64 = 1, todoId: Int64 = 1, position: Int = 0) -> CurrentListItem {
        let data = try! JSONSerialization.data(withJSONObject: [
            "id": id, "user_id": testUserId.uuidString, "todo_id": todoId,
            "position": position,
            "created_at": "2026-01-01T00:00:00+00:00",
            "updated_at": "2026-01-01T00:00:00+00:00",
        ])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(CurrentListItem.self, from: data)
    }

    func testClearCurrent_callsServiceAndClearsItems() async {
        let item = makeCurrentItem(todoId: 1)
        sut.currentItems = [item]

        var clearCalled = false
        mockCurrent.clearCurrentHandler = { _ in clearCalled = true }

        let success = await sut.clearCurrent(userId: testUserId)

        XCTAssertTrue(success)
        XCTAssertTrue(clearCalled)
        XCTAssertTrue(sut.currentItems.isEmpty)
    }

    func testLoad_populatesState() async {
        let list = makeList(id: 1)
        let todo = makeTodo(id: 10, listId: 1)
        let item = makeCurrentItem(todoId: 10)

        mockLists.fetchListsHandler = { _, _ in [list] }
        mockTodos.fetchTodosListIdsHandler = { _ in [todo] }
        mockCurrent.fetchCurrentItemsHandler = { _ in [item] }

        await sut.load(workspaceId: testWorkspaceId, userId: testUserId)

        XCTAssertEqual(sut.lists.count, 1)
        XCTAssertEqual(sut.allTodos.count, 1)
        XCTAssertEqual(sut.currentItems.count, 1)
    }
}
