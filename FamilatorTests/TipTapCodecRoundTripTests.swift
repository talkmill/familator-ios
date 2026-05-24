import XCTest
import UIKit
@testable import Familator

final class TipTapCodecRoundTripTests: XCTestCase {

    // MARK: - Round trip (JSON → attributed → JSON)

    func testEmptyDocumentRoundTrip() {
        let doc = TipTapCodec.emptyDocument
        let attributed = TipTapCodec.toAttributedString(from: doc)
        let result = TipTapCodec.fromAttributedString(attributed)

        guard case .object(let root) = result else {
            XCTFail("Expected object root")
            return
        }
        XCTAssertEqual(root["type"], .string("doc"))
        guard case .array(let content) = root["content"] else {
            XCTFail("Expected content array")
            return
        }
        XCTAssertGreaterThanOrEqual(content.count, 1)
    }

    func testPlainTextParagraphRoundTrip() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("paragraph"),
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string("Hello world"),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("Hello world"))

        let result = TipTapCodec.fromAttributedString(attributed)
        guard case .object(let root) = result,
              case .array(let paragraphs) = root["content"],
              case .object(let para) = paragraphs.first,
              case .array(let runs) = para["content"],
              case .object(let textNode) = runs.first,
              case .string(let text) = textNode["text"]
        else {
            XCTFail("Expected text node in round trip")
            return
        }
        XCTAssertTrue(text.contains("Hello world"))
    }

    func testBoldTextRoundTrip() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("paragraph"),
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string("Bold text"),
                            "marks": .array([
                                .object(["type": .string("bold")]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        let font = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)

        let result = TipTapCodec.fromAttributedString(attributed)
        let marks = extractMarks(from: result)
        XCTAssertTrue(marks.contains("bold"))
    }

    func testItalicTextRoundTrip() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("paragraph"),
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string("Italic text"),
                            "marks": .array([
                                .object(["type": .string("italic")]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        let font = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)

        let result = TipTapCodec.fromAttributedString(attributed)
        let marks = extractMarks(from: result)
        XCTAssertTrue(marks.contains("italic"))
    }

    func testUnderlineTextRoundTrip() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("paragraph"),
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string("Underlined"),
                            "marks": .array([
                                .object(["type": .string("underline")]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        let underline = attributed.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)

        let result = TipTapCodec.fromAttributedString(attributed)
        let marks = extractMarks(from: result)
        XCTAssertTrue(marks.contains("underline"))
    }

    func testFontSizeRoundTrip() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("paragraph"),
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string("Big text"),
                            "marks": .array([
                                .object([
                                    "type": .string("textStyle"),
                                    "attrs": .object(["fontSize": .string("24px")]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        let font = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, 24)

        let result = TipTapCodec.fromAttributedString(attributed)
        let fontSize = extractFontSize(from: result)
        XCTAssertEqual(fontSize, "24px")
    }

    func testMultipleParagraphsRoundTrip() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("paragraph"),
                    "content": .array([
                        .object(["type": .string("text"), "text": .string("First")]),
                    ]),
                ]),
                .object([
                    "type": .string("paragraph"),
                    "content": .array([
                        .object(["type": .string("text"), "text": .string("Second")]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("First"))
        XCTAssertTrue(attributed.string.contains("Second"))

        let result = TipTapCodec.fromAttributedString(attributed)
        guard case .object(let root) = result, case .array(let content) = root["content"] else {
            XCTFail("Expected content array")
            return
        }
        XCTAssertGreaterThanOrEqual(content.count, 2)
    }

    // MARK: - toAttributedString only (lossy structures)

    func testHeadingRendersWithBoldFont() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("heading"),
                    "attrs": .object(["level": .number(1)]),
                    "content": .array([
                        .object(["type": .string("text"), "text": .string("Title")]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("Title"))
        let font = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertEqual(font?.pointSize, 18)
    }

    func testHeadingLevel3RendersCorrectSize() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("heading"),
                    "attrs": .object(["level": .number(3)]),
                    "content": .array([
                        .object(["type": .string("text"), "text": .string("H3")]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        let font = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, 14)
    }

    func testBulletListRendersWithPrefix() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("bulletList"),
                    "content": .array([
                        .object([
                            "type": .string("listItem"),
                            "content": .array([
                                .object([
                                    "type": .string("paragraph"),
                                    "content": .array([
                                        .object(["type": .string("text"), "text": .string("Item one")]),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("•"))
        XCTAssertTrue(attributed.string.contains("Item one"))
    }

    func testOrderedListRendersWithNumberedPrefix() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("orderedList"),
                    "content": .array([
                        .object([
                            "type": .string("listItem"),
                            "content": .array([
                                .object([
                                    "type": .string("paragraph"),
                                    "content": .array([
                                        .object(["type": .string("text"), "text": .string("First item")]),
                                    ]),
                                ]),
                            ]),
                        ]),
                        .object([
                            "type": .string("listItem"),
                            "content": .array([
                                .object([
                                    "type": .string("paragraph"),
                                    "content": .array([
                                        .object(["type": .string("text"), "text": .string("Second item")]),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("1."))
        XCTAssertTrue(attributed.string.contains("2."))
        XCTAssertTrue(attributed.string.contains("First item"))
    }

    func testTableRendersPipeSeparated() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("table"),
                    "content": .array([
                        .object([
                            "type": .string("tableRow"),
                            "content": .array([
                                .object([
                                    "type": .string("tableCell"),
                                    "content": .array([
                                        .object([
                                            "type": .string("paragraph"),
                                            "content": .array([
                                                .object(["type": .string("text"), "text": .string("A")]),
                                            ]),
                                        ]),
                                    ]),
                                ]),
                                .object([
                                    "type": .string("tableCell"),
                                    "content": .array([
                                        .object([
                                            "type": .string("paragraph"),
                                            "content": .array([
                                                .object(["type": .string("text"), "text": .string("B")]),
                                            ]),
                                        ]),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("A | B"))
    }

    func testHorizontalRuleRenders() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object(["type": .string("horizontalRule")]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("────────"))
    }

    func testCodeBlockUsesMonospacedFont() {
        let doc: JSONValue = .object([
            "type": .string("doc"),
            "content": .array([
                .object([
                    "type": .string("codeBlock"),
                    "content": .array([
                        .object(["type": .string("text"), "text": .string("let x = 1")]),
                    ]),
                ]),
            ]),
        ])

        let attributed = TipTapCodec.toAttributedString(from: doc)
        XCTAssertTrue(attributed.string.contains("let x = 1"))
        let font = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, 14)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    func testFromAttributedStringEmptyProducesValidDoc() {
        let empty = NSAttributedString(string: "")
        let result = TipTapCodec.fromAttributedString(empty)

        guard case .object(let root) = result else {
            XCTFail("Expected object")
            return
        }
        XCTAssertEqual(root["type"], .string("doc"))
        guard case .array(let content) = root["content"] else {
            XCTFail("Expected content array")
            return
        }
        XCTAssertEqual(content.count, 1)
        if case .object(let para) = content[0] {
            XCTAssertEqual(para["type"], .string("paragraph"))
        }
    }

    func testInvalidJsonReturnsEmptyString() {
        let result = TipTapCodec.toAttributedString(from: .string("not a doc"))
        XCTAssertEqual(result.string, "")
    }

    // MARK: - Helpers

    private func extractMarks(from json: JSONValue) -> [String] {
        guard case .object(let root) = json,
              case .array(let content) = root["content"],
              case .object(let para) = content.first,
              case .array(let runs) = para["content"]
        else { return [] }

        var markTypes: [String] = []
        for run in runs {
            guard case .object(let node) = run,
                  case .array(let marks) = node["marks"]
            else { continue }
            for mark in marks {
                guard case .object(let m) = mark,
                      case .string(let type) = m["type"]
                else { continue }
                markTypes.append(type)
            }
        }
        return markTypes
    }

    private func extractFontSize(from json: JSONValue) -> String? {
        guard case .object(let root) = json,
              case .array(let content) = root["content"],
              case .object(let para) = content.first,
              case .array(let runs) = para["content"]
        else { return nil }

        for run in runs {
            guard case .object(let node) = run,
                  case .array(let marks) = node["marks"]
            else { continue }
            for mark in marks {
                guard case .object(let m) = mark,
                      case .string(let type) = m["type"],
                      type == "textStyle",
                      case .object(let attrs) = m["attrs"],
                      case .string(let fontSize) = attrs["fontSize"]
                else { continue }
                return fontSize
            }
        }
        return nil
    }
}
