import XCTest
@testable import Familator

final class ChecklistViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal Todo for testing computed properties.
    /// Uses `JSONDecoder` to go through the real `init(from:)` path.
    private func makeTodo(id: Int64, status: String = Todo.statusPending, kind: String? = nil) -> Todo {
        var fields: [String: Any] = [
            "id": id,
            "list_id": 1,
            "title": "Item \(id)",
            "status": status,
            "created_at": "2026-01-01T00:00:00+00:00",
            "updated_at": "2026-01-01T00:00:00+00:00",
        ]
        if let kind { fields["kind"] = kind }

        let data = try! JSONSerialization.data(withJSONObject: fields)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(Todo.self, from: data)
    }

    // MARK: - Progress computation

    @MainActor
    func testProgressFraction_empty() {
        let vm = ChecklistViewModel(listId: 1)
        XCTAssertEqual(vm.progressFraction, 0)
        XCTAssertEqual(vm.completedCount, 0)
        XCTAssertEqual(vm.totalCount, 0)
    }

    @MainActor
    func testProgressFraction_allPending() {
        let vm = ChecklistViewModel(listId: 1)
        vm.todos = [makeTodo(id: 1), makeTodo(id: 2), makeTodo(id: 3)]
        XCTAssertEqual(vm.completedCount, 0)
        XCTAssertEqual(vm.totalCount, 3)
        XCTAssertEqual(vm.progressFraction, 0, accuracy: 0.001)
    }

    @MainActor
    func testProgressFraction_someCompleted() {
        let vm = ChecklistViewModel(listId: 1)
        vm.todos = [
            makeTodo(id: 1, status: Todo.statusCompleted),
            makeTodo(id: 2),
            makeTodo(id: 3, status: Todo.statusCompleted),
        ]
        XCTAssertEqual(vm.completedCount, 2)
        XCTAssertEqual(vm.totalCount, 3)
        XCTAssertEqual(vm.progressFraction, 2.0 / 3.0, accuracy: 0.001)
    }

    @MainActor
    func testProgressFraction_allCompleted() {
        let vm = ChecklistViewModel(listId: 1)
        vm.todos = [
            makeTodo(id: 1, status: Todo.statusCompleted),
            makeTodo(id: 2, status: Todo.statusCompleted),
        ]
        XCTAssertEqual(vm.progressFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - Kind decoding

    @MainActor
    func testTodoKind_decodesFromJSON() {
        let todo = makeTodo(id: 1, kind: "flight")
        XCTAssertEqual(todo.kind, "flight")
    }

    @MainActor
    func testTodoKind_nilWhenAbsent() {
        let todo = makeTodo(id: 1)
        XCTAssertNil(todo.kind)
    }
}
