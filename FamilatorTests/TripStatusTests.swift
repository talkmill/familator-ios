import XCTest
@testable import Familator

final class TripStatusTests: XCTestCase {
    // MARK: - TripStatus.compute

    func testBothDatesNilReturnPlanning() {
        XCTAssertEqual(
            TripStatus.compute(startDate: nil, endDate: nil, today: "2026-05-19"),
            .planning
        )
    }

    func testStartDateNilReturnPlanning() {
        XCTAssertEqual(
            TripStatus.compute(startDate: nil, endDate: "2026-06-01", today: "2026-05-19"),
            .planning
        )
    }

    func testEndDateNilReturnPlanning() {
        XCTAssertEqual(
            TripStatus.compute(startDate: "2026-06-01", endDate: nil, today: "2026-05-19"),
            .planning
        )
    }

    func testEndDateBeforeTodayReturnsPast() {
        XCTAssertEqual(
            TripStatus.compute(startDate: "2026-05-01", endDate: "2026-05-18", today: "2026-05-19"),
            .past
        )
    }

    func testStartDateOnTodayReturnsInProgress() {
        XCTAssertEqual(
            TripStatus.compute(startDate: "2026-05-19", endDate: "2026-05-25", today: "2026-05-19"),
            .inProgress
        )
    }

    func testStartDateBeforeTodayEndDateOnTodayReturnsInProgress() {
        XCTAssertEqual(
            TripStatus.compute(startDate: "2026-05-15", endDate: "2026-05-19", today: "2026-05-19"),
            .inProgress
        )
    }

    func testBothDatesInFutureReturnsUpcoming() {
        XCTAssertEqual(
            TripStatus.compute(startDate: "2026-06-01", endDate: "2026-06-15", today: "2026-05-19"),
            .upcoming
        )
    }

    // MARK: - Sort order

    func testSortOrderPriority() {
        XCTAssertLessThan(TripStatus.inProgress.sortOrder, TripStatus.upcoming.sortOrder)
        XCTAssertLessThan(TripStatus.upcoming.sortOrder, TripStatus.planning.sortOrder)
        XCTAssertLessThan(TripStatus.planning.sortOrder, TripStatus.past.sortOrder)
    }

    // MARK: - Display name

    func testDisplayNames() {
        XCTAssertEqual(TripStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(TripStatus.upcoming.displayName, "Upcoming")
        XCTAssertEqual(TripStatus.planning.displayName, "Planning")
        XCTAssertEqual(TripStatus.past.displayName, "Past")
    }
}
