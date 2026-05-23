import SwiftUI

struct ChecklistTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: ChecklistViewModel
    @State private var showAddForm = false
    @State private var editingTodoId: Int64?
    @State private var editDraft = ""

    init(listId: Int64) {
        _model = StateObject(wrappedValue: ChecklistViewModel(listId: listId))
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            if let error = model.errorMessage {
                errorBanner(error)
            }
            if model.isBlockingLoad {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                itemsList
            }
            addItemSection
        }
        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load() }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task { await model.load() }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * model.progressFraction, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: model.progressFraction)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(model.completedCount)/\(model.totalCount) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal)
            .padding(.vertical, 4)
    }

    // MARK: - Items List

    private var itemsList: some View {
        List {
            ForEach(model.todos) { todo in
                ChecklistItemRow(
                    todo: todo,
                    isEditing: editingTodoId == todo.id,
                    editDraft: editingTodoId == todo.id ? $editDraft : .constant(""),
                    onToggle: {
                        Task { await model.toggleCompletion(todo) }
                    },
                    onTapTitle: {
                        editDraft = todo.title
                        editingTodoId = todo.id
                    },
                    onCommitRename: {
                        let trimmed = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        editingTodoId = nil
                        guard !trimmed.isEmpty, trimmed != todo.title else { return }
                        Task { await model.rename(todo, to: trimmed) }
                    },
                    onCancelRename: {
                        editingTodoId = nil
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let todo = model.todos[index]
                    Task { await model.delete(todo) }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Add Item

    private var addItemSection: some View {
        VStack(spacing: 0) {
            Divider()
            if showAddForm {
                AddChecklistItemForm(
                    onAdd: { title, kind in
                        Task {
                            await model.addItem(title: title, kind: kind)
                            showAddForm = false
                        }
                    },
                    onCancel: { showAddForm = false }
                )
            } else {
                Button {
                    showAddForm = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add item")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
    }
}

// MARK: - Checklist Item Row

struct ChecklistItemRow: View {
    let todo: Todo
    let isEditing: Bool
    @Binding var editDraft: String
    let onToggle: () -> Void
    let onTapTitle: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void

    @FocusState private var isFocused: Bool

    private var isDone: Bool { todo.status == Todo.statusCompleted }

    private var kindEnum: TodoKind? {
        todo.kind.flatMap { TodoKind(rawValue: $0) }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Kind icon
            if let kind = kindEnum {
                Image(systemName: kind.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Title (inline-editable)
            if isEditing {
                TextField("Title", text: $editDraft, onCommit: onCommitRename)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .submitLabel(.done)
            } else {
                Text(todo.title)
                    .font(.subheadline)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .onTapGesture(perform: onTapTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Add Checklist Item Form

struct AddChecklistItemForm: View {
    let onAdd: (String, TodoKind) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var selectedKind: TodoKind = .task
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Kind picker
            HStack(spacing: 8) {
                ForEach(TodoKind.allCases) { kind in
                    Button {
                        selectedKind = kind
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: kind.systemImage)
                                .font(.caption2)
                            Text(kind.label)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedKind == kind ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                        )
                        .foregroundStyle(selectedKind == kind ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Title field
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { submitIfValid() }
                .onAppear { titleFocused = true }

            // Actions
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundStyle(.secondary)
                Button("Add") { submitIfValid() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.medium)
            }
        }
        .padding()
    }

    private func submitIfValid() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed, selectedKind)
    }
}
