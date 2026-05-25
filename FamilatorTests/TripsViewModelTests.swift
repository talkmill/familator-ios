import XCTest
@testable import Familator

@MainActor
final class TripsViewModelTests: XCTestCase {
    private var sut: TripsViewModel!
    private var mockService: MockTripService!

    override func setUp() {
        super.setUp()
        mockService = MockTripService()
        sut = TripsViewModel(tripService: mockService)
    }

    private let testUserId = UUID()

    private func makeTrip(
        id: Int64 = 1, destination: String = "Paris",
        startDate: String? = nil, endDate: String? = nil
    ) -> Trip {
        Trip(
            id: id, listId: 10, ownerId: testUserId,
            workspaceId: "ws1", destination: destination,
            startDate: startDate, endDate: endDate,
            destinationLat: nil, destinationLng: nil,
            destinationPlaceId: nil, destinationPlaceName: nil,
            transportMode: .driving,
            createdAt: Date(), updatedAt: Date()
        )
    }

    func testLoadFetchesTripsFromService() async {
        mockService.tripsToReturn = [makeTrip(id: 1, destination: "Paris"), makeTrip(id: 2, destination: "London")]

        await sut.load(workspaceId: "ws1")

        XCTAssertEqual(sut.trips.count, 2)
        XCTAssertEqual(mockService.fetchTripsCalls, ["ws1"])
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadSetsErrorOnFailure() async {
        mockService.errorToThrow = NSError(domain: "test", code: 42)

        await sut.load(workspaceId: "ws1")

        XCTAssertTrue(sut.trips.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testDeleteTripCallsServiceAndRemovesFromArray() async {
        let trip = makeTrip(id: 5, destination: "Rome")
        sut.trips = [trip]

        await sut.deleteTrip(trip)

        XCTAssertTrue(sut.trips.isEmpty)
        XCTAssertEqual(mockService.deleteTripCalls.count, 1)
        XCTAssertEqual(mockService.deleteTripCalls[0].id, 5)
    }

    func testLoadWithNilWorkspaceIdResetsState() async {
        sut.trips = [makeTrip()]

        await sut.load(workspaceId: nil)

        XCTAssertTrue(sut.trips.isEmpty)
    }
}
