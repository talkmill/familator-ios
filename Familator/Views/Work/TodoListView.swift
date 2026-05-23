import SwiftUI

struct TodoListView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.scenePhase) private var scenePhase
    private let listId: Int64
    @StateObject private var model: TodoListViewModel

    @State private var showAddTodo = false
    @State private var showEditList = false
    @State private var editingTodo: Todo?
    @State private var showCompleted = false
    private let pollIntervalNanoseconds: UInt64 = 30_000_000_000

    init(listId: Int64) {
        self.listId = listId
        _model = StateObject(wrappedValue: TodoListViewModel(listId: listId))
    }

    var body: some View {
        Group {
            if model.isBlockingLoad {
                ProgressView()
            } else {
                List {
                    ForEach(displayTodos) { todo in
                        TodoRowView(todo: todo, onToggle: {
                            Task { await model.toggleTodo(todo) }
                        }, onDelete: {
                            Task { await model.deleteTodo(todo) }
                        }, onEdit: {
                            editingTodo = todo
                        }, isInCurrent: model.isInCurrent(todo.id), onToggleCurrent: {
                            Task {
                                if model.isInCurrent(todo.id) {
                                    await model.removeFromCurrent(userId: auth.currentUser?.id, todoId: todo.id)
                                } else {
                                    await model.addToCurrent(userId: auth.currentUser?.id, todoId: todo.id)
                                }
                            }
                        })
                    }
                }
            }
        }
        .navigationTitle(model.list?.name ?? "Tasks")
        .toolbar {
            if model.isRefreshing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProgressView()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add") { showAddTodo = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle(isOn: $showCompleted) {
                    Label(showCompleted ? "Hide completed" : "Show completed", systemImage: showCompleted ? "checkmark.circle.fill" : "circle")
                }
                .toggleStyle(.button)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Edit list") { showEditList = true }
            }
        }
        .sheet(isPresented: $showAddTodo) {
            AddTodoView(listId: listId) { todo in
                model.todos.insert(todo, at: 0)
                showAddTodo = false
            }
            .environmentObject(auth)
        }
        .sheet(isPresented: $showEditList) {
            if let list = model.list {
                EditListView(list: list) {
                    showEditList = false
                    Task { await model.load(userId: auth.currentUser?.id) }
                }
                .environmentObject(auth)
            }
        }
        .sheet(item: $editingTodo) { todo in
            EditTodoView(todo: todo) {
                editingTodo = nil
                Task { await model.load(userId: auth.currentUser?.id) }
                NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
            }
            .environmentObject(auth)
        }
        .task { await model.load(userId: auth.currentUser?.id) }
        .task(id: auth.currentUser?.id) {
            guard auth.currentUser?.id != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await model.load(userId: auth.currentUser?.id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load(userId: auth.currentUser?.id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            Task { await model.load(userId: auth.currentUser?.id) }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task { await model.load(userId: auth.currentUser?.id) }
            }
        }
    }

    private var displayTodos: [Todo] {
        showCompleted ? model.todos : model.todos.filter { $0.status != Todo.statusCompleted }
    }
}

struct TodoRowView: View {
    let todo: Todo
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let isInCurrent: Bool
    let onToggleCurrent: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.status == Todo.statusCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading) {
                Text(todo.title)
                    .strikethrough(todo.status == Todo.statusCompleted)
                TaskContextChipsView(contexts: todo.contexts)
                if let due = todo.dueDate {
                    Text(due, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onToggleCurrent) {
                Label(
                    isInCurrent ? "Remove from Current" : "Add to Current",
                    systemImage: isInCurrent ? "bolt.slash" : "bolt"
                )
            }
            .tint(isInCurrent ? .orange : .blue)
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
}
