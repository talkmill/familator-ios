import XCTest
@testable import Familator

final class RouteGroupingTests: XCTestCase {
    // MARK: - Helpers

    private func makeLeg(id: Int64, tripId: Int64 = 1, sortOrder: Int, mode: TransportMode = .driving) -> TripLeg {
        TripLeg(
            id: id, tripId: tripId, name: "Leg \(id)",
            sortOrder: sortOrder, transportMode: mode, createdAt: "2024-01-01"
        )
    }

    private func makePlace(
        id: Int64, tripId: Int64 = 1, legId: Int64? = nil,
        sortOrder: Int, lat: Double? = nil, lng: Double? = nil,
        createdAt: String = "2024-01-01"
    ) -> TripPlace {
        TripPlace(
            id: id, tripId: tripId, legId: legId,
            name: "Place \(id)", notes: nil, date: nil, lat: lat, lng: lng,
            googlePlaceId: nil, sortOrder: sortOrder, isRouteAnchor: false,
            visitedAt: nil, rating: nil, createdAt: createdAt
        )
    }

    private func makeTrip(transportMode: TransportMode = .driving) -> Trip {
        Trip(
            id: 1, listId: 1, ownerId: UUID(), workspaceId: "ws",
            destination: "Test", startDate: nil, endDate: nil,
            destinationLat: nil, destinationLng: nil, destinationPlaceId: nil,
            destinationPlaceName: nil, transportMode: transportMode,
            createdAt: Date(), updatedAt: Date()
        )
    }

    // MARK: - groupPlacesByLeg

    func testGroupPlacesByLegSortsWithinLegs() {
        let legs = [makeLeg(id: 1, sortOrder: 0)]
        let places = [
            makePlace(id: 2, legId: 1, sortOrder: 2),
            makePlace(id: 1, legId: 1, sortOrder: 1),
        ]

        let grouped = RouteGrouping.groupPlacesByLeg(legs: legs, places: places)

        XCTAssertEqual(grouped.byLegId[1]?.map(\.id), [1, 2])
        XCTAssertTrue(grouped.ungrouped.isEmpty)
    }

    func testGroupPlacesByLegTreatsOrphanedPlacesAsUngrouped() {
        let legs = [makeLeg(id: 1, sortOrder: 0)]
        let places = [
            makePlace(id: 1, legId: 1, sortOrder: 0),
            makePlace(id: 2, legId: 999, sortOrder: 0), // non-existent leg
            makePlace(id: 3, legId: nil, sortOrder: 0),
        ]

        let grouped = RouteGrouping.groupPlacesByLeg(legs: legs, places: places)

        XCTAssertEqual(grouped.byLegId[1]?.count, 1)
        XCTAssertEqual(grouped.ungrouped.count, 2)
    }

    func testGroupPlacesByLegCreatesEmptyEntriesForEmptyLegs() {
        let legs = [makeLeg(id: 1, sortOrder: 0), makeLeg(id: 2, sortOrder: 1)]
        let places: [TripPlace] = []

        let grouped = RouteGrouping.groupPlacesByLeg(legs: legs, places: places)

        XCTAssertEqual(grouped.byLegId[1]?.count, 0)
        XCTAssertEqual(grouped.byLegId[2]?.count, 0)
    }

    // MARK: - flattenGroupedPlaces

    func testFlattenGroupedPlacesRespectsLegSortOrder() {
        let legs = [makeLeg(id: 2, sortOrder: 1), makeLeg(id: 1, sortOrder: 0)]
        let places = [
            makePlace(id: 10, legId: 1, sortOrder: 0),
            makePlace(id: 20, legId: 2, sortOrder: 0),
            makePlace(id: 30, legId: nil, sortOrder: 0),
        ]

        let grouped = RouteGrouping.groupPlacesByLeg(legs: legs, places: places)
        let flat = RouteGrouping.flattenGroupedPlaces(legs: legs, grouped: grouped)

        XCTAssertEqual(flat.map(\.id), [10, 20, 30])
    }

    // MARK: - buildLegGroups

    func testBuildLegGroupsUsesLegTransportMode() {
        let legs = [
            makeLeg(id: 1, sortOrder: 0, mode: .walking),
            makeLeg(id: 2, sortOrder: 1, mode: .cycling),
        ]
        let places = [
            makePlace(id: 1, legId: 1, sortOrder: 0, lat: 1, lng: 1),
            makePlace(id: 2, legId: 2, sortOrder: 0, lat: 2, lng: 2),
        ]

        let groups = RouteGrouping.buildLegGroups(trip: makeTrip(), legs: legs, places: places)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].mode, .walking)
        XCTAssertEqual(groups[1].mode, .cycling)
    }

    func testBuildLegGroupsUsesTripModeForUngrouped() {
        let trip = makeTrip(transportMode: .cycling)
        let places = [
            makePlace(id: 1, legId: nil, sortOrder: 0, lat: 1, lng: 1),
            makePlace(id: 2, legId: nil, sortOrder: 1, lat: 2, lng: 2),
        ]

        let groups = RouteGrouping.buildLegGroups(trip: trip, legs: [], places: places)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].mode, .cycling)
        XCTAssertEqual(groups[0].coords.count, 2)
    }

    func testBuildLegGroupsSkipsPlacesWithoutCoordinates() {
        let places = [
            makePlace(id: 1, legId: nil, sortOrder: 0, lat: nil, lng: nil),
            makePlace(id: 2, legId: nil, sortOrder: 1, lat: 2, lng: 2),
        ]

        let groups = RouteGrouping.buildLegGroups(trip: makeTrip(), legs: [], places: places)

        XCTAssertEqual(groups.first?.coords.count, 1)
    }
}
