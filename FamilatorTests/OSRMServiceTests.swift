import CoreLocation
import XCTest
@testable import Familator

final class OSRMServiceTests: XCTestCase {
    func testFetchRouteThrowsForInsufficientCoordinates() async {
        let service = OSRMService.shared
        do {
            _ = try await service.fetchRoute(coords: [CLLocationCoordinate2D(latitude: 0, longitude: 0)])
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is OSRMError)
        }
    }

    func testFetchRouteThrowsForEmptyCoordinates() async {
        let service = OSRMService.shared
        do {
            _ = try await service.fetchRoute(coords: [])
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is OSRMError)
        }
    }

    func testFetchMultiLegRouteReturnsEmptyForNoGroups() async throws {
        let service = OSRMService.shared
        let result = try await service.fetchMultiLegRoute(legGroups: [])
        XCTAssertTrue(result.polylineCoords.isEmpty)
        XCTAssertEqual(result.totalDistanceKm, 0)
        XCTAssertEqual(result.totalDurationMin, 0)
        XCTAssertTrue(result.legs.isEmpty)
    }

    func testFetchMultiLegRouteSkipsGroupsWithSingleCoord() async throws {
        let service = OSRMService.shared
        let groups = [
            LegGroup(mode: .driving, coords: [CLLocationCoordinate2D(latitude: 1, longitude: 1)]),
        ]
        let result = try await service.fetchMultiLegRoute(legGroups: groups)
        XCTAssertEqual(result.legs.count, 1)
        XCTAssertTrue(result.legs[0].polylineCoords.isEmpty)
    }
}
