import XCTest
@testable import Familator

private enum MockError: Error { case test }

final class MockProfileService: ProfileServiceProtocol {
    var profileToReturn: Profile?
    var errorToThrow: Error?
    var fetchProfileCalls: [UUID] = []
    var updateProfileCalls: [(userId: UUID, displayName: String?, avatarUrl: String?)] = []

    func fetchProfile(userId: UUID) async throws -> Profile? {
        fetchProfileCalls.append(userId)
        if let error = errorToThrow { throw error }
        return profileToReturn
    }

    func updateProfile(userId: UUID, displayName: String?, avatarUrl: String?) async throws {
        updateProfileCalls.append((userId, displayName, avatarUrl))
        if let error = errorToThrow { throw error }
    }
}

@MainActor
final class ProfileViewModelTests: XCTestCase {
    private var sut: ProfileViewModel!
    private var mockService: MockProfileService!
    private let testUserId = UUID()

    override func setUp() {
        super.setUp()
        mockService = MockProfileService()
        sut = ProfileViewModel(profileService: mockService)
    }

    private func makeProfile(displayName: String = "Test User") -> Profile {
        Profile(
            id: 1,
            userId: testUserId,
            displayName: displayName,
            avatarUrl: nil,
            activeWorkspaceId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func testLoadSetsProfileOnSuccess() async {
        mockService.profileToReturn = makeProfile(displayName: "Alice")

        await sut.load(userId: testUserId)

        XCTAssertEqual(sut.profile?.displayName, "Alice")
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(mockService.fetchProfileCalls.count, 1)
    }

    func testLoadSetsErrorOnFailure() async {
        mockService.errorToThrow = NSError(
            domain: NSCocoaErrorDomain,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Network error"]
        )

        await sut.load(userId: testUserId)

        XCTAssertNil(sut.profile)
        XCTAssertEqual(sut.errorMessage, "Network error")
    }

    func testLoadWithNilUserIdResetsState() async {
        mockService.profileToReturn = makeProfile()
        await sut.load(userId: testUserId)
        XCTAssertNotNil(sut.profile)

        await sut.load(userId: nil)

        XCTAssertNil(sut.profile)
        XCTAssertNil(sut.errorMessage)
    }
}
