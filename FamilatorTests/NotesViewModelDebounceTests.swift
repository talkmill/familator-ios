import XCTest
@testable import Familator

private enum MockError: Error { case notConfigured }

final class MockNotesService: NotesServiceProtocol {
    var noteSummariesToReturn: [NoteSummary] = []
    var noteToReturn: Note?
    var createdNoteToReturn: Note?
    var linkedTodosToReturn: [LinkedTodoSummary] = []
    var canWriteToReturn: Bool = true
    var errorToThrow: Error?
    var updateNoteCalls: [(id: Int64, update: NoteUpdate)] = []
    var deleteNoteCalls: [Int64] = []
    var createNoteCalls: [(listId: Int64, title: String, content: JSONValue)] = []

    func fetchNoteSummaries(listId: Int64) async throws -> [NoteSummary] {
        if let error = errorToThrow { throw error }
        return noteSummariesToReturn
    }

    func fetchNote(id: Int64) async throws -> Note? {
        if let error = errorToThrow { throw error }
        return noteToReturn
    }

    func createNote(listId: Int64, title: String, content: JSONValue) async throws -> Note {
        createNoteCalls.append((listId, title, content))
        if let error = errorToThrow { throw error }
        guard let note = createdNoteToReturn else { XCTFail("createdNoteToReturn not set"); throw MockError.notConfigured }
        return note
    }

    func updateNote(id: Int64, update: NoteUpdate) async throws {
        updateNoteCalls.append((id, update))
        if let error = errorToThrow { throw error }
    }

    func deleteNote(id: Int64) async throws {
        deleteNoteCalls.append(id)
        if let error = errorToThrow { throw error }
    }

    func fetchLinkedTodos(noteId: Int64) async throws -> [LinkedTodoSummary] {
        if let error = errorToThrow { throw error }
        return linkedTodosToReturn
    }

    func fetchNoteSummaries(noteIds: [Int64]) async throws -> [NoteSummary] {
        if let error = errorToThrow { throw error }
        return noteSummariesToReturn.filter { noteIds.contains($0.id) }
    }

    func fetchLinkedNoteIds(todoId: Int64) async throws -> [Int64] {
        if let error = errorToThrow { throw error }
        return []
    }

    func replaceNoteLinks(todoId: Int64, listId: Int64, noteIds: [Int64]) async throws {
        if let error = errorToThrow { throw error }
    }

    func canWrite(list: FamilatorList, userId: UUID) async throws -> Bool {
        return canWriteToReturn
    }
}

@MainActor
final class NotesViewModelDebounceTests: XCTestCase {
    private var sut: NotesViewModel!
    private var mockNotesService: MockNotesService!
    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        mockNotesService = MockNotesService()
        sut = NotesViewModel(notesService: mockNotesService)
    }

    private func makeNote(id: Int64 = 1, title: String = "Test Note") -> Note {
        Note(
            id: id, listId: 1, title: title,
            content: Note.emptyDocument,
            createdAt: Date(), updatedAt: Date()
        )
    }

    private func setupForTitleSave(title: String = "Test Note") {
        sut.selectedNote = makeNote(title: title)
        sut.canWriteSelectedList = true
        sut.selectedListId = 1
        mockNotesService.noteSummariesToReturn = [
            NoteSummary(id: 1, title: title, updatedAt: Date()),
        ]
    }

    func testFlushTitleSavesImmediately() async {
        setupForTitleSave(title: "Old Title")

        await sut.flushTitle("New Title")

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 1)
        XCTAssertEqual(mockNotesService.updateNoteCalls[0].update.title, "New Title")
    }

    func testFlushTitleSkipsWhenTitleUnchanged() async {
        setupForTitleSave(title: "Same")

        await sut.flushTitle("Same")

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 0)
    }

    func testEmptyTitleNormalizesToUntitled() async {
        setupForTitleSave(title: "Old")

        await sut.flushTitle("   ")

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 1)
        XCTAssertEqual(mockNotesService.updateNoteCalls[0].update.title, "Untitled")
    }

    func testFlushTitleSkipsWhenCanWriteIsFalse() async {
        sut.selectedNote = makeNote()
        sut.canWriteSelectedList = false

        await sut.flushTitle("New")

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 0)
    }

    func testFlushTitleSkipsWhenNoSelectedNote() async {
        sut.canWriteSelectedList = true
        sut.selectedNote = nil

        await sut.flushTitle("New")

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 0)
    }

    func testPersistTitleDebouncedDoesNotSaveImmediately() {
        setupForTitleSave(title: "Old")

        sut.persistTitleDebounced("New Title")

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 0)
    }

    func testPersistTitleDebouncedSkipsWhenCanWriteIsFalse() {
        sut.selectedNote = makeNote()
        sut.canWriteSelectedList = false

        sut.persistTitleDebounced("New")

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 0)
    }

    func testFlushContentSavesPendingContent() async {
        setupForTitleSave()
        let content: JSONValue = .object(["type": .string("doc"), "content": .array([])])
        sut.persistContentDebounced(content)

        await sut.flushContent()

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 1)
        XCTAssertNotNil(mockNotesService.updateNoteCalls[0].update.content)
    }

    func testFlushContentNoOpWhenNoPendingContent() async {
        setupForTitleSave()

        await sut.flushContent()

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 0)
    }

    func testPersistContentDebouncedDoesNotSaveImmediately() {
        setupForTitleSave()
        let content: JSONValue = .object(["type": .string("doc"), "content": .array([])])

        sut.persistContentDebounced(content)

        XCTAssertEqual(mockNotesService.updateNoteCalls.count, 0)
    }
}
