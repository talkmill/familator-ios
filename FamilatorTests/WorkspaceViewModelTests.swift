import XCTest
@testable import Familator

final class MockWorkspaceService: WorkspaceServiceProtocol {
    var workspacesToReturn: [Workspace] = []
    var activeWorkspaceIdToReturn: String?
    var updateActiveWorkspaceCalls: [(userId: UUID, workspaceId: String)] = []
    var fetchError: Error?

    func fetchWorkspaces() async throws -> [Workspace] {
        if let error = fetchError { throw error }
        return workspacesToReturn
    }

    func updateActiveWorkspace(userId: UUID, workspaceId: String) async throws {
        updateActiveWorkspaceCalls.append((userId, workspaceId))
    }

    func fetchActiveWorkspaceId(userId: UUID) async throws -> String? {
        return activeWorkspaceIdToReturn
    }
}

@MainActor
final class WorkspaceViewModelTests: XCTestCase {
    private var sut: WorkspaceViewModel!
    private var mockService: MockWorkspaceService!
    private var testDefaults: UserDefaults!
    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        mockService = MockWorkspaceService()
        testDefaults = UserDefaults(suiteName: "WorkspaceViewModelTests")!
        testDefaults.removePersistentDomain(forName: "WorkspaceViewModelTests")
        sut = WorkspaceViewModel(service: mockService, defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "WorkspaceViewModelTests")
        super.tearDown()
    }

    private func makeWorkspace(id: String = "ws1", name: String = "Test", isPersonal: Bool = false) -> Workspace {
        Workspace(
            id: id,
            name: name,
            code: String(name.prefix(2)).uppercased(),
            color: "#6366f1",
            ownerId: testUserId,
            isPersonal: isPersonal,
            createdAt: Date()
        )
    }

    func testLoadWorkspacesSetsActiveFromUserDefaults() async {
        let ws1 = makeWorkspace(id: "ws1", name: "Personal", isPersonal: true)
        let ws2 = makeWorkspace(id: "ws2", name: "Family")
        mockService.workspacesToReturn = [ws1, ws2]
        testDefaults.set("ws2", forKey: WorkspaceViewModel.activeWorkspaceIdKey)

        await sut.loadWorkspaces(userId: testUserId)

        XCTAssertEqual(sut.activeWorkspace?.id, "ws2")
        XCTAssertEqual(sut.workspaces.count, 2)
    }

    func testLoadWorkspacesFallsBackToPersonalIfCachedIdNotFound() async {
        let ws1 = makeWorkspace(id: "ws1", name: "Personal", isPersonal: true)
        let ws2 = makeWorkspace(id: "ws2", name: "Family")
        mockService.workspacesToReturn = [ws1, ws2]
        mockService.activeWorkspaceIdToReturn = nil
        testDefaults.set("stale-id", forKey: WorkspaceViewModel.activeWorkspaceIdKey)

        await sut.loadWorkspaces(userId: testUserId)

        XCTAssertEqual(sut.activeWorkspace?.id, "ws1")
    }

    func testSetActiveWorkspacePersistsToUserDefaults() {
        let ws = makeWorkspace(id: "ws-new", name: "New Workspace")

        sut.setActiveWorkspace(ws, userId: testUserId)

        XCTAssertEqual(testDefaults.string(forKey: WorkspaceViewModel.activeWorkspaceIdKey), "ws-new")
    }

    func testSetActiveWorkspaceUpdatesPublishedProperty() {
        let ws = makeWorkspace(id: "ws-new", name: "New Workspace")

        sut.setActiveWorkspace(ws, userId: testUserId)

        XCTAssertEqual(sut.activeWorkspace?.id, "ws-new")
        XCTAssertEqual(sut.activeWorkspaceId, "ws-new")
    }

    func testSetActiveWorkspaceDismissesPicker() {
        sut.showWorkspacePicker = true
        let ws = makeWorkspace(id: "ws1", name: "Test")

        sut.setActiveWorkspace(ws, userId: testUserId)

        XCTAssertFalse(sut.showWorkspacePicker)
    }

    func testLoadWorkspacesWithErrorResetsState() async {
        mockService.fetchError = NSError(domain: "test", code: 1)

        await sut.loadWorkspaces(userId: testUserId)

        XCTAssertTrue(sut.workspaces.isEmpty)
        XCTAssertNil(sut.activeWorkspace)
    }

    func testResetClearsAllState() {
        sut.workspaces = [makeWorkspace()]
        sut.activeWorkspace = makeWorkspace()
        sut.showWorkspacePicker = true
        testDefaults.set("ws1", forKey: WorkspaceViewModel.activeWorkspaceIdKey)

        sut.reset()

        XCTAssertTrue(sut.workspaces.isEmpty)
        XCTAssertNil(sut.activeWorkspace)
        XCTAssertFalse(sut.showWorkspacePicker)
        XCTAssertNil(testDefaults.string(forKey: WorkspaceViewModel.activeWorkspaceIdKey))
    }

    func testLoadWorkspacesUsesProfileIdWhenCachedIsStale() async {
        let ws1 = makeWorkspace(id: "ws1", name: "Personal", isPersonal: true)
        let ws2 = makeWorkspace(id: "ws2", name: "Family")
        mockService.workspacesToReturn = [ws1, ws2]
        mockService.activeWorkspaceIdToReturn = "ws2"
        testDefaults.set("stale-id", forKey: WorkspaceViewModel.activeWorkspaceIdKey)

        await sut.loadWorkspaces(userId: testUserId)

        XCTAssertEqual(sut.activeWorkspace?.id, "ws2")
        XCTAssertEqual(testDefaults.string(forKey: WorkspaceViewModel.activeWorkspaceIdKey), "ws2")
    }
}
