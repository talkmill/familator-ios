import SwiftUI

struct TripNotesView: View {
    let listId: Int64

    @StateObject private var model: TripNotesViewModel
    @StateObject private var formattingState = TipTapFormattingState()
    @StateObject private var commandSink = TipTapCommandSink()
    @Environment(\.scenePhase) private var scenePhase

    @State private var noteTitle = ""
    @State private var editorHeight: CGFloat = 220
    @State private var noteIdToDelete: Int64?
    @State private var showDeleteConfirmation = false

    init(listId: Int64) {
        self.listId = listId
        _model = StateObject(wrappedValue: TripNotesViewModel(listId: listId))
    }

    private var listHeight: CGFloat {
        let noteRows = CGFloat(max(model.noteSummaries.count, 1)) * 56
        let header: CGFloat = 40
        let newNoteButton: CGFloat = 44
        return header + noteRows + newNoteButton + 16
    }

    var body: some View {
        Group {
            if model.isBlockingLoad {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    notesList
                    detailSection
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
        }
        .alert("Notes", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in if !isPresented { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "Something went wrong.")
        }
        .alert("Delete note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let id = noteIdToDelete {
                    Task { await model.deleteNote(id: id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .familatorDataDidChange)) { _ in
            Task { await model.load() }
        }
        .onChange(of: model.selectedNote?.id) { newId in
            if newId == nil {
                noteTitle = ""
                return
            }
            guard let note = model.selectedNote, note.id == newId else { return }
            noteTitle = note.title
        }
        .onChange(of: scenePhase) { phase in
            if phase == .inactive || phase == .background {
                Task { await model.flushContent() }
            }
        }
        .onChange(of: noteTitle) { _ in
            guard model.selectedNote != nil else { return }
            model.persistTitleDebounced(noteTitle)
        }
    }

    private var deleteMessage: String {
        guard let id = noteIdToDelete,
              let summary = model.noteSummaries.first(where: { $0.id == id })
        else { return "This note will be permanently deleted." }
        return "\"\(summary.title)\" will be permanently deleted."
    }

    // MARK: - Notes List

    private var notesList: some View {
        List {
            Section {
                if model.noteSummaries.isEmpty {
                    Text("No notes yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.noteSummaries) { summary in
                        noteRow(summary)
                    }
                }

                Button {
                    Task { await model.createNote() }
                } label: {
                    Label("New note", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Notes")
                    Spacer()
                    if model.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .frame(height: listHeight)
    }

    private func noteRow(_ summary: NoteSummary) -> some View {
        Button {
            Task { await model.selectNote(id: summary.id) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                    Text(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.selectedNote?.id == summary.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                noteIdToDelete = summary.id
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailSection: some View {
        if model.selectedNote == nil {
            Text("Select a note to view details.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 24)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await model.flushTitle(noteTitle) }
                    }

                TipTapToolbar(formattingState: formattingState, commandSink: commandSink, isEditable: true)

                TipTapWebView(
                    contentJSON: model.selectedNote?.content ?? Note.emptyDocument,
                    isEditable: true,
                    formattingState: formattingState,
                    onContentChanged: { json in
                        model.persistContentDebounced(json)
                    },
                    onBlur: {
                        Task { await model.flushContent() }
                    },
                    commandSink: commandSink,
                    contentId: "\(model.selectedNote?.id ?? -1)",
                    dynamicHeight: $editorHeight
                )
                .frame(height: editorHeight)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                )

                Button("Delete note", role: .destructive) {
                    if let note = model.selectedNote {
                        noteIdToDelete = note.id
                        showDeleteConfirmation = true
                    }
                }
            }
        }
    }
}
