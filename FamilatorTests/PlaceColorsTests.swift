import XCTest
@testable import Familator

final class PlaceColorsTests: XCTestCase {
    func testColorCountMatchesWebPalette() {
        XCTAssertEqual(PlaceColors.colors.count, 8)
    }

    func testColorForIndexWrapsAround() {
        let first = PlaceColors.color(forIndex: 0)
        let wrapped = PlaceColors.color(forIndex: 8)
        XCTAssertEqual(first, wrapped)
    }

    func testColorForIndexDoesNotCrashForLargeValues() {
        _ = PlaceColors.color(forIndex: 10000)
    }
}
