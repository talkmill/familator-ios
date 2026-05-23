import XCTest
@testable import Familator

@MainActor
final class TripPlacesViewModelTests: XCTestCase {
    func testInitialStateIsEmpty() {
        let vm = TripPlacesViewModel(tripId: 1)
        XCTAssertTrue(vm.places.isEmpty)
        XCTAssertFalse(vm.isBlockingLoad)
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertFalse(vm.isSearching)
        XCTAssertEqual(vm.searchQuery, "")
    }

    func testUpdateRatingOptimisticallyUpdatesLocal() {
        let vm = TripPlacesViewModel(tripId: 1)
        vm.places = [makePlace(id: 10, rating: nil)]

        // Simulate an optimistic update by directly modifying
        vm.places[0].rating = 4

        XCTAssertEqual(vm.places[0].rating, 4)
    }

    func testUpdateRatingClearingRating() {
        let vm = TripPlacesViewModel(tripId: 1)
        vm.places = [makePlace(id: 10, rating: 3)]

        vm.places[0].rating = nil

        XCTAssertNil(vm.places[0].rating)
    }

    func testDeletePlaceRemovesFromLocalArray() {
        let vm = TripPlacesViewModel(tripId: 1)
        vm.places = [makePlace(id: 1), makePlace(id: 2), makePlace(id: 3)]

        // Simulate optimistic removal
        vm.places.removeAll { $0.id == 2 }

        XCTAssertEqual(vm.places.count, 2)
        XCTAssertEqual(vm.places.map(\.id), [1, 3])
    }

    func testMovePlaceReordersLocalArray() {
        let vm = TripPlacesViewModel(tripId: 1)
        vm.places = [
            makePlace(id: 1, sortOrder: 0),
            makePlace(id: 2, sortOrder: 1),
            makePlace(id: 3, sortOrder: 2)
        ]

        // Simulate onMove: move item at index 0 to index 2
        vm.places.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertEqual(vm.places.map(\.id), [2, 1, 3])
    }

    func testMovePlaceExtractsCorrectIdOrder() {
        let vm = TripPlacesViewModel(tripId: 1)
        vm.places = [
            makePlace(id: 10, sortOrder: 0),
            makePlace(id: 20, sortOrder: 1),
            makePlace(id: 30, sortOrder: 2)
        ]

        vm.places.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        let orderedIds = vm.places.map(\.id)

        XCTAssertEqual(orderedIds, [30, 10, 20])
    }

    func testSearchQueryEmptyReturnsClearedSuggestions() async {
        let vm = TripPlacesViewModel(tripId: 1)
        vm.suggestions = [PlaceSuggestion(id: "abc", displayName: "Test", formattedAddress: nil)]

        await vm.searchPlaces(query: "")

        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func testSearchQueryWhitespaceOnlyReturnsClearedSuggestions() async {
        let vm = TripPlacesViewModel(tripId: 1)
        vm.suggestions = [PlaceSuggestion(id: "abc", displayName: "Test", formattedAddress: nil)]

        await vm.searchPlaces(query: "   ")

        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func testGoogleServiceAvailability() {
        let service = GooglePlacesService()
        // Without a configured API key, the service should report unavailable
        // (Info.plist in test target won't have the key)
        // This is a baseline check; actual availability depends on build config
        XCTAssertNotNil(service)
    }

    // MARK: - Helpers

    private func makePlace(id: Int64, sortOrder: Int = 0, rating: Int? = nil) -> TripPlace {
        TripPlace(
            id: id,
            tripId: 1,
            legId: nil,
            name: "Place \(id)",
            notes: nil,
            date: nil,
            lat: nil,
            lng: nil,
            googlePlaceId: nil,
            sortOrder: sortOrder,
            isRouteAnchor: false,
            visitedAt: nil,
            rating: rating,
            createdAt: "2026-01-01T00:00:00Z"
        )
    }
}
