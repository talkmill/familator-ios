import SwiftUI

struct NotesView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var workspaceVM: WorkspaceViewModel
    @StateObject private var viewModel = NotesViewModel()

    @StateObject private var formattingState = TipTapFormattingState()
    @StateObject private var commandSink = TipTapCommandSink()
    @Environment(\.scenePhase) private var scenePhase

    @State private var noteTitle = ""
    @State private var editorHeight: CGFloat = 220
    @State private var selectedLinkIds: Set<Int64> = []
    @State private var initialLinkedTodoIds: Set<Int64> = []
    @State private var todosForLinking: [Todo] = []
    @State private var linksSheetPresented = false

    private let todosService = TodosService()
    private let notesService: NotesServiceProtocol

    init(notesService: NotesServiceProtocol = NotesService()) {
        self.notesService = notesService
    }

    /// Approximate height for the List (picker + notes) so it doesn't scroll
    /// independently inside the outer ScrollView.
    private var listHeight: CGFloat {
        let pickerRow: CGFloat = 88 // section header + picker row + padding
        let noteRows = CGFloat(max(viewModel.noteSummaries.count, 1)) * 56
        let notesHeader: CGFloat = 40
        return pickerRow + notesHeader + noteRows + 32
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isBlockingLoad {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // List picker + notes list in a grouped-style container
                            List {
                                listPickerSection
                                notesSection
                            }
                            .listStyle(.insetGrouped)
                            .scrollDisabled(true)
                            .frame(height: listHeight)

                            // Detail section lives outside the List so the WKWebView
                            // receives touch events (List/UITableView intercepts them).
                            detailSection
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WorkspaceNavButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isRefreshing { ProgressView() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New note") {
                        Task { await viewModel.createNote() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canWriteSelectedList || viewModel.selectedListId == nil)
                }
            }
            .sheet(isPresented: $linksSheetPresented) {
                NavigationStack {
                    List {
                        ForEach(todosForLinking) { todo in
                            Button {
                                toggleLinked(todoId: todo.id)
                            } label: {
                                HStack {
                                    Image(systemName: selectedLinkIds.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                                    VStack(alignment: .leading) {
                                        Text(todo.title)
                                        Text(todo.status.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Link tasks")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { linksSheetPresented = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task { await saveLinkedTodos() }
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Notes", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong.")
            }
            .task {
                await viewModel.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id)
            }
            .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
                Task { await viewModel.load(workspaceId: workspaceVM.activeWorkspaceId, userId: auth.currentUser?.id) }
            }
            .onChange(of: viewModel.selectedNote?.id) { newId in
                if newId == nil {
                    noteTitle = ""
                    return
                }
                guard let note = viewModel.selectedNote, note.id == newId else { return }
                noteTitle = note.title
            }
            .onChange(of: scenePhase) { phase in
                if phase == .inactive || phase == .background {
                    Task { await viewModel.flushContent() }
                }
            }
            .onChange(of: noteTitle) { _ in
                guard viewModel.canWriteSelectedList, viewModel.selectedNote != nil else { return }
                viewModel.persistTitleDebounced(noteTitle)
            }
        }
    }

    private var listPickerSection: some View {
        Section("List") {
            Picker("List", selection: Binding(
                get: { viewModel.selectedListId ?? -1 },
                set: { newValue in
                    guard newValue > 0 else { return }
                    Task { await viewModel.selectList(newValue, userId: auth.currentUser?.id) }
                }
            )) {
                ForEach(viewModel.lists) { list in
                    Text(list.name).tag(list.id)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            if viewModel.noteSummaries.isEmpty {
                Text("No notes yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.noteSummaries) { summary in
                    Button {
                        Task { await viewModel.selectNote(id: summary.id) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.title)
                                Text(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedNote?.id == summary.id {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailSection: some View {
        if viewModel.selectedNote == nil {
            Text("Select a note to view details.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 24)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Detail")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("Title", text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.flushTitle(noteTitle) }
                    }
                    .disabled(!viewModel.canWriteSelectedList)

                TipTapToolbar(formattingState: formattingState, commandSink: commandSink, isEditable: viewModel.canWriteSelectedList)

                TipTapWebView(
                    contentJSON: viewModel.selectedNote?.content ?? Note.emptyDocument,
                    isEditable: viewModel.canWriteSelectedList,
                    formattingState: formattingState,
                    onContentChanged: { json in
                        viewModel.persistContentDebounced(json)
                    },
                    onBlur: {
                        Task { await viewModel.flushContent() }
                    },
                    commandSink: commandSink,
                    contentId: "\(viewModel.selectedNote?.id ?? -1)",
                    dynamicHeight: $editorHeight
                )
                .frame(height: editorHeight)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                )

                if !viewModel.linkedTodos.isEmpty {
                    Text("Linked tasks")
                        .font(.headline)
                    ForEach(viewModel.linkedTodos) { todo in
                        NavigationLink {
                            TodoDetailView(todoId: todo.id)
                                .environmentObject(auth)
                        } label: {
                            HStack {
                                Text(todo.title)
                                Spacer()
                                Text(todo.status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if viewModel.canWriteSelectedList {
                    Button("Edit linked tasks") {
                        Task { await openLinkEditor() }
                    }

                    Button("Delete note", role: .destructive) {
                        Task { await viewModel.deleteSelectedNote() }
                    }
                }
            }
        }
    }

    private func openLinkEditor() async {
        guard let listId = viewModel.selectedListId else { return }
        do {
            todosForLinking = try await todosService.fetchTodos(listId: listId)
            let linked = Set(viewModel.linkedTodos.map(\.id))
            initialLinkedTodoIds = linked
            selectedLinkIds = linked
            linksSheetPresented = true
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                viewModel.errorMessage = message
            }
        }
    }

    private func saveLinkedTodos() async {
        guard let note = viewModel.selectedNote else { return }
        do {
            let toggledTodoIds = initialLinkedTodoIds.symmetricDifference(selectedLinkIds)
            for todoId in toggledTodoIds {
                var current = try await notesService.fetchLinkedNoteIds(todoId: todoId)
                if selectedLinkIds.contains(todoId) {
                    if !current.contains(note.id) {
                        current.append(note.id)
                    }
                } else {
                    current.removeAll { $0 == note.id }
                }
                try await notesService.replaceNoteLinks(todoId: todoId, listId: note.listId, noteIds: current)
            }
            linksSheetPresented = false
            await viewModel.selectNote(id: note.id)
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                viewModel.errorMessage = message
            }
        }
    }

    private func toggleLinked(todoId: Int64) {
        if selectedLinkIds.contains(todoId) {
            selectedLinkIds.remove(todoId)
        } else {
            selectedLinkIds.insert(todoId)
        }
    }

}
