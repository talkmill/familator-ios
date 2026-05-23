import SwiftUI

struct TodoDetailView: View {
    @EnvironmentObject var auth: AuthService
    let todoId: Int64

    @State private var todo: Todo?
    @State private var subtasks: [Subtask] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var completing = false
    @State private var editingTodo: Todo?
    @State private var newSubtaskTitle = ""
    @State private var addingSubtask = false
    @State private var linkedNotes: [NoteSummary] = []

    private let todosService = TodosService()
    private let notesService = NotesService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if todo == nil {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Task not found")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let todo {
                List {
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Text(todo.title)
                            .font(.title2.weight(.bold))
                        if let d = todo.description, !d.isEmpty {
                            Text(d)
                                .foregroundStyle(.secondary)
                        }
                        if let p = todo.priority {
                            Text("Priority: \(p)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let planned = todo.plannedDate {
                            Text("Planned: \(planned.formatted(date: .abbreviated, time: .omitted))")
                        }
                        if let due = todo.dueDate {
                            Text("Due: \(due.formatted(date: .abbreviated, time: .omitted))")
                        }
                        if todo.hasRecurrencePayload {
                            Text(todo.recurrence?.summaryLabel() ?? "Repeating task")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(todo.isRecurrencePaused ? "Repeat: paused" : "Repeat: active")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !todo.contexts.isEmpty {
                            TaskContextChipsView(contexts: todo.contexts)
                        }
                        if todo.status == Todo.statusPending {
                            Button {
                                Task { await markComplete(todo) }
                            } label: {
                                if completing {
                                    ProgressView()
                                } else {
                                    Text("Mark complete")
                                }
                            }
                            .disabled(completing)
                        }
                    }

                    Section("Subtasks") {
                        HStack {
                            TextField("New subtask", text: $newSubtaskTitle)
                            Button("Add") {
                                Task { await addSubtask() }
                            }
                            .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || addingSubtask)
                        }

                        if subtasks.isEmpty {
                            Text("No subtasks yet")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(subtasks) { sub in
                                Button {
                                    Task { await toggleSubtask(sub) }
                                } label: {
                                    HStack {
                                        Text(sub.status == Subtask.statusCompleted ? "✓" : "○")
                                            .frame(width: 24, alignment: .leading)
                                        Text(sub.title)
                                            .strikethrough(sub.status == Subtask.statusCompleted)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }

                    if !linkedNotes.isEmpty {
                        Section("Linked notes") {
                            ForEach(linkedNotes) { note in
                                Text(note.title)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let t = todo {
                    Button("Edit") {
                        editingTodo = t
                    }
                }
            }
        }
        .sheet(item: $editingTodo) { t in
            EditTodoView(todo: t) {
                editingTodo = nil
                NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
                Task { await load() }
            }
            .environmentObject(auth)
        }
        .task { await load() }
    }

    private func load() async {
        guard auth.currentUser?.id != nil else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let t = try await todosService.fetchTodo(id: todoId) else {
                todo = nil
                subtasks = []
                return
            }
            todo = t
            subtasks = try await todosService.fetchSubtasks(todoId: todoId)
            let noteIds = try await notesService.fetchLinkedNoteIds(todoId: todoId)
            if noteIds.isEmpty {
                linkedNotes = []
            } else {
                linkedNotes = try await notesService.fetchNoteSummaries(noteIds: noteIds)
            }
        } catch {
            errorMessage = error.localizedDescription
            todo = nil
            subtasks = []
            linkedNotes = []
        }
    }

    private func markComplete(_ t: Todo) async {
        completing = true
        defer { completing = false }
        do {
            try await todosService.updateTodo(id: t.id, update: TodoUpdate(status: Todo.statusCompleted))
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleSubtask(_ sub: Subtask) async {
        let next = sub.status == Subtask.statusCompleted ? Subtask.statusPending : Subtask.statusCompleted
        do {
            try await todosService.updateSubtask(id: sub.id, title: nil, status: next)
            if let i = subtasks.firstIndex(where: { $0.id == sub.id }) {
                subtasks[i].status = next
            }
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addSubtask() async {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        addingSubtask = true
        defer { addingSubtask = false }
        do {
            let sub = try await todosService.addSubtask(todoId: todoId, title: title)
            subtasks.append(sub)
            newSubtaskTitle = ""
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
