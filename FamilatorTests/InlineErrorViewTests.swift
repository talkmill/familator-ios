import XCTest
@testable import Familator

final class InlineErrorViewTests: XCTestCase {
    func testInitWithMessageOnly() {
        let view = InlineErrorView(message: "Something went wrong")
        XCTAssertEqual(view.message, "Something went wrong")
        XCTAssertNil(view.retryAction)
    }

    func testInitWithMessageAndRetryAction() {
        let view = InlineErrorView(message: "Load failed") {
            // retry
        }
        XCTAssertEqual(view.message, "Load failed")
        XCTAssertNotNil(view.retryAction)
    }
}
