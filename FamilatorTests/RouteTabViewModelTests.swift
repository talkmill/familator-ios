import XCTest
@testable import Familator

@MainActor
final class RouteTabViewModelTests: XCTestCase {
    private var sut: RouteTabViewModel!
    private var mockTripService: MockTripService!
    private var mockLegsService: MockTripLegsService!
    private var mockPlacesService: MockTripPlacesService!

    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        mockTripService = MockTripService()
        mockLegsService = MockTripLegsService()
        mockPlacesService = MockTripPlacesService()
        sut = RouteTabViewModel(
            tripService: mockTripService,
            legsService: mockLegsService,
            placesService: mockPlacesService
        )
    }

    private func makeLeg(id: Int64, name: String = "Leg", sortOrder: Int = 0) -> TripLeg {
        TripLeg(id: id, tripId: 1, name: name, sortOrder: sortOrder,
                transportMode: .driving, createdAt: "2026-01-01T00:00:00Z")
    }

    private func makePlace(id: Int64, lat: Double? = nil, lng: Double? = nil, sortOrder: Int = 0) -> TripPlace {
        TripPlace(id: id, tripId: 1, legId: nil, name: "Place \(id)",
                  notes: nil, date: nil, lat: lat, lng: lng, googlePlaceId: nil,
                  sortOrder: sortOrder, isRouteAnchor: false, visitedAt: nil,
                  rating: nil, createdAt: "2026-01-01T00:00:00Z")
    }

    private func makeTrip(id: Int64 = 1, transportMode: TransportMode = .driving) -> Trip {
        Trip(id: id, listId: 10, ownerId: testUserId, workspaceId: "ws1",
             destination: "Paris", startDate: nil, endDate: nil,
             destinationLat: nil, destinationLng: nil,
             destinationPlaceId: nil, destinationPlaceName: nil,
             transportMode: transportMode, createdAt: Date(), updatedAt: Date())
    }

    func testLoadFetchesLegsAndPlacesFromService() async {
        mockLegsService.legsToReturn = [makeLeg(id: 1, name: "Day 1")]
        mockPlacesService.placesToReturn = [makePlace(id: 1)]

        await sut.load(tripId: 1)

        XCTAssertEqual(sut.legs.count, 1)
        XCTAssertEqual(sut.places.count, 1)
        XCTAssertEqual(mockLegsService.fetchLegsCalls, [1])
        XCTAssertEqual(mockPlacesService.fetchPlacesCalls, [1])
    }

    func testChangeTransportModeCallsTripService() async {
        let trip = makeTrip()
        sut.setTrip(trip)

        await sut.changeTransportMode(to: .walking)

        XCTAssertEqual(mockTripService.updateTransportModeCalls.count, 1)
        XCTAssertEqual(mockTripService.updateTransportModeCalls[0].transportMode, .walking)
        XCTAssertEqual(sut.transportMode, .walking)
    }

    func testChangeTransportModeRevertsOnFailure() async {
        let trip = makeTrip(transportMode: .driving)
        sut.setTrip(trip)
        mockTripService.errorToThrow = NSError(domain: "test", code: 1)

        await sut.changeTransportMode(to: .cycling)

        XCTAssertEqual(sut.transportMode, .driving)
    }

    func testChangeLegTransportModeCallsLegsService() async {
        sut.legs = [makeLeg(id: 5)]

        await sut.changeLegTransportMode(legId: 5, to: .walking)

        XCTAssertEqual(mockLegsService.updateLegCalls.count, 1)
        XCTAssertEqual(mockLegsService.updateLegCalls[0].id, 5)
        XCTAssertEqual(mockLegsService.updateLegCalls[0].update.transportMode, .walking)
    }

    func testToggleAnchorCallsPlacesService() async {
        sut.places = [makePlace(id: 10)]

        await sut.toggleAnchor(placeId: 10)

        XCTAssertEqual(mockPlacesService.updatePlaceCalls.count, 1)
        XCTAssertEqual(mockPlacesService.updatePlaceCalls[0].id, 10)
    }

    func testFormatDuration() {
        XCTAssertEqual(sut.formatDuration(30), "30 min")
        XCTAssertEqual(sut.formatDuration(60), "1 hr")
        XCTAssertEqual(sut.formatDuration(90), "1 hr 30 min")
    }

    func testFormatDistance() {
        XCTAssertEqual(sut.formatDistance(0.5), "500 m")
        XCTAssertEqual(sut.formatDistance(10.0), "10.0 km")
    }
}
