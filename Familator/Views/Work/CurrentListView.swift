import SwiftUI

struct CurrentListView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @StateObject private var model = CurrentListViewModel()

    @State private var showCompleted = false
    @State private var clearConfirming = false
    @State private var clearingCurrent = false
    @State private var editingTodo: Todo?

    var body: some View {
        Group {
            if model.isBlockingLoad {
                ProgressView()
            } else {
                List {
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    if displayTodos.isEmpty {
                        Text("No tasks in Current.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayTodos) { todo in
                            row(todo: todo)
                        }
                    }
                }
            }
        }
        .navigationTitle("Current")
        .toolbar {
            ToolbarItem(placement: .principal) {
                WorkspaceNavButton()
            }
            if model.isRefreshing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProgressView()
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle(isOn: $showCompleted) {
                    Label(showCompleted ? "Hide completed" : "Show completed", systemImage: showCompleted ? "checkmark.circle.fill" : "circle")
                }
                .toggleStyle(.button)
            }
            ToolbarItem(placement: .primaryAction) {
                if !clearConfirming {
                    Button("Clear Current") { clearConfirming = true }
                        .disabled(displayTodos.isEmpty || clearingCurrent)
                } else {
                    HStack(spacing: 10) {
                        Button(clearingCurrent ? "Clearing..." : "Confirm clear") {
                            Task {
                                clearingCurrent = true
                                let cleared = await model.clearCurrent(userId: auth.currentUser?.id)
                                clearingCurrent = false
                                if cleared {
                                    clearConfirming = false
                                }
                            }
                        }
                        .disabled(clearingCurrent)

                        Button("Cancel") {
                            clearConfirming = false
                        }
                        .disabled(clearingCurrent)
                    }
                }
            }
        }
        .refreshable { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        .task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        .onChange(of: clearConfirming) { isConfirming in
            if isConfirming {
                model.clearError()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        }
        .navigationDestination(for: Int64.self) { todoId in
            TodoDetailView(todoId: todoId)
                .environmentObject(auth)
        }
        .sheet(item: $editingTodo) { todo in
            EditTodoView(todo: todo) {
                editingTodo = nil
                Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
                NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
            }
            .environmentObject(auth)
        }
    }

    private var displayTodos: [Todo] {
        model.orderedTodos(showCompleted: showCompleted)
    }

    private func row(todo: Todo) -> some View {
        HStack {
            Button(action: { Task { await model.toggleTodo(todo) } }) {
                Image(systemName: todo.status == Todo.statusCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            NavigationLink(value: todo.id) {
                VStack(alignment: .leading) {
                    Text(todo.title)
                        .strikethrough(todo.status == Todo.statusCompleted)
                    if let due = todo.dueDate ?? todo.plannedDate {
                        Text(due, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let list = model.listForTodo(todo) {
                        Text(list.name)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                Task { await model.removeFromCurrent(userId: auth.currentUser?.id, todoId: todo.id) }
            } label: {
                Label("Remove", systemImage: "minus.circle")
            }
            .tint(.orange)

            Button {
                editingTodo = todo
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
}

