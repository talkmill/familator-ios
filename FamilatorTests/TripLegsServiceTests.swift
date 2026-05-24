import XCTest
@testable import Familator

private enum MockError: Error { case notConfigured }

final class MockTripLegsService: TripLegsServiceProtocol {
    var legsToReturn: [TripLeg] = []
    var createdLegToReturn: TripLeg?
    var reorderedLegsToReturn: [TripLeg] = []
    var errorToThrow: Error?
    var fetchLegsCalls: [Int64] = []
    var createLegCalls: [TripLegInsert] = []
    var updateLegCalls: [(id: Int64, update: TripLegUpdate)] = []
    var deleteLegCalls: [Int64] = []
    var reorderLegsCalls: [(tripId: Int64, legIds: [Int64])] = []

    func fetchLegs(tripId: Int64) async throws -> [TripLeg] {
        fetchLegsCalls.append(tripId)
        if let error = errorToThrow { throw error }
        return legsToReturn
    }

    func createLeg(payload: TripLegInsert) async throws -> TripLeg {
        createLegCalls.append(payload)
        if let error = errorToThrow { throw error }
        guard let leg = createdLegToReturn else { XCTFail("createdLegToReturn not set"); throw MockError.notConfigured }
        return leg
    }

    func updateLeg(id: Int64, update: TripLegUpdate) async throws {
        updateLegCalls.append((id, update))
        if let error = errorToThrow { throw error }
    }

    func deleteLeg(id: Int64) async throws {
        deleteLegCalls.append(id)
        if let error = errorToThrow { throw error }
    }

    func reorderLegs(tripId: Int64, legIds: [Int64]) async throws -> [TripLeg] {
        reorderLegsCalls.append((tripId, legIds))
        if let error = errorToThrow { throw error }
        return reorderedLegsToReturn
    }
}

final class TripLegsServiceTests: XCTestCase {
    private var sut: MockTripLegsService!

    override func setUp() {
        super.setUp()
        sut = MockTripLegsService()
    }

    private func makeLeg(id: Int64 = 1, tripId: Int64 = 1, name: String = "Leg 1",
                         sortOrder: Int = 0, transportMode: TransportMode = .driving) -> TripLeg {
        TripLeg(id: id, tripId: tripId, name: name, sortOrder: sortOrder,
                transportMode: transportMode, createdAt: "2024-01-01")
    }

    func testFetchLegsReturnsConfiguredLegs() async throws {
        sut.legsToReturn = [makeLeg(id: 1), makeLeg(id: 2)]

        let result = try await sut.fetchLegs(tripId: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(sut.fetchLegsCalls, [10])
    }

    func testCreateLegRecordsPayload() async throws {
        sut.createdLegToReturn = makeLeg(id: 5)
        let payload = TripLegInsert(tripId: 1, name: "Day 1", sortOrder: 0, transportMode: .walking)

        let result = try await sut.createLeg(payload: payload)

        XCTAssertEqual(sut.createLegCalls.count, 1)
        XCTAssertEqual(sut.createLegCalls[0].name, "Day 1")
        XCTAssertEqual(sut.createLegCalls[0].transportMode, .walking)
        XCTAssertEqual(result.id, 5)
    }

    func testUpdateLegRecordsIdAndUpdate() async throws {
        var update = TripLegUpdate()
        update.name = "Updated Leg"
        update.transportMode = .cycling

        try await sut.updateLeg(id: 3, update: update)

        XCTAssertEqual(sut.updateLegCalls.count, 1)
        XCTAssertEqual(sut.updateLegCalls[0].id, 3)
        XCTAssertEqual(sut.updateLegCalls[0].update.name, "Updated Leg")
        XCTAssertEqual(sut.updateLegCalls[0].update.transportMode, .cycling)
    }

    func testDeleteLegRecordsId() async throws {
        try await sut.deleteLeg(id: 7)

        XCTAssertEqual(sut.deleteLegCalls, [7])
    }

    func testReorderLegsRecordsTripIdAndLegIds() async throws {
        sut.reorderedLegsToReturn = [makeLeg(id: 3), makeLeg(id: 1)]

        let result = try await sut.reorderLegs(tripId: 5, legIds: [3, 1])

        XCTAssertEqual(sut.reorderLegsCalls.count, 1)
        XCTAssertEqual(sut.reorderLegsCalls[0].tripId, 5)
        XCTAssertEqual(sut.reorderLegsCalls[0].legIds, [3, 1])
        XCTAssertEqual(result.count, 2)
    }

    func testFetchLegsThrowsConfiguredError() async {
        sut.errorToThrow = NSError(domain: "test", code: 99)

        do {
            _ = try await sut.fetchLegs(tripId: 1)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual((error as NSError).code, 99)
        }
    }
}
