import XCTest
@testable import Familator

final class TripDetailViewModelTests: XCTestCase {

    private let testUserId = UUID()

    private func makeTrip(
        id: Int64 = 1, destination: String = "Paris",
        startDate: String? = nil, endDate: String? = nil,
        transportMode: TransportMode? = .driving
    ) -> Trip {
        Trip(
            id: id, listId: 10, ownerId: testUserId,
            workspaceId: "ws1", destination: destination,
            startDate: startDate, endDate: endDate,
            destinationLat: nil, destinationLng: nil,
            destinationPlaceId: nil, destinationPlaceName: nil,
            transportMode: transportMode,
            createdAt: Date(), updatedAt: Date()
        )
    }

    // MARK: - Computed properties (pure local state)

    @MainActor
    func testStatusReturnsPlanning_whenNoDates() {
        let vm = TripDetailViewModel()
        vm.localStartDate = nil
        vm.localEndDate = nil
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

    // MARK: - Service integration via mock

    @MainActor
    func testLoadFetchesTripFromService() async {
        let mockService = MockTripService()
        let vm = TripDetailViewModel(service: mockService)
        mockService.tripToReturn = makeTrip(id: 7, destination: "Vienna")

        await vm.load(tripId: 7)

        XCTAssertEqual(vm.trip?.id, 7)
        XCTAssertEqual(vm.trip?.destination, "Vienna")
        XCTAssertEqual(vm.destinationDraft, "Vienna")
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testLoadSetsErrorOnFailure() async {
        let mockService = MockTripService()
        let vm = TripDetailViewModel(service: mockService)
        mockService.errorToThrow = NSError(domain: "test", code: 1)

        await vm.load(tripId: 1)

        XCTAssertNil(vm.trip)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testSaveDestinationCallsService() async {
        let mockService = MockTripService()
        let vm = TripDetailViewModel(service: mockService)
        mockService.tripToReturn = makeTrip(id: 3, destination: "Paris")
        await vm.load(tripId: 3)

        vm.destinationDraft = "Berlin"
        await vm.saveDestination()

        XCTAssertEqual(mockService.updateDestinationCalls.count, 1)
        XCTAssertEqual(mockService.updateDestinationCalls[0].id, 3)
        XCTAssertEqual(mockService.updateDestinationCalls[0].destination, "Berlin")
        XCTAssertEqual(vm.trip?.destination, "Berlin")
    }
}
