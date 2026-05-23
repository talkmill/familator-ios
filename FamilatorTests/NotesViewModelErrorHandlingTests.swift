import XCTest
@testable import Familator

@MainActor
final class NotesViewModelErrorHandlingTests: XCTestCase {
    func testHandleLoadNoteErrorClearsStateAndSuppressesCancellationAlert() {
        let viewModel = NotesViewModel()
        viewModel.selectedNote = makeNote(id: 101)
        viewModel.linkedTodos = [LinkedTodoSummary(id: 201, title: "Todo", status: "open")]
        viewModel.errorMessage = "Old error"

        viewModel.handleLoadNoteError(CancellationError())

        XCTAssertNil(viewModel.selectedNote)
        XCTAssertTrue(viewModel.linkedTodos.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Old error")
    }

    func testHandleLoadNoteErrorClearsStateAndSetsErrorForNonCancellation() {
        let viewModel = NotesViewModel()
        viewModel.selectedNote = makeNote(id: 102)
        viewModel.linkedTodos = [LinkedTodoSummary(id: 202, title: "Todo", status: "open")]
        viewModel.errorMessage = nil
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Could not load note"]
        )

        viewModel.handleLoadNoteError(error)

        XCTAssertNil(viewModel.selectedNote)
        XCTAssertTrue(viewModel.linkedTodos.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Could not load note")
    }

    func testHandleLoadNoteSummariesErrorClearsSummariesAndSuppressesCancellationAlert() {
        let viewModel = NotesViewModel()
        viewModel.noteSummaries = [NoteSummary(id: 301, title: "Note", updatedAt: Date())]
        viewModel.errorMessage = "Existing message"

        viewModel.handleLoadNoteSummariesError(CancellationError())

        XCTAssertTrue(viewModel.noteSummaries.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Existing message")
    }

    private func makeNote(id: Int64) -> Note {
        Note(
            id: id,
            listId: 1,
            title: "Test",
            content: .object([:]),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
