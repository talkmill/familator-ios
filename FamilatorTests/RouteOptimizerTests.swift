import XCTest
@testable import Familator

final class RouteOptimizerTests: XCTestCase {
    private func makePlace(
        id: Int64, tripId: Int64 = 1, legId: Int64? = nil,
        sortOrder: Int, lat: Double? = nil, lng: Double? = nil,
        isRouteAnchor: Bool = false,
        createdAt: String = "2024-01-01"
    ) -> TripPlace {
        TripPlace(
            id: id, tripId: tripId, legId: legId,
            name: "Place \(id)", notes: nil, date: nil, lat: lat, lng: lng,
            googlePlaceId: nil, sortOrder: sortOrder, isRouteAnchor: isRouteAnchor,
            visitedAt: nil, rating: nil, createdAt: createdAt
        )
    }

    func testOptimizeRouteEmptyInput() {
        let result = RouteOptimizer.optimizeRoute([])
        XCTAssertTrue(result.isEmpty)
    }

    func testOptimizeRouteSinglePlace() {
        let place = makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522)
        let result = RouteOptimizer.optimizeRoute([place])
        XCTAssertEqual(result.map(\.id), [1])
    }

    func testOptimizeRouteTwoPlaces() {
        let places = [
            makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522),
            makePlace(id: 2, sortOrder: 1, lat: 51.5074, lng: -0.1278),
        ]
        let result = RouteOptimizer.optimizeRoute(places)
        XCTAssertEqual(result.map(\.id), [1, 2])
    }

    func testOptimizeRoutePreservesAnchorStart() {
        let places = [
            makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522, isRouteAnchor: true),
            makePlace(id: 2, sortOrder: 1, lat: 35.6762, lng: 139.6503),
            makePlace(id: 3, sortOrder: 2, lat: 51.5074, lng: -0.1278),
            makePlace(id: 4, sortOrder: 3, lat: 40.7128, lng: -74.0060),
        ]
        let result = RouteOptimizer.optimizeRoute(places)
        XCTAssertEqual(result.first?.id, 1)
        XCTAssertEqual(result.count, 4)
    }

    func testOptimizeRoutePreservesAnchorEnd() {
        let places = [
            makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522),
            makePlace(id: 2, sortOrder: 1, lat: 35.6762, lng: 139.6503),
            makePlace(id: 3, sortOrder: 2, lat: 51.5074, lng: -0.1278),
            makePlace(id: 4, sortOrder: 3, lat: 40.7128, lng: -74.0060, isRouteAnchor: true),
        ]
        let result = RouteOptimizer.optimizeRoute(places)
        XCTAssertEqual(result.last?.id, 4)
        XCTAssertEqual(result.count, 4)
    }

    func testOptimizeRoutePreservesBothAnchors() {
        let places = [
            makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522, isRouteAnchor: true),
            makePlace(id: 2, sortOrder: 1, lat: 35.6762, lng: 139.6503),
            makePlace(id: 3, sortOrder: 2, lat: 51.5074, lng: -0.1278),
            makePlace(id: 4, sortOrder: 3, lat: 40.7128, lng: -74.0060, isRouteAnchor: true),
        ]
        let result = RouteOptimizer.optimizeRoute(places)
        XCTAssertEqual(result.first?.id, 1)
        XCTAssertEqual(result.last?.id, 4)
        XCTAssertEqual(result.count, 4)
    }

    func testOptimizeRouteReordersMiddlePlaces() {
        let places = [
            makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522),
            makePlace(id: 2, sortOrder: 1, lat: 55.7558, lng: 37.6173),
            makePlace(id: 3, sortOrder: 2, lat: 41.0082, lng: 28.9784),
            makePlace(id: 4, sortOrder: 3, lat: 52.2297, lng: 21.0122),
            makePlace(id: 5, sortOrder: 4, lat: 52.5200, lng: 13.4050),
        ]
        let result = RouteOptimizer.optimizeRoute(places)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(Set(result.map(\.id)), Set(places.map(\.id)))
        let originalDist = RouteOptimizer.totalDistance(places)
        let optimizedDist = RouteOptimizer.totalDistance(result)
        XCTAssertLessThanOrEqual(optimizedDist, originalDist + 1e-6)
    }

    func testOptimizeRouteKeepsNoCoordInOriginalSlots() {
        let places = [
            makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522),
            makePlace(id: 2, sortOrder: 1),
            makePlace(id: 3, sortOrder: 2, lat: 35.6762, lng: 139.6503),
            makePlace(id: 4, sortOrder: 3),
            makePlace(id: 5, sortOrder: 4, lat: 51.5074, lng: -0.1278),
        ]
        let result = RouteOptimizer.optimizeRoute(places)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[1].id, 2)
        XCTAssertEqual(result[3].id, 4)
    }

    func testOptimizeRouteAllAnchored() {
        let places = [
            makePlace(id: 1, sortOrder: 0, lat: 48.8566, lng: 2.3522, isRouteAnchor: true),
            makePlace(id: 2, sortOrder: 1, lat: 51.5074, lng: -0.1278, isRouteAnchor: true),
        ]
        let result = RouteOptimizer.optimizeRoute(places)
        XCTAssertEqual(result.map(\.id), [1, 2])
    }

    func testHaversineKmKnownDistance() {
        let paris = (lat: 48.8566, lng: 2.3522)
        let london = (lat: 51.5074, lng: -0.1278)
        let dist = RouteOptimizer.haversineKm(paris, london)
        XCTAssertEqual(dist, 343.0, accuracy: 5.0)
    }
}
