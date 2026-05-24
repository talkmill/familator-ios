import XCTest
@testable import Familator

private enum MockError: Error { case notConfigured }

final class MockTripItineraryService: TripItineraryServiceProtocol {
    var itemsToReturn: [TripItineraryItem] = []
    var createdItemToReturn: TripItineraryItem?
    var reorderedItemsToReturn: [TripItineraryItem] = []
    var errorToThrow: Error?
    var fetchItemsCalls: [Int64] = []
    var createItemCalls: [TripItineraryItemInsert] = []
    var updateItemCalls: [(id: Int64, update: TripItineraryItemUpdate)] = []
    var deleteItemCalls: [Int64] = []
    var reorderItemsCalls: [(tripId: Int64, itemIds: [Int64])] = []

    func fetchItems(tripId: Int64) async throws -> [TripItineraryItem] {
        fetchItemsCalls.append(tripId)
        if let error = errorToThrow { throw error }
        return itemsToReturn
    }

    func createItem(payload: TripItineraryItemInsert) async throws -> TripItineraryItem {
        createItemCalls.append(payload)
        if let error = errorToThrow { throw error }
        guard let item = createdItemToReturn else { XCTFail("createdItemToReturn not set"); throw MockError.notConfigured }
        return item
    }

    func updateItem(id: Int64, update: TripItineraryItemUpdate) async throws {
        updateItemCalls.append((id, update))
        if let error = errorToThrow { throw error }
    }

    func deleteItem(id: Int64) async throws {
        deleteItemCalls.append(id)
        if let error = errorToThrow { throw error }
    }

    func reorderItems(tripId: Int64, itemIds: [Int64]) async throws -> [TripItineraryItem] {
        reorderItemsCalls.append((tripId, itemIds))
        if let error = errorToThrow { throw error }
        return reorderedItemsToReturn
    }
}

final class TripItineraryServiceTests: XCTestCase {
    private var sut: MockTripItineraryService!
    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        sut = MockTripItineraryService()
    }

    private func makeItem(id: Int64 = 1, tripId: Int64 = 1, itemType: ItineraryItemType = .flight,
                          title: String = "Item", sortOrder: Int = 0) -> TripItineraryItem {
        TripItineraryItem(
            id: id, tripId: tripId, legId: nil, placeId: nil,
            workspaceId: "ws1", ownerId: testUserId,
            itemType: itemType, title: title, description: nil,
            date: nil, startTime: nil, endTime: nil,
            confirmationNumber: nil, provider: nil,
            sortOrder: sortOrder, createdAt: "2024-01-01", updatedAt: "2024-01-01"
        )
    }

    func testFetchItemsReturnsConfiguredItems() async throws {
        sut.itemsToReturn = [makeItem(id: 1, title: "Flight"), makeItem(id: 2, title: "Hotel")]

        let result = try await sut.fetchItems(tripId: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].title, "Flight")
        XCTAssertEqual(sut.fetchItemsCalls, [10])
    }

    func testCreateItemRecordsPayload() async throws {
        sut.createdItemToReturn = makeItem(id: 5)
        let payload = TripItineraryItemInsert(
            tripId: 1, workspaceId: testUserId, ownerId: testUserId,
            itemType: .hotel, title: "Hilton", sortOrder: 0
        )

        let result = try await sut.createItem(payload: payload)

        XCTAssertEqual(sut.createItemCalls.count, 1)
        XCTAssertEqual(sut.createItemCalls[0].title, "Hilton")
        XCTAssertEqual(sut.createItemCalls[0].itemType, .hotel)
        XCTAssertEqual(result.id, 5)
    }

    func testUpdateItemRecordsIdAndUpdate() async throws {
        var update = TripItineraryItemUpdate()
        update.title = "Updated Flight"
        update.confirmationNumber = "ABC123"

        try await sut.updateItem(id: 3, update: update)

        XCTAssertEqual(sut.updateItemCalls.count, 1)
        XCTAssertEqual(sut.updateItemCalls[0].id, 3)
        XCTAssertEqual(sut.updateItemCalls[0].update.title, "Updated Flight")
        XCTAssertEqual(sut.updateItemCalls[0].update.confirmationNumber, "ABC123")
    }

    func testDeleteItemRecordsId() async throws {
        try await sut.deleteItem(id: 7)

        XCTAssertEqual(sut.deleteItemCalls, [7])
    }

    func testReorderItemsRecordsTripIdAndItemIds() async throws {
        sut.reorderedItemsToReturn = [makeItem(id: 3), makeItem(id: 1)]

        let result = try await sut.reorderItems(tripId: 5, itemIds: [3, 1])

        XCTAssertEqual(sut.reorderItemsCalls.count, 1)
        XCTAssertEqual(sut.reorderItemsCalls[0].tripId, 5)
        XCTAssertEqual(sut.reorderItemsCalls[0].itemIds, [3, 1])
        XCTAssertEqual(result.count, 2)
    }

    func testItineraryItemUpdateClearFieldsEncoding() throws {
        var update = TripItineraryItemUpdate()
        update.clearDescription = true
        update.clearConfirmationNumber = true
        update.title = "Test"

        let data = try JSONEncoder().encode(update)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["title"] as? String, "Test")
        XCTAssertTrue(json.keys.contains("description"))
        XCTAssertTrue(json["description"] is NSNull)
        XCTAssertTrue(json.keys.contains("confirmation_number"))
        XCTAssertTrue(json["confirmation_number"] is NSNull)
        XCTAssertFalse(json.keys.contains("provider"))
    }
}
