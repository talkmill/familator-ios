import XCTest
@testable import Familator

final class TripDetailViewModelTests: XCTestCase {
    // Tests for the computed properties which are pure functions of local state.

    @MainActor
    func testStatusReturnsPlanning_whenNoDates() {
        let vm = TripDetailViewModel()
        vm.localStartDate = nil
        vm.localEndDate = nil
        // status uses today's date, but with nil dates it's always planning
        XCTAssertEqual(vm.status, .planning)
    }

    @MainActor
    func testStatusReturnsPlanning_whenOnlyStartDate() {
        let vm = TripDetailViewModel()
        vm.localStartDate = "2026-01-01"
        vm.localEndDate = nil
        XCTAssertEqual(vm.status, .planning)
    }

    @MainActor
    func testStatusReturnsPast_whenBothDatesInPast() {
        let vm = TripDetailViewModel()
        vm.localStartDate = "2020-01-01"
        vm.localEndDate = "2020-01-15"
        XCTAssertEqual(vm.status, .past)
    }

    @MainActor
    func testStatusReturnsUpcoming_whenBothDatesInFarFuture() {
        let vm = TripDetailViewModel()
        vm.localStartDate = "2099-01-01"
        vm.localEndDate = "2099-01-15"
        XCTAssertEqual(vm.status, .upcoming)
    }

    @MainActor
    func testNightsReturnsNil_whenNoDates() {
        let vm = TripDetailViewModel()
        vm.localStartDate = nil
        vm.localEndDate = nil
        XCTAssertNil(vm.nights)
    }

    @MainActor
    func testNightsReturnsCorrectCount() {
        let vm = TripDetailViewModel()
        vm.localStartDate = "2026-05-05"
        vm.localEndDate = "2026-05-08"
        XCTAssertEqual(vm.nights, 3)
    }

    @MainActor
    func testDateRangeReturnsEmpty_whenNoDates() {
        let vm = TripDetailViewModel()
        vm.localStartDate = nil
        vm.localEndDate = nil
        XCTAssertEqual(vm.dateRange, "")
    }

    @MainActor
    func testDateRangeReturnsSameMonth_format() {
        let vm = TripDetailViewModel()
        vm.localStartDate = "2026-05-05"
        vm.localEndDate = "2026-05-15"
        XCTAssertEqual(vm.dateRange, "May 5 – 15, 2026")
    }

    @MainActor
    func testActiveTabDefaultsToChecklist() {
        let vm = TripDetailViewModel()
        XCTAssertEqual(vm.activeTab, .checklist)
    }
}
