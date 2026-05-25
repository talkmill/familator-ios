import XCTest
@testable import Familator

@MainActor
final class TodoListViewModelTests: XCTestCase {
    private var mockLists: MockListsService!
    private var mockTodos: MockTodosService!
    private var mockCurrent: MockCurrentListService!
    private var sut: TodoListViewModel!
    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        mockLists = MockListsService()
        mockTodos = MockTodosService()
        mockCurrent = MockCurrentListService()
        sut = TodoListViewModel(
            listId: 1,
            listsService: mockLists,
            todosService: mockTodos,
            currentListService: mockCurrent
        )
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

    func testLoad_populatesTodosAndList() async {
        let list = makeList(id: 1, name: "Work")
        let todo = makeTodo(id: 5, listId: 1)

        mockLists.fetchListHandler = { _ in list }
        mockTodos.fetchTodosListHandler = { _ in [todo] }
        mockCurrent.fetchCurrentItemsHandler = { _ in [] }

        await sut.load(userId: testUserId)

        XCTAssertEqual(sut.list?.name, "Work")
        XCTAssertEqual(sut.todos.count, 1)
        XCTAssertEqual(sut.todos.first?.id, 5)
    }

    func testToggleTodo_flipsStatusLocally() async {
        let todo = makeTodo(id: 1, status: Todo.statusPending)
        sut.todos = [todo]

        mockTodos.updateTodoHandler = { _, _ in }

        await sut.toggleTodo(todo)

        XCTAssertEqual(sut.todos.first?.status, Todo.statusCompleted)
        XCTAssertEqual(mockTodos.updateTodoCalls.count, 1)
    }
}
