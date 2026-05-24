import XCTest
@testable import Familator

final class MockDashboardService: DashboardServiceProtocol {
    var favoritesToReturn: [DashboardFavoriteRow] = []
    var errorToThrow: Error?
    var fetchFavoritesCalls: [UUID] = []
    var setFavoritesCalls: [(userId: UUID, favorites: [DashboardFavoriteInput])] = []

    func fetchFavorites(userId: UUID) async throws -> [DashboardFavoriteRow] {
        fetchFavoritesCalls.append(userId)
        if let error = errorToThrow { throw error }
        return favoritesToReturn
    }

    func setFavorites(userId: UUID, favorites: [DashboardFavoriteInput]) async throws {
        setFavoritesCalls.append((userId, favorites))
        if let error = errorToThrow { throw error }
    }
}

final class DashboardServiceSeamTests: XCTestCase {
    private let testUserId = UUID()

    func testMockReturnsFavorites() async throws {
        let mock = MockDashboardService()
        let row = DashboardFavoriteRow(
            userId: testUserId,
            position: 0,
            itemType: DashboardFavoriteRow.typeList,
            listId: 42,
            filterKey: nil
        )
        mock.favoritesToReturn = [row]

        let result = try await mock.fetchFavorites(userId: testUserId)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.listId, 42)
        XCTAssertEqual(mock.fetchFavoritesCalls.count, 1)
    }

    func testMockRecordsSetFavorites() async throws {
        let mock = MockDashboardService()
        let input = DashboardFavoriteInput(itemType: DashboardFavoriteRow.typeFilter, listId: nil, filterKey: "due-now")

        try await mock.setFavorites(userId: testUserId, favorites: [input])

        XCTAssertEqual(mock.setFavoritesCalls.count, 1)
        XCTAssertEqual(mock.setFavoritesCalls.first?.favorites.first?.filterKey, "due-now")
    }

    func testMockThrowsConfiguredError() async {
        let mock = MockDashboardService()
        mock.errorToThrow = NSError(domain: "test", code: 1)

        do {
            _ = try await mock.fetchFavorites(userId: testUserId)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }
}
