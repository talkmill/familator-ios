import XCTest
@testable import Familator

@MainActor
final class WorkListsViewModelTests: XCTestCase {
    private var mockLists: MockListsService!
    private var sut: WorkListsViewModel!
    private let testUserId = UUID()
    private let testWorkspaceId = "ws-1"

    override func setUp() {
        super.setUp()
        mockLists = MockListsService()
        sut = WorkListsViewModel(listsService: mockLists)
    }

    private func makeList(id: Int64 = 1, name: String = "Test") -> FamilatorList {
        let data = try! JSONSerialization.data(withJSONObject: [
            "id": id, "owner_id": testUserId.uuidString, "name": name,
            "is_shared": false,
            "created_at": "2026-01-01T00:00:00+00:00",
            "updated_at": "2026-01-01T00:00:00+00:00",
        ])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(FamilatorList.self, from: data)
    }

    func testLoad_populatesLists() async {
        let list1 = makeList(id: 1, name: "Work")
        let list2 = makeList(id: 2, name: "Personal")

        mockLists.fetchListsHandler = { _, _ in [list1, list2] }

        await sut.load(workspaceId: testWorkspaceId, userId: testUserId)

        XCTAssertEqual(sut.lists.count, 2)
        XCTAssertEqual(sut.lists[0].name, "Work")
        XCTAssertEqual(sut.lists[1].name, "Personal")
    }

    func testLoad_withNilUserId_resets() async {
        sut.lists = [makeList()]

        await sut.load(workspaceId: testWorkspaceId, userId: nil)

        XCTAssertTrue(sut.lists.isEmpty)
    }
}
