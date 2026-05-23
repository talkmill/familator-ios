import XCTest
@testable import Familator

final class UserFacingAsyncErrorTests: XCTestCase {
    func testAlertMessageReturnsNilForCancellationError() {
        XCTAssertNil(UserFacingAsyncError.alertMessage(from: CancellationError()))
    }

    func testAlertMessageReturnsNilForURLErrorCancelled() {
        XCTAssertNil(UserFacingAsyncError.alertMessage(from: URLError(.cancelled)))
    }

    func testAlertMessageReturnsNilForNSErrorCancelled() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        XCTAssertNil(UserFacingAsyncError.alertMessage(from: error))
    }

    func testAlertMessageReturnsLocalizedDescriptionForNonCancellationError() {
        let message = "Network unavailable"
        let error = NSError(domain: NSCocoaErrorDomain, code: 4, userInfo: [NSLocalizedDescriptionKey: message])

        XCTAssertEqual(UserFacingAsyncError.alertMessage(from: error), message)
    }
}
