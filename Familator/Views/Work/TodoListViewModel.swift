import Foundation
import SwiftUI

@MainActor
final class TodoListViewModel: ObservableObject {
    let listId: Int64

    @Published var list: FamilatorList?
    @Published var todos: [Todo] = []
    @Published var currentItems: [CurrentListItem] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false

    private var cachedUserId: String?
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0

    private let listsService = ListsService()
    private let todosService = TodosService()
    private let currentListService = CurrentListService()

    init(listId: Int64) {
        self.listId = listId
    }

    func reset() {
        list = nil
        todos = []
        currentItems = []
        cachedUserId = nil
        initialLoadAttemptCompleted = false
        loadSequence &+= 1
        isBlockingLoad = false
        isRefreshing = false
    }

    func load(userId: UUID?) async {
        guard let userId else {
            reset()
            return
        }

        let userKey = userId.uuidString.lowercased()
        if let cached = cachedUserId, cached != userKey {
            reset()
        }

        let showBlocking = !initialLoadAttemptCompleted
        loadSequence &+= 1
        let sequence = loadSequence

        if showBlocking {
            isBlockingLoad = true
        } else {
            isRefreshing = true
        }

        defer {
            if sequence == loadSequence {
                initialLoadAttemptCompleted = true
                isBlockingLoad = false
                isRefreshing = false
            }
        }

        do {
            list = try await listsService.fetchList(id: listId)
            let fetched = try await todosService.fetchTodos(listId: listId)
            guard sequence == loadSequence else { return }
            todos = fetched
            currentItems = try await currentListService.fetchCurrentItems(userId: userId)
            guard sequence == loadSequence else { return }
            cachedUserId = userKey
        } catch {
            guard sequence == loadSequence else { return }
        }
    }

    func isInCurrent(_ todoId: Int64) -> Bool {
        currentItems.contains(where: { $0.todoId == todoId })
    }

    func addToCurrent(userId: UUID?, todoId: Int64) async {
        guard let userId else { return }
        do {
            try await currentListService.addTodo(userId: userId, todoId: todoId)
            currentItems = try await currentListService.fetchCurrentItems(userId: userId)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {}
    }

    func removeFromCurrent(userId: UUID?, todoId: Int64) async {
        guard let userId else { return }
        do {
            try await currentListService.removeTodo(userId: userId, todoId: todoId)
            currentItems.removeAll { $0.todoId == todoId }
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {}
    }

    func toggleTodo(_ todo: Todo) async {
        let newStatus = todo.status == Todo.statusCompleted ? Todo.statusPending : Todo.statusCompleted
        do {
            try await todosService.updateTodo(id: todo.id, update: TodoUpdate(status: newStatus))
            if let i = todos.firstIndex(where: { $0.id == todo.id }) {
                todos[i].status = newStatus
            }
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {}
    }

    func deleteTodo(_ todo: Todo) async {
        do {
            try await todosService.deleteTodo(id: todo.id)
            todos.removeAll { $0.id == todo.id }
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {}
    }
}
