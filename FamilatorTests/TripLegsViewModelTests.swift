import XCTest
@testable import Familator

@MainActor
final class TripLegsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeLeg(
        id: Int64,
        name: String = "Leg",
        sortOrder: Int = 0,
        transportMode: TransportMode = .driving
    ) -> TripLeg {
        TripLeg(
            id: id,
            tripId: 1,
            name: name,
            sortOrder: sortOrder,
            transportMode: transportMode,
            createdAt: "2026-01-01T00:00:00Z"
        )
    }

    // MARK: - Local state tests

    func testInitialStateIsEmpty() {
        let vm = TripLegsViewModel(tripId: 1)
        XCTAssertTrue(vm.legs.isEmpty)
        XCTAssertFalse(vm.isBlockingLoad)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertNil(vm.errorMessage)
    }

    func testDeleteLegRemovesFromLocalArray() {
        let vm = TripLegsViewModel(tripId: 1)
        vm.legs = [makeLeg(id: 1), makeLeg(id: 2), makeLeg(id: 3)]

        vm.legs.removeAll { $0.id == 2 }

        XCTAssertEqual(vm.legs.count, 2)
        XCTAssertEqual(vm.legs.map(\.id), [1, 3])
    }

    func testMoveLegReordersLocalArray() {
        let vm = TripLegsViewModel(tripId: 1)
        vm.legs = [
            makeLeg(id: 1, sortOrder: 0),
            makeLeg(id: 2, sortOrder: 1),
            makeLeg(id: 3, sortOrder: 2)
        ]

        vm.legs.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertEqual(vm.legs.map(\.id), [2, 1, 3])
    }

    func testMoveLegExtractsCorrectIdOrder() {
        let vm = TripLegsViewModel(tripId: 1)
        vm.legs = [
            makeLeg(id: 10, sortOrder: 0),
            makeLeg(id: 20, sortOrder: 1),
            makeLeg(id: 30, sortOrder: 2)
        ]

        vm.legs.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        let orderedIds = vm.legs.map(\.id)

        XCTAssertEqual(orderedIds, [30, 10, 20])
    }

    func testUpdateLegRejectsEmptyName() async {
        let vm = TripLegsViewModel(tripId: 1)
        vm.legs = [makeLeg(id: 1, name: "Leg 1")]

        let result = await vm.updateLeg(id: 1, name: "   ")

        XCTAssertFalse(result)
        XCTAssertEqual(vm.legs[0].name, "Leg 1")
    }

    func testUpdateLegRejectsUnknownId() async {
        let vm = TripLegsViewModel(tripId: 1)
        vm.legs = [makeLeg(id: 1)]

        let result = await vm.updateLeg(id: 999, name: "New Name")

        XCTAssertFalse(result)
    }

    func testLegHashability() {
        let leg1 = makeLeg(id: 1)
        let leg2 = makeLeg(id: 1, name: "Different name")
        let leg3 = makeLeg(id: 2)

        XCTAssertEqual(leg1, leg2)
        XCTAssertNotEqual(leg1, leg3)
    }

    // MARK: - Service integration via mock

    func testLoadFetchesLegsFromService() async {
        let mockService = MockTripLegsService()
        let vm = TripLegsViewModel(tripId: 1, legsService: mockService)
        mockService.legsToReturn = [makeLeg(id: 1), makeLeg(id: 2)]

        await vm.load()

        XCTAssertEqual(vm.legs.count, 2)
        XCTAssertEqual(mockService.fetchLegsCalls, [1])
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadSetsErrorOnFailure() async {
        let mockService = MockTripLegsService()
        let vm = TripLegsViewModel(tripId: 1, legsService: mockService)
        mockService.errorToThrow = NSError(domain: "test", code: 1)

        await vm.load()

        XCTAssertTrue(vm.legs.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testAddLegCallsService() async {
        let mockService = MockTripLegsService()
        let vm = TripLegsViewModel(tripId: 1, legsService: mockService)
        mockService.createdLegToReturn = makeLeg(id: 5, name: "Day 1")

        await vm.addLeg(name: "Day 1")

        XCTAssertEqual(mockService.createLegCalls.count, 1)
        XCTAssertEqual(mockService.createLegCalls[0].name, "Day 1")
        XCTAssertEqual(vm.legs.count, 1)
        XCTAssertEqual(vm.legs[0].id, 5)
    }

    func testDeleteLegCallsServiceAndRemoves() async {
        let mockService = MockTripLegsService()
        let vm = TripLegsViewModel(tripId: 1, legsService: mockService)
        vm.legs = [makeLeg(id: 1), makeLeg(id: 2)]

        await vm.deleteLeg(id: 1)

        XCTAssertEqual(vm.legs.count, 1)
        XCTAssertEqual(vm.legs[0].id, 2)
        XCTAssertEqual(mockService.deleteLegCalls, [1])
    }
}
