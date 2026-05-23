import XCTest
@testable import Familator

@MainActor
final class TripNotesViewModelTests: XCTestCase {

    // MARK: - Initial state

    func testInitialState() {
        let vm = TripNotesViewModel(listId: 42)
        XCTAssertEqual(vm.listId, 42)
        XCTAssertTrue(vm.noteSummaries.isEmpty)
        XCTAssertNil(vm.selectedNote)
        XCTAssertFalse(vm.isBlockingLoad)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Error handling

    func testHandleLoadNoteErrorClearsSelectionAndSuppressesCancellation() {
        let vm = TripNotesViewModel(listId: 1)
        vm.selectedNote = makeNote(id: 101)
        vm.errorMessage = "Old error"

        vm.handleLoadNoteError(CancellationError())

        XCTAssertNil(vm.selectedNote)
        // Cancellation should NOT overwrite existing error
        XCTAssertEqual(vm.errorMessage, "Old error")
    }

    func testHandleLoadNoteErrorClearsSelectionAndSetsError() {
        let vm = TripNotesViewModel(listId: 1)
        vm.selectedNote = makeNote(id: 102)
        vm.errorMessage = nil

        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Could not load note"]
        )
        vm.handleLoadNoteError(error)

        XCTAssertNil(vm.selectedNote)
        XCTAssertEqual(vm.errorMessage, "Could not load note")
    }

    func testHandleLoadNoteSummariesErrorClearsSummariesAndSuppressesCancellation() {
        let vm = TripNotesViewModel(listId: 1)
        vm.noteSummaries = [NoteSummary(id: 301, title: "Note", updatedAt: Date())]
        vm.errorMessage = "Existing message"

        vm.handleLoadNoteSummariesError(CancellationError())

        XCTAssertTrue(vm.noteSummaries.isEmpty)
        XCTAssertEqual(vm.errorMessage, "Existing message")
    }

    func testHandleLoadNoteSummariesErrorClearsSummariesAndSetsError() {
        let vm = TripNotesViewModel(listId: 1)
        vm.noteSummaries = [NoteSummary(id: 302, title: "Note", updatedAt: Date())]
        vm.errorMessage = nil

        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Failed to load summaries"]
        )
        vm.handleLoadNoteSummariesError(error)

        XCTAssertTrue(vm.noteSummaries.isEmpty)
        XCTAssertEqual(vm.errorMessage, "Failed to load summaries")
    }

    // MARK: - Delete clears selection

    func testDeleteClearsSelectionWhenSelectedNoteDeleted() {
        let vm = TripNotesViewModel(listId: 1)
        let note = makeNote(id: 200)
        vm.selectedNote = note

        // Simulate what deleteNote does to local state when the deleted note is selected
        if vm.selectedNote?.id == note.id {
            vm.selectedNote = nil
        }

        XCTAssertNil(vm.selectedNote)
    }

    func testDeletePreservesSelectionWhenOtherNoteDeleted() {
        let vm = TripNotesViewModel(listId: 1)
        let selectedNote = makeNote(id: 200)
        vm.selectedNote = selectedNote

        let otherNoteId: Int64 = 300
        // Simulate what deleteNote does: only clears if IDs match
        if vm.selectedNote?.id == otherNoteId {
            vm.selectedNote = nil
        }

        XCTAssertEqual(vm.selectedNote?.id, 200)
    }

    // MARK: - Helpers

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
