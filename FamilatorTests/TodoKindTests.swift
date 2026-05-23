import XCTest
@testable import Familator

final class TodoKindTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(TodoKind.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(TodoKind.task.rawValue, "task")
        XCTAssertEqual(TodoKind.flight.rawValue, "flight")
        XCTAssertEqual(TodoKind.hotel.rawValue, "hotel")
    }

    func testLabels() {
        XCTAssertEqual(TodoKind.task.label, "Task")
        XCTAssertEqual(TodoKind.flight.label, "Flight")
        XCTAssertEqual(TodoKind.hotel.label, "Hotel")
    }

    func testSystemImages() {
        XCTAssertEqual(TodoKind.task.systemImage, "checkmark.square")
        XCTAssertEqual(TodoKind.flight.systemImage, "airplane")
        XCTAssertEqual(TodoKind.hotel.systemImage, "building.2")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(TodoKind(rawValue: "task"), .task)
        XCTAssertEqual(TodoKind(rawValue: "flight"), .flight)
        XCTAssertEqual(TodoKind(rawValue: "hotel"), .hotel)
        XCTAssertNil(TodoKind(rawValue: "unknown"))
    }
}
