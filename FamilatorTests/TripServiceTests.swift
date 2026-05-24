import XCTest
@testable import Familator

private enum MockError: Error { case notConfigured }

final class MockTripService: TripServiceProtocol {
    var tripsToReturn: [Trip] = []
    var tripToReturn: Trip?
    var createdTripToReturn: Trip?
    var errorToThrow: Error?
    var fetchTripsCalls: [String] = []
    var createTripCalls: [(ownerId: UUID, destination: String, workspaceId: String)] = []
    var deleteTripCalls: [Trip] = []
    var updateDestinationCalls: [(id: Int64, destination: String)] = []
    var updateStartDateCalls: [(id: Int64, startDate: String?)] = []
    var updateEndDateCalls: [(id: Int64, endDate: String?)] = []
    var updateTransportModeCalls: [(id: Int64, transportMode: TransportMode)] = []

    func fetchTrips(workspaceId: String) async throws -> [Trip] {
        fetchTripsCalls.append(workspaceId)
        if let error = errorToThrow { throw error }
        return tripsToReturn
    }

    func createTrip(ownerId: UUID, destination: String, workspaceId: String) async throws -> Trip {
        createTripCalls.append((ownerId, destination, workspaceId))
        if let error = errorToThrow { throw error }
        guard let trip = createdTripToReturn else { XCTFail("createdTripToReturn not set"); throw MockError.notConfigured }
        return trip
    }

    func deleteTrip(_ trip: Trip) async throws {
        deleteTripCalls.append(trip)
        if let error = errorToThrow { throw error }
    }

    func fetchTrip(id: Int64) async throws -> Trip? {
        if let error = errorToThrow { throw error }
        return tripToReturn
    }

    func updateTripDestination(id: Int64, destination: String) async throws {
        updateDestinationCalls.append((id, destination))
        if let error = errorToThrow { throw error }
    }

    func updateTripStartDate(id: Int64, startDate: String?) async throws {
        updateStartDateCalls.append((id, startDate))
        if let error = errorToThrow { throw error }
    }

    func updateTripEndDate(id: Int64, endDate: String?) async throws {
        updateEndDateCalls.append((id, endDate))
        if let error = errorToThrow { throw error }
    }

    func updateTripTransportMode(id: Int64, transportMode: TransportMode) async throws {
        updateTransportModeCalls.append((id, transportMode))
        if let error = errorToThrow { throw error }
    }
}

final class TripServiceTests: XCTestCase {
    private var sut: MockTripService!
    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        sut = MockTripService()
    }

    private func makeTrip(
        id: Int64 = 1, listId: Int64 = 10, destination: String = "Paris",
        startDate: String? = nil, endDate: String? = nil,
        transportMode: TransportMode? = .driving
    ) -> Trip {
        Trip(
            id: id, listId: listId, ownerId: testUserId,
            workspaceId: "ws1", destination: destination,
            startDate: startDate, endDate: endDate,
            destinationLat: nil, destinationLng: nil,
            destinationPlaceId: nil, destinationPlaceName: nil,
            transportMode: transportMode,
            createdAt: Date(), updatedAt: Date()
        )
    }

    func testFetchTripsReturnsConfiguredTrips() async throws {
        let trips = [makeTrip(id: 1, destination: "Paris"), makeTrip(id: 2, destination: "London")]
        sut.tripsToReturn = trips

        let result = try await sut.fetchTrips(workspaceId: "ws1")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].destination, "Paris")
        XCTAssertEqual(result[1].destination, "London")
        XCTAssertEqual(sut.fetchTripsCalls, ["ws1"])
    }

    func testFetchTripsRecordsWorkspaceId() async throws {
        sut.tripsToReturn = []

        _ = try await sut.fetchTrips(workspaceId: "ws-abc")
        _ = try await sut.fetchTrips(workspaceId: "ws-xyz")

        XCTAssertEqual(sut.fetchTripsCalls, ["ws-abc", "ws-xyz"])
    }

    func testFetchTripsThrowsConfiguredError() async {
        sut.errorToThrow = NSError(domain: "test", code: 42)

        do {
            _ = try await sut.fetchTrips(workspaceId: "ws1")
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual((error as NSError).code, 42)
        }
    }

    func testCreateTripRecordsCallParameters() async throws {
        sut.createdTripToReturn = makeTrip()

        _ = try await sut.createTrip(ownerId: testUserId, destination: "Tokyo", workspaceId: "ws2")

        XCTAssertEqual(sut.createTripCalls.count, 1)
        XCTAssertEqual(sut.createTripCalls[0].destination, "Tokyo")
        XCTAssertEqual(sut.createTripCalls[0].workspaceId, "ws2")
        XCTAssertEqual(sut.createTripCalls[0].ownerId, testUserId)
    }

    func testCreateTripReturnsConfiguredTrip() async throws {
        let expected = makeTrip(id: 42, destination: "Berlin")
        sut.createdTripToReturn = expected

        let result = try await sut.createTrip(ownerId: testUserId, destination: "Berlin", workspaceId: "ws1")

        XCTAssertEqual(result.id, 42)
        XCTAssertEqual(result.destination, "Berlin")
    }

    func testDeleteTripRecordsCall() async throws {
        let trip = makeTrip(id: 5, destination: "Rome")

        try await sut.deleteTrip(trip)

        XCTAssertEqual(sut.deleteTripCalls.count, 1)
        XCTAssertEqual(sut.deleteTripCalls[0].id, 5)
    }

    func testFetchSingleTripReturnsNilWhenNotFound() async throws {
        sut.tripToReturn = nil

        let result = try await sut.fetchTrip(id: 999)

        XCTAssertNil(result)
    }

    func testFetchSingleTripReturnsTrip() async throws {
        sut.tripToReturn = makeTrip(id: 7, destination: "Vienna")

        let result = try await sut.fetchTrip(id: 7)

        XCTAssertEqual(result?.id, 7)
        XCTAssertEqual(result?.destination, "Vienna")
    }

    func testUpdateTripDestinationRecordsCall() async throws {
        try await sut.updateTripDestination(id: 3, destination: "Madrid")

        XCTAssertEqual(sut.updateDestinationCalls.count, 1)
        XCTAssertEqual(sut.updateDestinationCalls[0].id, 3)
        XCTAssertEqual(sut.updateDestinationCalls[0].destination, "Madrid")
    }

    func testUpdateTripStartDateRecordsCall() async throws {
        try await sut.updateTripStartDate(id: 4, startDate: "2026-07-01")

        XCTAssertEqual(sut.updateStartDateCalls.count, 1)
        XCTAssertEqual(sut.updateStartDateCalls[0].id, 4)
        XCTAssertEqual(sut.updateStartDateCalls[0].startDate, "2026-07-01")
    }

    func testUpdateTripEndDateRecordsCall() async throws {
        try await sut.updateTripEndDate(id: 4, endDate: nil)

        XCTAssertEqual(sut.updateEndDateCalls.count, 1)
        XCTAssertEqual(sut.updateEndDateCalls[0].id, 4)
        XCTAssertNil(sut.updateEndDateCalls[0].endDate)
    }

    func testUpdateTripTransportModeRecordsCall() async throws {
        try await sut.updateTripTransportMode(id: 8, transportMode: .cycling)

        XCTAssertEqual(sut.updateTransportModeCalls.count, 1)
        XCTAssertEqual(sut.updateTransportModeCalls[0].id, 8)
        XCTAssertEqual(sut.updateTransportModeCalls[0].transportMode, .cycling)
    }
}
