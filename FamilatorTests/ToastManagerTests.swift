import XCTest
@testable import Familator

@MainActor
final class ToastManagerTests: XCTestCase {
    func testShowSetsCurrentItem() {
        let manager = ToastManager()

        manager.show(.error, message: "Something failed")

        XCTAssertNotNil(manager.current)
        XCTAssertEqual(manager.current?.variant, .error)
        XCTAssertEqual(manager.current?.message, "Something failed")
    }

    func testShowSuccessVariant() {
        let manager = ToastManager()

        manager.show(.success, message: "Saved!")

        XCTAssertNotNil(manager.current)
        XCTAssertEqual(manager.current?.variant, .success)
        XCTAssertEqual(manager.current?.message, "Saved!")
    }

    func testDismissClearsCurrent() {
        let manager = ToastManager()
        manager.show(.error, message: "Error")

        manager.dismiss()

        XCTAssertNil(manager.current)
    }

    func testShowReplacesExistingToast() {
        let manager = ToastManager()
        manager.show(.error, message: "First")
        let firstId = manager.current?.id

        manager.show(.success, message: "Second")

        XCTAssertNotEqual(manager.current?.id, firstId)
        XCTAssertEqual(manager.current?.message, "Second")
        XCTAssertEqual(manager.current?.variant, .success)
    }

    func testAutoDismissAfterDelay() async throws {
        let manager = ToastManager()
        manager.show(.error, message: "Temporary", duration: 0.1)

        XCTAssertNotNil(manager.current)

        try await Task.sleep(for: .milliseconds(200))

        XCTAssertNil(manager.current)
    }

    func testDismissCancelsAutoDismissTimer() async throws {
        let manager = ToastManager()
        manager.show(.error, message: "Will dismiss manually", duration: 0.5)

        manager.dismiss()

        try await Task.sleep(for: .milliseconds(600))

        // Should still be nil (no crash, no unexpected state)
        XCTAssertNil(manager.current)
    }

    func testToastVariantIcon() {
        XCTAssertEqual(ToastVariant.error.icon, "xmark.circle.fill")
        XCTAssertEqual(ToastVariant.success.icon, "checkmark.circle.fill")
    }

    func testToastVariantIconColor() {
        // Just verify they don't crash — Color equality is not reliable
        _ = ToastVariant.error.iconColor
        _ = ToastVariant.success.iconColor
    }

    func testToastItemIdentityDiffersAcrossInstances() {
        let item1 = ToastItem(variant: .error, message: "Error")
        let item2 = ToastItem(variant: .error, message: "Error")

        XCTAssertNotEqual(item1, item2, "Each ToastItem gets a unique id")
        XCTAssertEqual(item1, item1)
    }

    func testShowAfterDismissIsNotClearedByPriorTimer() async throws {
        let manager = ToastManager()
        manager.show(.error, message: "First", duration: 0.1)

        manager.dismiss()
        manager.show(.success, message: "Second", duration: 5.0)

        // Wait long enough for the first timer to have fired if not cancelled
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertNotNil(manager.current, "Second toast must survive the first timer's expiry")
        XCTAssertEqual(manager.current?.message, "Second")
    }
}
