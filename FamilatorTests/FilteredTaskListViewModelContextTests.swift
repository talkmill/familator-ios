import XCTest
@testable import Familator

final class FilteredTaskListViewModelContextTests: XCTestCase {
    func testMatchesAllSelectedContextsReturnsTrueWhenNoSelection() throws {
        let todo = try makeTodo(id: 1, contextIds: [10])

        XCTAssertTrue(FilteredTaskListViewModel.matchesAllSelectedContexts(todo: todo, selectedContextIds: []))
    }

    func testMatchesAllSelectedContextsRequiresEverySelectedContext() throws {
        let todo = try makeTodo(id: 2, contextIds: [10, 20])

        XCTAssertTrue(FilteredTaskListViewModel.matchesAllSelectedContexts(todo: todo, selectedContextIds: [10]))
        XCTAssertTrue(FilteredTaskListViewModel.matchesAllSelectedContexts(todo: todo, selectedContextIds: [10, 20]))
        XCTAssertFalse(FilteredTaskListViewModel.matchesAllSelectedContexts(todo: todo, selectedContextIds: [10, 30]))
    }

    private func makeTodo(id: Int64, contextIds: [Int64]) throws -> Todo {
        let json: [String: Any] = [
            "id": id,
            "list_id": 1,
            "title": "Task \(id)",
            "description": NSNull(),
            "status": Todo.statusPending,
            "priority": Todo.priorityMedium,
            "due_date": NSNull(),
            "planned_date": NSNull(),
            "recurrence": NSNull(),
            "recurrence_paused": false,
            "recurrence_series_id": NSNull(),
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z",
            "completed_at": NSNull(),
        ]

        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var todo = try decoder.decode(Todo.self, from: data)
        todo.contexts = contextIds.map { TaskContext(id: $0, name: "c\($0)", createdAt: nil, updatedAt: nil) }
        return todo
    }
}
