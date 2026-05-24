import XCTest
@testable import Familator

private enum MockError: Error { case notConfigured }

final class MockTripPlacesService: TripPlacesServiceProtocol {
    var placesToReturn: [TripPlace] = []
    var createdPlaceToReturn: TripPlace?
    var reorderedPlacesToReturn: [TripPlace] = []
    var errorToThrow: Error?
    var fetchPlacesCalls: [Int64] = []
    var createPlaceCalls: [TripPlaceInsert] = []
    var updatePlaceCalls: [(id: Int64, update: TripPlaceUpdate)] = []
    var deletePlaceCalls: [Int64] = []
    var reorderPlacesCalls: [(tripId: Int64, placeIds: [Int64])] = []

    func fetchPlaces(tripId: Int64) async throws -> [TripPlace] {
        fetchPlacesCalls.append(tripId)
        if let error = errorToThrow { throw error }
        return placesToReturn
    }

    func createPlace(payload: TripPlaceInsert) async throws -> TripPlace {
        createPlaceCalls.append(payload)
        if let error = errorToThrow { throw error }
        guard let place = createdPlaceToReturn else { XCTFail("createdPlaceToReturn not set"); throw MockError.notConfigured }
        return place
    }

    func updatePlace(id: Int64, update: TripPlaceUpdate) async throws {
        updatePlaceCalls.append((id, update))
        if let error = errorToThrow { throw error }
    }

    func deletePlace(id: Int64) async throws {
        deletePlaceCalls.append(id)
        if let error = errorToThrow { throw error }
    }

    func reorderPlaces(tripId: Int64, placeIds: [Int64]) async throws -> [TripPlace] {
        reorderPlacesCalls.append((tripId, placeIds))
        if let error = errorToThrow { throw error }
        return reorderedPlacesToReturn
    }
}

final class TripPlacesServiceTests: XCTestCase {
    private var sut: MockTripPlacesService!

    override func setUp() {
        super.setUp()
        sut = MockTripPlacesService()
    }

    private func makePlace(id: Int64 = 1, tripId: Int64 = 1, sortOrder: Int = 0,
                           lat: Double? = nil, lng: Double? = nil) -> TripPlace {
        TripPlace(
            id: id, tripId: tripId, legId: nil,
            name: "Place \(id)", notes: nil, date: nil,
            lat: lat, lng: lng, googlePlaceId: nil,
            sortOrder: sortOrder, isRouteAnchor: false,
            visitedAt: nil, rating: nil, createdAt: "2024-01-01"
        )
    }

    func testFetchPlacesReturnsConfiguredPlaces() async throws {
        sut.placesToReturn = [makePlace(id: 1), makePlace(id: 2)]

        let result = try await sut.fetchPlaces(tripId: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(sut.fetchPlacesCalls, [10])
    }

    func testFetchPlacesThrowsConfiguredError() async {
        sut.errorToThrow = NSError(domain: "test", code: 1)

        do {
            _ = try await sut.fetchPlaces(tripId: 1)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual((error as NSError).code, 1)
        }
    }

    func testCreatePlaceRecordsPayload() async throws {
        sut.createdPlaceToReturn = makePlace(id: 5)
        let payload = TripPlaceInsert(tripId: 1, name: "Eiffel Tower", lat: 48.86, lng: 2.29, googlePlaceId: nil, sortOrder: 0)

        let result = try await sut.createPlace(payload: payload)

        XCTAssertEqual(sut.createPlaceCalls.count, 1)
        XCTAssertEqual(sut.createPlaceCalls[0].name, "Eiffel Tower")
        XCTAssertEqual(result.id, 5)
    }

    func testUpdatePlaceRecordsIdAndUpdate() async throws {
        var update = TripPlaceUpdate()
        update.name = "Updated Name"
        update.rating = 5

        try await sut.updatePlace(id: 3, update: update)

        XCTAssertEqual(sut.updatePlaceCalls.count, 1)
        XCTAssertEqual(sut.updatePlaceCalls[0].id, 3)
        XCTAssertEqual(sut.updatePlaceCalls[0].update.name, "Updated Name")
        XCTAssertEqual(sut.updatePlaceCalls[0].update.rating, 5)
    }

    func testDeletePlaceRecordsId() async throws {
        try await sut.deletePlace(id: 7)

        XCTAssertEqual(sut.deletePlaceCalls, [7])
    }

    func testReorderPlacesRecordsTripIdAndPlaceIds() async throws {
        sut.reorderedPlacesToReturn = [makePlace(id: 2), makePlace(id: 1)]

        let result = try await sut.reorderPlaces(tripId: 10, placeIds: [2, 1])

        XCTAssertEqual(sut.reorderPlacesCalls.count, 1)
        XCTAssertEqual(sut.reorderPlacesCalls[0].tripId, 10)
        XCTAssertEqual(sut.reorderPlacesCalls[0].placeIds, [2, 1])
        XCTAssertEqual(result.count, 2)
    }

    func testTripPlaceUpdateClearFieldsEncoding() throws {
        var update = TripPlaceUpdate()
        update.clearDate = true
        update.clearRating = true
        update.name = "Test"

        let data = try JSONEncoder().encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["name"] as? String, "Test")
        XCTAssertTrue(json.keys.contains("date"))
        XCTAssertTrue(json["date"] is NSNull)
        XCTAssertTrue(json.keys.contains("rating"))
        XCTAssertTrue(json["rating"] is NSNull)
        XCTAssertFalse(json.keys.contains("notes"))
    }

    func testTripPlaceUpdateEncodesValueWhenNotCleared() throws {
        var update = TripPlaceUpdate()
        update.date = "2026-07-01"
        update.rating = 4

        let data = try JSONEncoder().encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["date"] as? String, "2026-07-01")
        XCTAssertEqual(json["rating"] as? Int, 4)
    }
}
