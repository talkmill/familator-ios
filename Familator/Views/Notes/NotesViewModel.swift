import Foundation

@MainActor
final class NotesViewModel: ObservableObject {
    @Published var lists: [FamilatorList] = []
    @Published var selectedListId: Int64?
    @Published var noteSummaries: [NoteSummary] = []
    @Published var selectedNote: Note?
    @Published var linkedTodos: [LinkedTodoSummary] = []
    @Published var isBlockingLoad = false
    @Published var isRefreshing = false
    @Published var canWriteSelectedList = false
    @Published var errorMessage: String?

    private let listsService = ListsService()
    private let notesService = NotesService()
    private var cachedUserId: String?
    private var initialLoadAttemptCompleted = false
    private var loadSequence = 0
    private var persistTask: Task<Void, Never>?
    private var titlePersistTask: Task<Void, Never>?
    private var pendingTitleForSave: String = ""
    private var pendingContent: JSONValue?

    deinit {
        persistTask?.cancel()
        titlePersistTask?.cancel()
    }

    func reset() {
        lists = []
        selectedListId = nil
        noteSummaries = []
        selectedNote = nil
        linkedTodos = []
        isBlockingLoad = false
        isRefreshing = false
        canWriteSelectedList = false
        errorMessage = nil
        cachedUserId = nil
        initialLoadAttemptCompleted = false
        loadSequence &+= 1
        persistTask?.cancel()
        titlePersistTask?.cancel()
        pendingTitleForSave = ""
        pendingContent = nil
    }

    func load(workspaceId: String?, userId: UUID?) async {
        guard let userId, let workspaceId else {
            reset()
            return
        }
        let userKey = userId.uuidString.lowercased()
        if let cached = cachedUserId, cached != userKey {
            reset()
        }

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
            let fetchedLists = try await listsService.fetchLists(workspaceId: workspaceId, userId: userId)
            guard sequence == loadSequence else { return }
            lists = fetchedLists
            cachedUserId = userKey

            if selectedListId == nil || !fetchedLists.contains(where: { $0.id == selectedListId }) {
                selectedListId = fetchedLists.first(where: { $0.isInbox == true })?.id ?? fetchedLists.first?.id
            }
            try await reloadSelectedListData(userId: userId)
        } catch {
            guard sequence == loadSequence else { return }
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = message
            }
        }
    }

    func selectList(_ listId: Int64, userId: UUID?) async {
        await flushContent()
        titlePersistTask?.cancel()
        pendingTitleForSave = ""
        selectedListId = listId
        selectedNote = nil
        linkedTodos = []
        await loadListWriteAccess(userId: userId)
        await loadNoteSummaries()
    }

    /// Loads one note into `selectedNote` (used by the notes list and detail flow).
    func selectNote(id noteId: Int64) async {
        await flushContent()
        await loadNote(noteId: noteId)
    }

    func loadNote(noteId: Int64) async {
        titlePersistTask?.cancel()
        pendingTitleForSave = ""
        do {
            if let note = try await notesService.fetchNote(id: noteId) {
                selectedNote = note
                linkedTodos = try await notesService.fetchLinkedTodos(noteId: note.id)
            } else {
                selectedNote = nil
                linkedTodos = []
            }
        } catch {
            handleLoadNoteError(error)
        }
    }

    func createNote() async {
        titlePersistTask?.cancel()
        pendingTitleForSave = ""
        guard canWriteSelectedList, let listId = selectedListId else { return }
        do {
            let note = try await notesService.createNote(
                listId: listId,
                title: Note.untitledTitle,
                content: Note.emptyDocument
            )
            await loadNoteSummaries()
            selectedNote = note
            linkedTodos = []
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = message
            }
        }
    }

    func deleteSelectedNote() async {
        titlePersistTask?.cancel()
        guard canWriteSelectedList, let note = selectedNote else { return }
        do {
            try await notesService.deleteNote(id: note.id)
            selectedNote = nil
            linkedTodos = []
            await loadNoteSummaries()
            NotificationCenter.default.post(name: .familatorDataDidChange, object: nil)
        } catch {
            if let message = UserFacingAsyncError.alertMessage(from: error) {
                errorMessage = message
            }
        }
    }

    func saveTitle(_ title: String) async {
        titlePersistTask?.cancel()
        await saveTitleIfChanged(title, noteId: selectedNote?.id)
    }

    /// Cancels pending debounced title work and saves immediately (e.g. Return key).
    func flushTitle(_ title: String) async {
        titlePersistTask?.cancel()
        pendingTitleForSave = title
        await saveTitleIfChanged(title, noteId: selectedNote?.id)
    }

    func persistTitleDebounced(_ title: String) {
        guard canWriteSelectedList, selectedNote != nil else { return }
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

    private func saveTitleIfChanged(_ title: String, noteId: Int64?) async {
        guard canWriteSelectedList, let noteId, let note = selectedNote, note.id == noteId else { return }
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

    func persistContentDebounced(_ content: JSONValue) {
        guard canWriteSelectedList, let note = selectedNote else { return }
        pendingContent = content
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.pendingContent = nil
            await self.persistContent(noteId: note.id, content: content)
        }
    }

    /// Cancels any pending debounced content save and persists immediately.
    func flushContent() async {
        persistTask?.cancel()
        guard canWriteSelectedList, let note = selectedNote, let content = pendingContent else { return }
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

    private func loadNoteSummaries() async {
        guard let listId = selectedListId else {
            noteSummaries = []
            return
        }
        do {
            noteSummaries = try await notesService.fetchNoteSummaries(listId: listId)
            if let selected = selectedNote, !noteSummaries.contains(where: { $0.id == selected.id }) {
                selectedNote = nil
                linkedTodos = []
            }
        } catch {
            handleLoadNoteSummariesError(error)
        }
    }

    func handleLoadNoteError(_ error: Error) {
        selectedNote = nil
        linkedTodos = []
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

    private func loadListWriteAccess(userId: UUID?) async {
        guard let userId, let selectedList = lists.first(where: { $0.id == selectedListId }) else {
            canWriteSelectedList = false
            return
        }
        do {
            canWriteSelectedList = try await notesService.canWrite(list: selectedList, userId: userId)
        } catch {
            canWriteSelectedList = false
        }
    }

    private func reloadSelectedListData(userId: UUID) async throws {
        await loadListWriteAccess(userId: userId)
        await loadNoteSummaries()
    }
}
