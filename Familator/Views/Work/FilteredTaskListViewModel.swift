import Foundation
import SwiftUI

// MARK: - Date helpers (match web app)

private func toDateOnly(_ d: Date) -> String {
    let cal = Calendar.current
    let y = cal.component(.year, from: d)
    let m = cal.component(.month, from: d)
    let day = cal.component(.day, from: d)
    return String(format: "%04d-%02d-%02d", y, m, day)
}

private func effectiveDueDate(for todo: Todo) -> Date? {
    todo.dueDate ?? todo.plannedDate
}

private func isDueNow(_ date: Date?) -> Bool {
    guard let date else { return false }
    let day = toDateOnly(date)
    let today = toDateOnly(Date())
    return day <= today
}

private func isUpcomingThisWeek(_ date: Date?) -> Bool {
    guard let date else { return false }
    let cal = Calendar.current
    let startOfToday = cal.startOfDay(for: Date())
    guard let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfToday) else { return false }
    let dayStr = toDateOnly(date)
    let todayStr = toDateOnly(Date())
    let endStr = toDateOnly(endOfWeek)
    return dayStr > todayStr && dayStr <= endStr
}

private func isNextWeek(_ date: Date?) -> Bool {
    guard let date else { return false }
    let cal = Calendar.current
    let startOfToday = cal.startOfDay(for: Date())
    guard let weekEnd = cal.date(byAdding: .day, value: 7, to: startOfToday),
          let nextWeekEnd = cal.date(byAdding: .day, value: 14, to: startOfToday) else { return false }
    let startStr = toDateOnly(weekEnd)
    let endStr = toDateOnly(nextWeekEnd)
    let dayStr = toDateOnly(date)
    return dayStr > startStr && dayStr <= endStr
}

// MARK: - View model

@MainActor
final class FilteredTaskListViewModel: ObservableObject {
    let filterKey: String

    @Published var lists: [FamilatorList] = []
    @Published var allTodos: [Todo] = []
    @Published var currentItems: [CurrentListItem] = []
    @Published var availableContexts: [TaskContext] = []

    @Published var isBlockingLoad = false
    @Published var isRefreshing = false

    private var cachedUserId: String?
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0

    private let listsService: ListsServiceProtocol
    private let todosService: TodosServiceProtocol
    private let currentListService: CurrentListServiceProtocol

    init(filterKey: String, listsService: ListsServiceProtocol = ListsService(), todosService: TodosServiceProtocol = TodosService(), currentListService: CurrentListServiceProtocol = CurrentListService()) {
        self.filterKey = filterKey
        self.listsService = listsService
        self.todosService = todosService
        self.currentListService = currentListService
    }

    func reset() {
        lists = []
        allTodos = []
        currentItems = []
        availableContexts = []
        cachedUserId = nil
        initialLoadAttemptCompleted = false
        loadSequence &+= 1
        isBlockingLoad = false
        isRefreshing = false
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
            lists = fetchedLists
            currentItems = try await currentListService.fetchCurrentItems(userId: userId)
            guard sequence == loadSequence else { return }
            let listIds = lists.map(\.id)

            if listIds.isEmpty {
                allTodos = []
                availableContexts = []
            } else {
                let todosList = try await todosService.fetchTodos(listIds: listIds)
                guard sequence == loadSequence else { return }
                allTodos = todosList
                let allContexts = Set(todosList.flatMap(\.contexts))
                availableContexts = allContexts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }

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
            if let i = allTodos.firstIndex(where: { $0.id == todo.id }) {
                allTodos[i].status = newStatus
            }
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {}
    }

    func deleteTodo(_ todo: Todo) async {
        do {
            try await todosService.deleteTodo(id: todo.id)
            allTodos.removeAll { $0.id == todo.id }
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {}
    }

    private func activeRecurring(from todos: [Todo]) -> [Todo] {
        todos.filter(\.isActiveRecurring)
    }

    /// `recurringTodos` is only used for the Recurring filter — not mixed with main rows elsewhere.
    func computedRows() -> (todos: [Todo], recurringTodos: [Todo]) {
        let rec = activeRecurring(from: allTodos)
        switch filterKey {
        case "due-now":
            let dueTodos = allTodos.filter { isDueNow(effectiveDueDate(for: $0)) }
            return (dueTodos, [])
        case "upcoming":
            let upcomingTodos = allTodos.filter { d in
                let date = effectiveDueDate(for: d)
                return isDueNow(date) || isUpcomingThisWeek(date)
            }
            return (upcomingTodos, [])
        case "next-week":
            let nextTodos = allTodos.filter { isNextWeek(effectiveDueDate(for: $0)) }
            return (nextTodos, [])
        case "all":
            return (allTodos, [])
        case "current":
            let todoById = Dictionary(uniqueKeysWithValues: allTodos.map { ($0.id, $0) })
            let ordered = currentItems.compactMap { todoById[$0.todoId] }
            return (ordered, [])
        case "routines":
            let rows = allTodos.filter(\.hasRecurrencePayload).sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            return ([], rows)
        default:
            return ([], [])
        }
    }

    nonisolated static func matchesAllSelectedContexts(todo: Todo, selectedContextIds: Set<Int64>) -> Bool {
        if selectedContextIds.isEmpty {
            return true
        }
        let todoContextIds = Set(todo.contexts.map(\.id))
        return selectedContextIds.allSatisfy { todoContextIds.contains($0) }
    }
}
