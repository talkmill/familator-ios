import Foundation

@MainActor
final class TripNotesViewModel: ObservableObject {
    let listId: Int64

    @Published var noteSummaries: [NoteSummary] = []
    @Published var selectedNote: Note?
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let notesService = NotesService()
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0
    private var persistTask: Task<Void, Never>?
    private var titlePersistTask: Task<Void, Never>?
    private var pendingTitleForSave: String = ""
    private var pendingContent: JSONValue?

    init(listId: Int64) {
        self.listId = listId
    }

    deinit {
        persistTask?.cancel()
        titlePersistTask?.cancel()
    }

    func load() async {
        let showBlocking = !initialLoadAttemptCompleted
        loadSequence &+= 1
        let sequence = loadSequence
        errorMessage = nil
        if showBlocking { isBlockingLoad = true } else { isRefreshing = true }

        defer {
            if sequence == loadSequence {
                initialLoadAttemptCompleted = true
                isBlockingLoad = false
                isRefreshing = false
            }
        }

        do {
            let summaries = try await notesService.fetchNoteSummaries(listId: listId)
            guard sequence == loadSequence else { return }
            noteSummaries = summaries
            if let selected = selectedNote, !summaries.contains(where: { $0.id == selected.id }) {
                selectedNote = nil
            }
        } catch {
            guard sequence == loadSequence else { return }
            handleLoadNoteSummariesError(error)
        }
    }

    func selectNote(id noteId: Int64) async {
        await flushContent()
        titlePersistTask?.cancel()
        pendingTitleForSave = ""
        do {
            if let note = try await notesService.fetchNote(id: noteId) {
                selectedNote = note
            } else {
                selectedNote = nil
            }
        } catch {
            handleLoadNoteError(error)
        }
    }

    func createNote() async {
        titlePersistTask?.cancel()
        pendingTitleForSave = ""
        do {
            let note = try await notesService.createNote(
                listId: listId,
                title: Note.untitledTitle,
                content: Note.emptyDocument
            )
            selectedNote = note
            await loadNoteSummaries()
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = message
            }
        }
    }

    func deleteNote(id noteId: Int64) async {
        titlePersistTask?.cancel()
        persistTask?.cancel()
        pendingContent = nil
        pendingTitleForSave = ""
        do {
            try await notesService.deleteNote(id: noteId)
            if selectedNote?.id == noteId {
                selectedNote = nil
            }
            await loadNoteSummaries()
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = message
            }
        }
    }

    // MARK: - Title auto-save

    func persistTitleDebounced(_ title: String) {
        guard selectedNote != nil else { return }
        pendingTitleForSave = title
        titlePersistTask?.cancel()
        titlePersistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            let latest = self.pendingTitleForSave
            await self.saveTitleIfChanged(latest, noteId: self.selectedNote?.id)
        }
    }

    func flushTitle(_ title: String) async {
        titlePersistTask?.cancel()
        pendingTitleForSave = title
        await saveTitleIfChanged(title, noteId: selectedNote?.id)
    }

    private func saveTitleIfChanged(_ title: String, noteId: Int64?) async {
        guard let noteId, let note = selectedNote, note.id == noteId else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? Note.untitledTitle : trimmed
        guard normalized != note.title else { return }
        do {
            try await notesService.updateNote(id: note.id, update: NoteUpdate(title: normalized, content: nil))
            if var n = selectedNote, n.id == note.id {
                n.title = normalized
                selectedNote = n
            }
            await loadNoteSummaries()
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = message
            }
        }
    }

    // MARK: - Content auto-save

    func persistContentDebounced(_ content: JSONValue) {
        guard selectedNote != nil else { return }
        pendingContent = content
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            guard let self, let noteId = self.selectedNote?.id else { return }
            self.pendingContent = nil
            await self.persistContent(noteId: noteId, content: content)
        }
    }

    func flushContent() async {
        persistTask?.cancel()
        guard let note = selectedNote, let content = pendingContent else { return }
        pendingContent = nil
        await persistContent(noteId: note.id, content: content)
    }

    private func persistContent(noteId: Int64, content: JSONValue) async {
        do {
            try await notesService.updateNote(id: noteId, update: NoteUpdate(title: nil, content: content))
            if var n = selectedNote, n.id == noteId {
                n.content = content
                selectedNote = n
            }
            await loadNoteSummaries()
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = message
            }
        }
    }

    // MARK: - Internal helpers

    private func loadNoteSummaries() async {
        do {
            noteSummaries = try await notesService.fetchNoteSummaries(listId: listId)
            if let selected = selectedNote, !noteSummaries.contains(where: { $0.id == selected.id }) {
                selectedNote = nil
            }
        } catch {
            handleLoadNoteSummariesError(error)
        }
    }

    func handleLoadNoteError(_ error: Error) {
        selectedNote = nil
        if let message = UserFacingAsyncError.alertMessage(from: error) {
            errorMessage = message
        }
    }

    func handleLoadNoteSummariesError(_ error: Error) {
        noteSummaries = []
        if let message = UserFacingAsyncError.alertMessage(from: error) {
            errorMessage = message
        }
    }
}
