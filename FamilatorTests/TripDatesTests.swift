import XCTest
@testable import Familator

final class TripDatesTests: XCTestCase {
    // MARK: - formatTripDateRange

    func testNeitherDateSetReturnsEmpty() {
        XCTAssertEqual(formatTripDateRange(startDate: nil, endDate: nil), "")
    }

    func testOnlyStartSet() {
        XCTAssertEqual(formatTripDateRange(startDate: "2026-05-05", endDate: nil), "May 5, 2026 –")
    }

    func testOnlyEndSet() {
        XCTAssertEqual(formatTripDateRange(startDate: nil, endDate: "2026-05-10"), "– May 10, 2026")
    }

    func testSameDayTrip() {
        XCTAssertEqual(formatTripDateRange(startDate: "2026-05-05", endDate: "2026-05-05"), "May 5, 2026")
    }

    func testSameMonthStartDayLessThan10() {
        XCTAssertEqual(formatTripDateRange(startDate: "2026-05-05", endDate: "2026-05-15"), "May 5 – 15, 2026")
    }

    func testSameMonthStartDayGreaterOrEqual10() {
        XCTAssertEqual(formatTripDateRange(startDate: "2026-05-15", endDate: "2026-05-25"), "May 15 – 25, 2026")
    }

    func testMultiMonth() {
        XCTAssertEqual(formatTripDateRange(startDate: "2026-05-25", endDate: "2026-06-05"), "May 25, 2026 – Jun 5, 2026")
    }

    func testCrossYear() {
        XCTAssertEqual(formatTripDateRange(startDate: "2026-12-28", endDate: "2027-01-03"), "Dec 28, 2026 – Jan 3, 2027")
    }

    // MARK: - computeNights

    func testBothNullReturnsNil() {
        XCTAssertNil(computeNights(startDate: nil, endDate: nil))
    }

    func testStartNullReturnsNil() {
        XCTAssertNil(computeNights(startDate: nil, endDate: "2026-05-10"))
    }

    func testEndNullReturnsNil() {
        XCTAssertNil(computeNights(startDate: "2026-05-05", endDate: nil))
    }

    func testSameDayReturns0() {
        XCTAssertEqual(computeNights(startDate: "2026-05-05", endDate: "2026-05-05"), 0)
    }

    func test3Nights() {
        XCTAssertEqual(computeNights(startDate: "2026-05-05", endDate: "2026-05-08"), 3)
    }

    func testMultiMonth11Nights() {
        XCTAssertEqual(computeNights(startDate: "2026-05-25", endDate: "2026-06-05"), 11)
    }

    func testInvertedDatesReturns0() {
        XCTAssertEqual(computeNights(startDate: "2026-05-10", endDate: "2026-05-05"), 0)
    }
}
