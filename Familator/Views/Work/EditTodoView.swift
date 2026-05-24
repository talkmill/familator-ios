import SwiftUI

struct EditTodoView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    let todo: Todo
    var onSaved: () -> Void

    @State private var title: String
    @State private var description: String
    @State private var selectedListId: Int64
    @State private var priority: String?
    @State private var hasPlannedDate = false
    @State private var plannedDate = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var recForm: RecurrenceEditForm
    @State private var lists: [FamilatorList] = []
    @State private var noteSummaries: [NoteSummary] = []
    @State private var selectedNoteIds: Set<Int64> = []
    @State private var contexts: [TaskContext] = []
    @State private var selectedContextIds: Set<Int64> = []
    @State private var newContextName = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let todosService: TodosServiceProtocol
    private let listsService: ListsServiceProtocol
    private let notesService = NotesService()
    private let contextsService = ContextsService()

    init(todo: Todo, onSaved: @escaping () -> Void, todosService: TodosServiceProtocol = TodosService(), listsService: ListsServiceProtocol = ListsService()) {
        self.todo = todo
        self.onSaved = onSaved
        self.todosService = todosService
        self.listsService = listsService
        _title = State(initialValue: todo.title)
        _description = State(initialValue: todo.description ?? "")
        _selectedListId = State(initialValue: todo.listId)
        _priority = State(initialValue: todo.priority)
        let p = todo.plannedDate.map { Calendar.current.startOfDay(for: $0) }
        _hasPlannedDate = State(initialValue: p != nil)
        _plannedDate = State(initialValue: p ?? Date())
        let d = todo.dueDate.map { Calendar.current.startOfDay(for: $0) }
        _hasDueDate = State(initialValue: d != nil)
        _dueDate = State(initialValue: d ?? Date())
        _recForm = State(initialValue: RecurrenceEditForm(todo: todo))
        _selectedContextIds = State(initialValue: Set(todo.contexts.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description (optional)", text: $description, axis: .vertical)
                    .lineLimit(3 ... 8)
                Picker("List", selection: $selectedListId) {
                    ForEach(lists) { list in
                        Text(list.name).tag(list.id)
                    }
                }
                Picker("Priority", selection: $priority) {
                    Text("None").tag(Optional<String>.none)
                    Text("Low").tag(Optional(Todo.priorityLow))
                    Text("Medium").tag(Optional(Todo.priorityMedium))
                    Text("High").tag(Optional(Todo.priorityHigh))
                }
                Toggle("Planned date", isOn: $hasPlannedDate)
                if hasPlannedDate {
                    DatePicker("Planned", selection: $plannedDate, displayedComponents: .date)
                }
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
                if !noteSummaries.isEmpty {
                    Section("Linked notes") {
                        ForEach(noteSummaries) { note in
                            Button {
                                if selectedNoteIds.contains(note.id) {
                                    selectedNoteIds.remove(note.id)
                                } else {
                                    selectedNoteIds.insert(note.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedNoteIds.contains(note.id) ? "checkmark.circle.fill" : "circle")
                                    Text(note.title)
                                }
                            }
                        }
                    }
                }
                TaskContextPickerSection(
                    contexts: $contexts,
                    selectedContextIds: $selectedContextIds,
                    newContextName: $newContextName,
                    onCreateContext: { Task { await createContext() } }
                )

                Section("Repeat") {
                    Toggle("Repeating task", isOn: $recForm.repeatEnabled)
                    if recForm.repeatEnabled {
                        Picker("Repeat type", selection: $recForm.scheduleAfterCompletion) {
                            Text("After complete").tag(true)
                            Text("On schedule").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if recForm.scheduleAfterCompletion {
                            Stepper("Wait: \(recForm.waitValue)", value: $recForm.waitValue, in: 1 ... 999)
                            Picker("Unit", selection: $recForm.waitUnit) {
                                Text("days").tag("days")
                                Text("weeks").tag("weeks")
                                Text("months").tag("months")
                            }
                        } else {
                            Stepper("Every: \(recForm.calEvery)", value: $recForm.calEvery, in: 1 ... 999)
                            Picker("Interval", selection: $recForm.calGranularity) {
                                Text("day(s)").tag("day")
                                Text("week(s)").tag("week")
                                Text("month(s)").tag("month")
                                Text("year(s)").tag("year")
                            }
                            if recForm.calGranularity == "week" {
                                Toggle("Specific weekday (off = simple weekly interval)", isOn: $recForm.useSpecificWeekday)
                                if recForm.useSpecificWeekday {
                                    Picker("Weekday", selection: $recForm.weekday) {
                                        Text("Sunday").tag(0)
                                        Text("Monday").tag(1)
                                        Text("Tuesday").tag(2)
                                        Text("Wednesday").tag(3)
                                        Text("Thursday").tag(4)
                                        Text("Friday").tag(5)
                                        Text("Saturday").tag(6)
                                    }
                                }
                            }
                            if recForm.calGranularity == "month" {
                                Stepper("Day of month: \(recForm.monthlyDay)", value: $recForm.monthlyDay, in: 1 ... 31)
                                Stepper("Every N months: \(recForm.monthlyEvery)", value: $recForm.monthlyEvery, in: 1 ... 24)
                            }
                        }
                        Toggle("Paused (no new instances until resumed)", isOn: $recForm.recPaused)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                Section {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Edit task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isSaving { ProgressView() }
            }
            .task { await loadLists() }
            .onChange(of: selectedListId) { _ in
                Task { await loadNotesAndLinks() }
            }
        }
    }

    private func loadLists() async {
        guard let userId = auth.currentUser?.id,
              let workspaceId = workspaceVM.activeWorkspaceId else { return }
        do {
            lists = try await listsService.fetchLists(workspaceId: workspaceId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadNotesAndLinks()
        await loadContexts()
    }

    private func loadNotesAndLinks() async {
        do {
            noteSummaries = try await notesService.fetchNoteSummaries(listId: selectedListId)
        } catch {
            noteSummaries = []
        }
        let allowedNoteIds = Set(noteSummaries.map(\.id))
        do {
            let linked = try await notesService.fetchLinkedNoteIds(todoId: todo.id)
            selectedNoteIds = Set(linked.filter { allowedNoteIds.contains($0) })
        } catch {
            selectedNoteIds = []
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let hadRule = todo.hasRecurrencePayload
        let builtRule = recForm.buildRecurrenceJSON()

        var update = TodoUpdate(
            title: trimmedTitle,
            description: desc.isEmpty ? nil : desc,
            status: nil,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            plannedDate: hasPlannedDate ? plannedDate : nil,
            listId: selectedListId != todo.listId ? selectedListId : nil,
            removeRecurrence: false,
            recurrence: nil,
            recurrenceSeriesId: nil,
            recurrencePaused: nil,
            noteIds: Array(selectedNoteIds).sorted()
        )

        if recForm.repeatEnabled {
            guard let rule = builtRule, rule.isValidRule else {
                errorMessage = "Check repeat settings."
                return
            }
            update.recurrence = rule
            update.recurrencePaused = recForm.recPaused
            if !hadRule {
                update.recurrenceSeriesId = UUID()
            }
        } else if hadRule {
            update.removeRecurrence = true
        }

        do {
            try await todosService.updateTodo(id: todo.id, update: update)
            if let userId = auth.currentUser?.id {
                do {
                    try await contextsService.setTodoContexts(
                        todoId: todo.id,
                        userId: userId,
                        contextIds: Array(selectedContextIds).sorted()
                    )
                } catch {
                    // Preserve todo edits even if context sync fails.
                }
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadContexts() async {
        guard let userId = auth.currentUser?.id else { return }
        do {
            contexts = try await contextsService.fetchContexts(userId: userId)
        } catch {
            contexts = []
        }
    }

    private func createContext() async {
        guard let userId = auth.currentUser?.id else { return }
        do {
            let created = try await contextsService.createContext(userId: userId, name: newContextName)
            contexts = (contexts + [created]).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            selectedContextIds.insert(created.id)
            newContextName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
