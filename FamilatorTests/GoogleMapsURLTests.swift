import XCTest
@testable import Familator

final class GoogleMapsURLTests: XCTestCase {
    private func makePlace(
        id: Int64, name: String, lat: Double?, lng: Double?,
        googlePlaceId: String? = nil
    ) -> TripPlace {
        TripPlace(
            id: id, tripId: 1, legId: nil,
            name: name, notes: nil, date: nil, lat: lat, lng: lng,
            googlePlaceId: googlePlaceId, sortOrder: Int(id),
            isRouteAnchor: false, visitedAt: nil, rating: nil,
            createdAt: "2024-01-01"
        )
    }

    func testReturnsNilForFewerThanTwoGeocodedPlaces() {
        let places = [makePlace(id: 1, name: "A", lat: nil, lng: nil)]
        XCTAssertNil(GoogleMapsURL.build(from: places))
    }

    func testReturnsNilForEmptyPlaces() {
        XCTAssertNil(GoogleMapsURL.build(from: []))
    }

    func testBuildsURLWithOriginAndDestination() {
        let places = [
            makePlace(id: 1, name: "Paris", lat: 48.85, lng: 2.35),
            makePlace(id: 2, name: "London", lat: 51.50, lng: -0.12),
        ]

        let url = GoogleMapsURL.build(from: places)

        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("origin=Paris"))
        XCTAssertTrue(urlString.contains("destination=London"))
        XCTAssertTrue(urlString.contains("travelmode=driving"))
    }

    func testBuildsURLWithWaypoints() {
        let places = [
            makePlace(id: 1, name: "A", lat: 1, lng: 1),
            makePlace(id: 2, name: "B", lat: 2, lng: 2),
            makePlace(id: 3, name: "C", lat: 3, lng: 3),
        ]

        let url = GoogleMapsURL.build(from: places)

        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("waypoints=B"))
    }

    func testIncludesPlaceIdsWhenAllPresent() {
        let places = [
            makePlace(id: 1, name: "A", lat: 1, lng: 1, googlePlaceId: "ChIJ1"),
            makePlace(id: 2, name: "B", lat: 2, lng: 2, googlePlaceId: "ChIJ2"),
        ]

        let url = GoogleMapsURL.build(from: places)

        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("origin_place_id=ChIJ1"))
        XCTAssertTrue(urlString.contains("destination_place_id=ChIJ2"))
    }

    func testSkipsNonGeocodedPlaces() {
        let places = [
            makePlace(id: 1, name: "A", lat: 1, lng: 1),
            makePlace(id: 2, name: "NoCoords", lat: nil, lng: nil),
            makePlace(id: 3, name: "B", lat: 2, lng: 2),
        ]

        let url = GoogleMapsURL.build(from: places)

        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertFalse(urlString.contains("NoCoords"))
    }

    func testReplacesAndPipesInNames() {
        let places = [
            makePlace(id: 1, name: "A|B", lat: 1, lng: 1),
            makePlace(id: 2, name: "C", lat: 2, lng: 2),
        ]

        let url = GoogleMapsURL.build(from: places)

        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertFalse(urlString.contains("A|B"))
        XCTAssertTrue(urlString.contains("A%20B") || urlString.contains("A+B"))
    }
}
