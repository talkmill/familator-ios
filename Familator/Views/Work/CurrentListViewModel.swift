import Foundation
import SwiftUI

@MainActor
final class CurrentListViewModel: ObservableObject {
    @Published var lists: [FamilatorList] = []
    @Published var allTodos: [Todo] = []
    @Published var currentItems: [CurrentListItem] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private var cachedUserId: String?
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0

    private let listsService: ListsServiceProtocol
    private let todosService: TodosServiceProtocol
    private let currentListService: CurrentListServiceProtocol

    init(listsService: ListsServiceProtocol = ListsService(), todosService: TodosServiceProtocol = TodosService(), currentListService: CurrentListServiceProtocol = CurrentListService()) {
        self.listsService = listsService
        self.todosService = todosService
        self.currentListService = currentListService
    }

    func reset() {
        lists = []
        allTodos = []
        currentItems = []
        cachedUserId = nil
        initialLoadAttemptCompleted = false
        loadSequence &+= 1
        isBlockingLoad = false
        isRefreshing = false
        errorMessage = nil
    }

    func load(workspaceId: String?, userId: UUID?) async {
        guard let userId, let workspaceId else {
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
            let fetchedLists = try await listsService.fetchLists(workspaceId: workspaceId, userId: userId)
            guard sequence == loadSequence else { return }

            let fetchedCurrent = try await currentListService.fetchCurrentItems(userId: userId)
            guard sequence == loadSequence else { return }

            let listIds = fetchedLists.map(\.id)
            let fetchedTodos: [Todo]
            if listIds.isEmpty {
                fetchedTodos = []
            } else {
                fetchedTodos = try await todosService.fetchTodos(listIds: listIds)
            }
            guard sequence == loadSequence else { return }
            lists = fetchedLists
            currentItems = fetchedCurrent
            allTodos = fetchedTodos
            cachedUserId = userKey
            errorMessage = nil
        } catch {
            guard sequence == loadSequence else { return }
            errorMessage = "Could not load Current tasks."
        }
    }

    func clearCurrent(userId: UUID?) async -> Bool {
        guard let userId else { return false }
        let snapshot = currentItems
        do {
            try await currentListService.clearCurrent(userId: userId)
            currentItems = []
            errorMessage = nil
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
            return true
        } catch {
            currentItems = snapshot
            errorMessage = "Failed to clear Current."
            return false
        }
    }

    func removeFromCurrent(userId: UUID?, todoId: Int64) async {
        guard let userId else { return }
        let snapshot = currentItems
        currentItems.removeAll { $0.todoId == todoId }
        do {
            try await currentListService.removeTodo(userId: userId, todoId: todoId)
            errorMessage = nil
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            currentItems = snapshot
            errorMessage = "Failed to remove task from Current."
        }
    }

    func toggleTodo(_ todo: Todo) async {
        let newStatus = todo.status == Todo.statusCompleted ? Todo.statusPending : Todo.statusCompleted
        let oldStatus = todo.status
        do {
            try await todosService.updateTodo(id: todo.id, update: TodoUpdate(status: newStatus))
            if let idx = allTodos.firstIndex(where: { $0.id == todo.id }) {
                allTodos[idx].status = newStatus
            }
            errorMessage = nil
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if let idx = allTodos.firstIndex(where: { $0.id == todo.id }) {
                allTodos[idx].status = oldStatus
            }
            errorMessage = "Failed to update task status."
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func listForTodo(_ todo: Todo) -> FamilatorList? {
        lists.first { $0.id == todo.listId }
    }

    func orderedTodos(showCompleted: Bool) -> [Todo] {
        let todoById = Dictionary(uniqueKeysWithValues: allTodos.map { ($0.id, $0) })
        let rows = currentItems.compactMap { item -> Todo? in
            guard let todo = todoById[item.todoId] else { return nil }
            if !showCompleted && todo.status == Todo.statusCompleted { return nil }
            return todo
        }
        return rows
    }
}

