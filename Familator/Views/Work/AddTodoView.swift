import SwiftUI

struct AddTodoView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss
    let listId: Int64
    @State private var title = ""
    @State private var description = ""
    @State private var priority = Todo.priorityMedium
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var noteSummaries: [NoteSummary] = []
    @State private var selectedNoteIds: Set<Int64> = []
    @State private var contexts: [TaskContext] = []
    @State private var selectedContextIds: Set<Int64> = []
    @State private var newContextName = ""
    var onAdded: (Todo) -> Void

    private let todosService: TodosServiceProtocol
    private let notesService: NotesServiceProtocol
    private let contextsService: ContextsServiceProtocol

    init(listId: Int64, onAdded: @escaping (Todo) -> Void, todosService: TodosServiceProtocol = TodosService(), notesService: NotesServiceProtocol = NotesService(), contextsService: ContextsServiceProtocol = ContextsService()) {
        self.listId = listId
        self.onAdded = onAdded
        self.todosService = todosService
        self.notesService = notesService
        self.contextsService = contextsService
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description (optional)", text: $description)
                Picker("Priority", selection: $priority) {
                    Text("Low").tag(Todo.priorityLow)
                    Text("Medium").tag(Todo.priorityMedium)
                    Text("High").tag(Todo.priorityHigh)
                }
                Toggle("Add due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
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
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                Section {
                    Button("Add") {
                        Task { await add() }
                    }
                    .disabled(isLoading || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isLoading { ProgressView() }
            }
            .task {
                await loadNotes()
                await loadContexts()
            }
        }
    }

    private func loadNotes() async {
        do {
            noteSummaries = try await notesService.fetchNoteSummaries(listId: listId)
        } catch {
            noteSummaries = []
        }
    }

    private func add() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let parsed = parseInlineDateTokens(trimmedTitle)
            var todo = try await todosService.createTodo(
                listId: listId,
                title: parsed.title,
                description: description.isEmpty ? nil : description,
                priority: priority,
                dueDate: parsed.dueDate ?? (hasDueDate ? dueDate : nil),
                plannedDate: parsed.plannedDate,
                noteIds: Array(selectedNoteIds).sorted(),
                kind: nil
            )
            let selectedContexts = contexts.filter { selectedContextIds.contains($0.id) }
            if let userId = auth.currentUser?.id {
                do {
                    try await contextsService.setTodoContexts(
                        todoId: todo.id,
                        userId: userId,
                        contextIds: Array(selectedContextIds).sorted()
                    )
                    todo.contexts = selectedContexts
                } catch {
                    // Keep add flow successful even if context sync fails to avoid duplicate tasks on retry.
                }
            }
            onAdded(todo)
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

    private func parseInlineDateTokens(_ input: String) -> (title: String, dueDate: Date?, plannedDate: Date?) {
        let pattern = #"\b(due|plan):(\d{4}-\d{2}-\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return (input, nil, nil)
        }

        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, options: [], range: fullRange)

        var dueDate: Date?
        var plannedDate: Date?
        var stripped = input
        var acceptedTokenRanges: [NSRange] = []

        for match in matches {
            guard
                let tokenRange = Range(match.range(at: 1), in: input),
                let dateRange = Range(match.range(at: 2), in: input)
            else {
                continue
            }

            let token = input[tokenRange].lowercased()
            let dateString = String(input[dateRange])

            guard let parsedDate = parseISODate(dateString) else { continue }
            if token == "due" { dueDate = parsedDate }
            if token == "plan" { plannedDate = parsedDate }
            acceptedTokenRanges.append(match.range(at: 0))
        }

        for range in acceptedTokenRanges.sorted(by: { $0.location > $1.location }) {
            if let wholeRangeInStripped = Range(range, in: stripped) {
                stripped.replaceSubrange(wholeRangeInStripped, with: " ")
            }
        }

        let normalizedTitle = stripped
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (normalizedTitle.isEmpty ? input : normalizedTitle, dueDate, plannedDate)
    }

    private func parseISODate(_ value: String) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3 else { return nil }
        guard
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }

        let calendar = Calendar(identifier: .gregorian)
        let utcTimeZone = TimeZone(secondsFromGMT: 0)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.calendar = calendar
        components.timeZone = utcTimeZone

        guard let date = components.date else { return nil }
        var verifyCalendar = calendar
        verifyCalendar.timeZone = utcTimeZone ?? .gmt
        let normalized = verifyCalendar.dateComponents([.year, .month, .day], from: date)
        guard normalized.year == year, normalized.month == month, normalized.day == day else {
            return nil
        }
        return date
    }
}
