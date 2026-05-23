import SwiftUI

struct FilteredTaskListView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let filterKey: String
    @StateObject private var model: FilteredTaskListViewModel

    @State private var showAddTodo = false
    @State private var showCompleted = false
    @State private var editingTodo: Todo?
    @State private var selectedContextIds: Set<Int64> = []
    private let pollIntervalNanoseconds: UInt64 = 30_000_000_000

    init(filterKey: String) {
        self.filterKey = filterKey
        _model = StateObject(wrappedValue: FilteredTaskListViewModel(filterKey: filterKey))
    }

    private var title: String {
        switch filterKey {
        case "due-now": return "Due now"
        case "upcoming": return "Upcoming"
        case "next-week": return "Next week"
        case "all": return "All tasks"
        case "current": return "Current"
        case "routines": return "Recurring"
        default: return filterKey
        }
    }

    var body: some View {
        Group {
            if model.isBlockingLoad {
                ProgressView()
            } else {
                listContent
            }
        }
        .navigationTitle(title)
        .toolbar {
            if model.isRefreshing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProgressView()
                }
            }
            if showsTodoList {
                ToolbarItem(placement: .secondaryAction) {
                    Toggle(isOn: $showCompleted) {
                        Label(showCompleted ? "Hide completed" : "Show completed", systemImage: showCompleted ? "checkmark.circle.fill" : "circle")
                    }
                    .toggleStyle(.button)
                }
            }
            if canAddTodo {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") { showAddTodo = true }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if !model.availableContexts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.availableContexts) { context in
                            Button {
                                toggleContext(context.id)
                            } label: {
                                Text(context.name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedContextIds.contains(context.id) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .background(.thinMaterial)
            }
        }
        .sheet(isPresented: $showAddTodo) {
            if let defaultListId = model.lists.first?.id {
                AddTodoView(listId: defaultListId) { _ in
                    showAddTodo = false
                    Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
                    NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
                }
                .environmentObject(auth)
            }
        }
        .refreshable { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        .task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        .task(id: auth.currentUser?.id) {
            guard auth.currentUser?.id != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
            }
        }
        .navigationDestination(for: Int64.self) { todoId in
            TodoDetailView(todoId: todoId)
                .environmentObject(auth)
        }
        .sheet(item: $editingTodo) { t in
            EditTodoView(todo: t) {
                editingTodo = nil
                Task { await model.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
                NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
            }
            .environmentObject(auth)
        }
    }

    private var canAddTodo: Bool {
        (filterKey == "routines" || filterKey == "current") ? false : !model.lists.isEmpty
    }

    private var showsTodoList: Bool {
        switch filterKey {
        case "due-now", "upcoming", "next-week", "all", "current": return true
        default: return false
        }
    }

    @ViewBuilder
    private var listContent: some View {
        let (todoRows, recurringRows) = model.computedRows()
        let contextFilteredTodoRows = todoRows.filter { matchesSelectedContexts($0) }
        let contextFilteredRecurring = recurringRows.filter { matchesSelectedContexts($0) }
        let displayTodoRows = showCompleted ? contextFilteredTodoRows : contextFilteredTodoRows.filter { $0.status != Todo.statusCompleted }
        if filterKey == "routines" {
            recurringOnlySection(recurringRows: contextFilteredRecurring)
        } else {
            tasksOnlySection(todoRows: displayTodoRows)
        }
    }

    private func recurringOnlySection(recurringRows: [Todo]) -> some View {
        List {
            if recurringRows.isEmpty {
                Text("No recurring tasks.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recurringRows) { todo in
                    recurringTodoRow(todo: todo, onComplete: { Task { await model.toggleTodo(todo) } })
                }
            }
        }
    }

    private func tasksOnlySection(todoRows: [Todo]) -> some View {
        List {
            if todoRows.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todoRows) { todo in
                    todoRow(todo: todo, list: listFor(todo), onComplete: { Task { await model.toggleTodo(todo) } })
                }
            }
        }
    }

    private var emptyMessage: String {
        switch filterKey {
        case "due-now": return "Nothing due right now."
        case "upcoming": return "Nothing upcoming this week."
        case "next-week": return "Nothing due next week."
        case "all": return "No tasks."
        case "current": return "No tasks in Current."
        default: return "No items."
        }
    }

    private func listFor(_ todo: Todo) -> FamilatorList? {
        model.lists.first { $0.id == todo.listId }
    }

    private func todoRow(todo: Todo, list: FamilatorList?, onComplete: @escaping () -> Void) -> some View {
        HStack {
            Button(action: onComplete) {
                Image(systemName: todo.status == Todo.statusCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            NavigationLink(value: todo.id) {
                VStack(alignment: .leading) {
                    Text(todo.title)
                        .strikethrough(todo.status == Todo.statusCompleted)
                    TaskContextChipsView(contexts: todo.contexts)
                    if let due = todo.dueDate ?? todo.plannedDate {
                        Text(due, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let list {
                        Text(list.name)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                Task {
                    if model.isInCurrent(todo.id) {
                        await model.removeFromCurrent(userId: auth.currentUser?.id, todoId: todo.id)
                    } else {
                        await model.addToCurrent(userId: auth.currentUser?.id, todoId: todo.id)
                    }
                }
            } label: {
                Label(
                    model.isInCurrent(todo.id) ? "Remove from Current" : "Add to Current",
                    systemImage: model.isInCurrent(todo.id) ? "bolt.slash" : "bolt"
                )
            }
            .tint(model.isInCurrent(todo.id) ? .orange : .blue)

            Button {
                editingTodo = todo
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: { Task { await model.deleteTodo(todo) } }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func recurringTodoRow(todo: Todo, onComplete: @escaping () -> Void) -> some View {
        HStack {
            Button(action: onComplete) {
                Image(systemName: todo.status == Todo.statusCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            NavigationLink(value: todo.id) {
                VStack(alignment: .leading) {
                    Text(todo.title)
                    TaskContextChipsView(contexts: todo.contexts)
                    if let next = todo.dueDate ?? todo.plannedDate {
                        Text(next, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Repeats")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                Task {
                    if model.isInCurrent(todo.id) {
                        await model.removeFromCurrent(userId: auth.currentUser?.id, todoId: todo.id)
                    } else {
                        await model.addToCurrent(userId: auth.currentUser?.id, todoId: todo.id)
                    }
                }
            } label: {
                Label(
                    model.isInCurrent(todo.id) ? "Remove from Current" : "Add to Current",
                    systemImage: model.isInCurrent(todo.id) ? "bolt.slash" : "bolt"
                )
            }
            .tint(model.isInCurrent(todo.id) ? .orange : .blue)

            Button {
                editingTodo = todo
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    private func toggleContext(_ id: Int64) {
        if selectedContextIds.contains(id) {
            selectedContextIds.remove(id)
        } else {
            selectedContextIds.insert(id)
        }
    }

    private func matchesSelectedContexts(_ todo: Todo) -> Bool {
        FilteredTaskListViewModel.matchesAllSelectedContexts(todo: todo, selectedContextIds: selectedContextIds)
    }
}
