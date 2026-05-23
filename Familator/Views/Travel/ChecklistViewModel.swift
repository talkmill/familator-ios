import Foundation

@MainActor
final class ChecklistViewModel: ObservableObject {
    let listId: Int64

    @Published var todos: [Todo] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let todosService = TodosService()
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0

    init(listId: Int64) {
        self.listId = listId
    }

    var completedCount: Int {
        todos.filter { $0.status == Todo.statusCompleted }.count
    }

    var totalCount: Int {
        todos.count
    }

    var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    func load() async {
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
            let fetched = try await todosService.fetchChecklistTodos(listId: listId)
            guard sequence == loadSequence else { return }
            todos = fetched
            errorMessage = nil
        } catch {
            guard sequence == loadSequence else { return }
            errorMessage = error.localizedDescription
        }
    }

    func addItem(title: String, kind: TodoKind) async {
        do {
            let todo = try await todosService.createTodo(
                listId: listId,
                title: title,
                description: nil,
                priority: nil,
                dueDate: nil,
                plannedDate: nil,
                kind: kind.rawValue
            )
            todos.append(todo)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCompletion(_ todo: Todo) async {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        let newStatus = todo.status == Todo.statusCompleted ? Todo.statusPending : Todo.statusCompleted
        todos[index].status = newStatus
        do {
            try await todosService.updateTodo(id: todo.id, update: TodoUpdate(status: newStatus))
        } catch {
            todos[index].status = todo.status
            errorMessage = error.localizedDescription
        }
    }

    func rename(_ todo: Todo, to newTitle: String) async {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        let oldTitle = todos[index].title
        todos[index].title = newTitle
        do {
            try await todosService.updateTodo(id: todo.id, update: TodoUpdate(title: newTitle))
        } catch {
            todos[index].title = oldTitle
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ todo: Todo) async {
        let snapshot = todos
        todos.removeAll { $0.id == todo.id }
        do {
            try await todosService.deleteTodo(id: todo.id)
        } catch {
            todos = snapshot
            errorMessage = error.localizedDescription
        }
    }

}
