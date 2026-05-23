import XCTest
@testable import Familator

@MainActor
final class ItineraryViewModelTests: XCTestCase {
    func testInitialStateIsEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertTrue(vm.legs.isEmpty)
        XCTAssertTrue(vm.places.isEmpty)
        XCTAssertFalse(vm.isBlockingLoad)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertNil(vm.errorMessage)
    }

    func testDeleteItemRemovesFromLocalArray() {
        let vm = makeViewModel()
        vm.items = [makeItem(id: 1), makeItem(id: 2), makeItem(id: 3)]

        vm.items.removeAll { $0.id == 2 }

        XCTAssertEqual(vm.items.count, 2)
        XCTAssertEqual(vm.items.map(\.id), [1, 3])
    }

    func testMoveItemReordersLocalArray() {
        let vm = makeViewModel()
        vm.items = [
            makeItem(id: 1, sortOrder: 0),
            makeItem(id: 2, sortOrder: 1),
            makeItem(id: 3, sortOrder: 2)
        ]

        vm.items.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertEqual(vm.items.map(\.id), [2, 1, 3])
    }

    func testMoveItemExtractsCorrectIdOrder() {
        let vm = makeViewModel()
        vm.items = [
            makeItem(id: 10, sortOrder: 0),
            makeItem(id: 20, sortOrder: 1),
            makeItem(id: 30, sortOrder: 2)
        ]

        vm.items.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        let orderedIds = vm.items.map(\.id)

        XCTAssertEqual(orderedIds, [30, 10, 20])
    }

    func testGroupedItemsWithNoLegsReturnsSingleGroup() {
        let vm = makeViewModel()
        vm.items = [makeItem(id: 1), makeItem(id: 2)]

        let groups = vm.groupedItems
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].leg)
        XCTAssertEqual(groups[0].items.count, 2)
    }

    func testGroupedItemsGroupsByLeg() {
        let vm = makeViewModel()
        let leg1 = makeLeg(id: 1, name: "London", sortOrder: 0)
        let leg2 = makeLeg(id: 2, name: "Paris", sortOrder: 1)
        vm.legs = [leg1, leg2]
        vm.items = [
            makeItem(id: 1, legId: 1),
            makeItem(id: 2, legId: 2),
            makeItem(id: 3, legId: 1)
        ]

        let groups = vm.groupedItems
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].leg?.id, 1)
        XCTAssertEqual(groups[0].items.count, 2)
        XCTAssertEqual(groups[1].leg?.id, 2)
        XCTAssertEqual(groups[1].items.count, 1)
    }

    func testGroupedItemsUnassignedGroupAppearsLast() {
        let vm = makeViewModel()
        let leg1 = makeLeg(id: 1, name: "London", sortOrder: 0)
        vm.legs = [leg1]
        vm.items = [
            makeItem(id: 1, legId: nil),
            makeItem(id: 2, legId: 1),
            makeItem(id: 3, legId: nil)
        ]

        let groups = vm.groupedItems
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].leg?.id, 1)
        XCTAssertEqual(groups[0].items.count, 1)
        XCTAssertNil(groups[1].leg)
        XCTAssertEqual(groups[1].items.count, 2)
    }

    func testGroupedItemsSkipsEmptyLegGroups() {
        let vm = makeViewModel()
        let leg1 = makeLeg(id: 1, name: "London", sortOrder: 0)
        let leg2 = makeLeg(id: 2, name: "Paris", sortOrder: 1)
        vm.legs = [leg1, leg2]
        vm.items = [makeItem(id: 1, legId: 1)]

        let groups = vm.groupedItems
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].leg?.id, 1)
    }

    func testItemHashability() {
        let item1 = makeItem(id: 1)
        let item2 = makeItem(id: 1, title: "Different title")
        let item3 = makeItem(id: 2)

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }

    func testItineraryItemTypeIcons() {
        for itemType in ItineraryItemType.allCases {
            XCTAssertFalse(itemType.icon.isEmpty, "\(itemType) should have a non-empty icon")
        }
    }

    func testItineraryItemTypeDisplayNames() {
        XCTAssertEqual(ItineraryItemType.flight.displayName, "Flight")
        XCTAssertEqual(ItineraryItemType.hotel.displayName, "Hotel")
        XCTAssertEqual(ItineraryItemType.other.displayName, "Other")
    }

    func testLegNameLookup() {
        let vm = makeViewModel()
        vm.legs = [makeLeg(id: 1, name: "London"), makeLeg(id: 2, name: "Paris")]

        XCTAssertEqual(vm.legName(for: 1), "London")
        XCTAssertEqual(vm.legName(for: 2), "Paris")
        XCTAssertNil(vm.legName(for: 999))
        XCTAssertNil(vm.legName(for: nil))
    }

    func testPlaceNameLookup() {
        let vm = makeViewModel()
        vm.places = [makePlace(id: 1, name: "Big Ben"), makePlace(id: 2, name: "Eiffel Tower")]

        XCTAssertEqual(vm.placeName(for: 1), "Big Ben")
        XCTAssertEqual(vm.placeName(for: 2), "Eiffel Tower")
        XCTAssertNil(vm.placeName(for: 999))
        XCTAssertNil(vm.placeName(for: nil))
    }

    // MARK: - Helpers

    private func makeViewModel() -> ItineraryViewModel {
        ItineraryViewModel(
            tripId: 1,
            workspaceId: "00000000-0000-0000-0000-000000000001",
            ownerId: UUID()
        )
    }

    private func makeItem(
        id: Int64,
        legId: Int64? = nil,
        placeId: Int64? = nil,
        itemType: ItineraryItemType = .activity,
        title: String = "Item",
        date: String? = nil,
        startTime: String? = nil,
        sortOrder: Int = 0
    ) -> TripItineraryItem {
        TripItineraryItem(
            id: id,
            tripId: 1,
            legId: legId,
            placeId: placeId,
            workspaceId: "00000000-0000-0000-0000-000000000001",
            ownerId: UUID(),
            itemType: itemType,
            title: title,
            description: nil,
            date: date,
            startTime: startTime,
            endTime: nil,
            confirmationNumber: nil,
            provider: nil,
            sortOrder: sortOrder,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )
    }

    private func makeLeg(
        id: Int64,
        name: String = "Leg",
        sortOrder: Int = 0
    ) -> TripLeg {
        TripLeg(
            id: id,
            tripId: 1,
            name: name,
            sortOrder: sortOrder,
            transportMode: .driving,
            createdAt: "2026-01-01T00:00:00Z"
        )
    }

    private func makePlace(
        id: Int64,
        name: String = "Place"
    ) -> TripPlace {
        TripPlace(
            id: id,
            tripId: 1,
            legId: nil,
            name: name,
            notes: nil,
            date: nil,
            lat: nil,
            lng: nil,
            googlePlaceId: nil,
            sortOrder: 0,
            isRouteAnchor: false,
            visitedAt: nil,
            rating: nil,
            createdAt: "2026-01-01T00:00:00Z"
        )
    }
}
