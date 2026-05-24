import XCTest
@testable import Familator

final class MockFeatureRequestService: FeatureRequestServiceProtocol {
    var errorToThrow: Error?
    var submitCalls: [(userId: UUID, title: String, description: String?)] = []

    func submit(userId: UUID, title: String, description: String?) async throws {
        submitCalls.append((userId, title, description))
        if let error = errorToThrow { throw error }
    }
}

final class FeatureRequestServiceSeamTests: XCTestCase {
    private let testUserId = UUID()

    func testMockRecordsSubmitCall() async throws {
        let mock = MockFeatureRequestService()

        try await mock.submit(userId: testUserId, title: "Dark mode", description: "Please add dark mode support")

        XCTAssertEqual(mock.submitCalls.count, 1)
        XCTAssertEqual(mock.submitCalls.first?.title, "Dark mode")
        XCTAssertEqual(mock.submitCalls.first?.description, "Please add dark mode support")
    }

    func testMockSubmitWithNilDescription() async throws {
        let mock = MockFeatureRequestService()

        try await mock.submit(userId: testUserId, title: "Bug fix", description: nil)

        XCTAssertEqual(mock.submitCalls.count, 1)
        XCTAssertNil(mock.submitCalls.first?.description)
    }

    func testMockThrowsConfiguredError() async {
        let mock = MockFeatureRequestService()
        mock.errorToThrow = NSError(domain: "test", code: 500)

        do {
            try await mock.submit(userId: testUserId, title: "Test", description: nil)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual((error as NSError).code, 500)
        }
    }
}
