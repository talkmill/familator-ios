import XCTest
@testable import Familator

@MainActor
final class TipTapFormattingStateTests: XCTestCase {
    func testUpdateFromValidJSON() {
        let state = TipTapFormattingState()

        let json = """
        {"bold":true,"italic":false,"underline":true,"heading":2,"bulletList":false,"orderedList":true,"color":"#FF0000","fontSize":"18px","canUndo":true,"canRedo":false}
        """
        state.update(from: json)

        XCTAssertTrue(state.isBold)
        XCTAssertFalse(state.isItalic)
        XCTAssertTrue(state.isUnderline)
        XCTAssertEqual(state.headingLevel, 2)
        XCTAssertFalse(state.isBulletList)
        XCTAssertTrue(state.isOrderedList)
        XCTAssertEqual(state.color, "#FF0000")
        XCTAssertEqual(state.fontSize, "18px")
        XCTAssertTrue(state.canUndo)
        XCTAssertFalse(state.canRedo)
    }

    func testUpdateFromEmptyJSON() {
        let state = TipTapFormattingState()
        state.isBold = true
        state.headingLevel = 3

        state.update(from: "{}")

        XCTAssertFalse(state.isBold)
        XCTAssertEqual(state.headingLevel, 0)
        XCTAssertEqual(state.color, "")
        XCTAssertEqual(state.fontSize, "")
    }

    func testUpdateFromMalformedJSONIsNoOp() {
        let state = TipTapFormattingState()
        state.isBold = true

        state.update(from: "not json")

        XCTAssertTrue(state.isBold)
    }

    func testUpdateFromPartialJSON() {
        let state = TipTapFormattingState()

        state.update(from: "{\"bold\":true}")

        XCTAssertTrue(state.isBold)
        XCTAssertFalse(state.isItalic)
        XCTAssertEqual(state.headingLevel, 0)
    }

    func testNoteEmptyDocument() {
        guard case .object(let root) = Note.emptyDocument else {
            XCTFail("emptyDocument should be an object")
            return
        }
        XCTAssertEqual(root["type"], .string("doc"))
        guard case .array(let content) = root["content"] else {
            XCTFail("content should be an array")
            return
        }
        XCTAssertEqual(content.count, 1)
    }
}
