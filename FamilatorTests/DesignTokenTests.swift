import XCTest
import SwiftUI
@testable import Familator

final class DesignTokenTests: XCTestCase {

    // MARK: - Color hex initializer

    func testColorHexProducesCorrectComponents() {
        let uiColor = UIColor(Color(hex: 0xFBFAF8))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 0xFB / 255.0, accuracy: 0.01)
        XCTAssertEqual(g, 0xFA / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, 0xF8 / 255.0, accuracy: 0.01)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)
    }

    func testColorHexBlack() {
        let uiColor = UIColor(Color(hex: 0x000000))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 0, accuracy: 0.01)
        XCTAssertEqual(g, 0, accuracy: 0.01)
        XCTAssertEqual(b, 0, accuracy: 0.01)
    }

    func testColorHexWithOpacity() {
        let uiColor = UIColor(Color(hex: 0xFF0000, opacity: 0.5))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(a, 0.5, accuracy: 0.01)
    }

    // MARK: - All color tokens exist (smoke test)

    func testAllColorTokensAccessible() {
        _ = Color.appBg
        _ = Color.appSurface
        _ = Color.appSurfaceSoft
        _ = Color.appSurfaceHover
        _ = Color.appSurfaceActive
        _ = Color.appBorder
        _ = Color.appText
        _ = Color.appMuted
        _ = Color.appFocus
        _ = Color.appAccentDashboard
        _ = Color.appAccentTasks
        _ = Color.appAccentCalendar
        _ = Color.appAccentTravel
        _ = Color.appAccentNotes
        _ = Color.appAccentWorkspace
        _ = Color.appAccentSettings
    }

    // MARK: - Font registration

    func testInterRegularRegistered() {
        XCTAssertNotNil(
            UIFont(name: "Inter-Regular", size: 16),
            "Inter-Regular font should be registered"
        )
    }

    func testInterSemiBoldRegistered() {
        XCTAssertNotNil(
            UIFont(name: "Inter-SemiBold", size: 16),
            "Inter-SemiBold font should be registered"
        )
    }

    func testInterBoldRegistered() {
        XCTAssertNotNil(
            UIFont(name: "Inter-Bold", size: 16),
            "Inter-Bold font should be registered"
        )
    }

    func testDMSansRegularRegistered() {
        XCTAssertNotNil(
            UIFont(name: "DMSans-Regular", size: 16),
            "DMSans-Regular font should be registered"
        )
    }

    func testDMSansBoldRegistered() {
        XCTAssertNotNil(
            UIFont(name: "DMSans-Bold", size: 16),
            "DMSans-Bold font should be registered"
        )
    }

    func testDMSansExtraBoldRegistered() {
        XCTAssertNotNil(
            UIFont(name: "DMSans-ExtraBold", size: 16),
            "DMSans-ExtraBold font should be registered"
        )
    }

    // MARK: - Dynamic Type scaling

    func testFontMetricsScalesCustomFont() {
        guard let baseFont = UIFont(name: "Inter-Regular", size: 15) else {
            XCTFail("Inter-Regular must be available for this test")
            return
        }
        let metrics = UIFontMetrics(forTextStyle: .body)
        let scaled = metrics.scaledFont(for: baseFont)
        // At default content size category, scaled size should match base
        XCTAssertEqual(scaled.pointSize, 15, accuracy: 1.0)
    }

    // MARK: - Semantic styles (smoke test)

    func testSemanticStylesDoNotCrash() {
        _ = AppFont.largeTitle
        _ = AppFont.title
        _ = AppFont.title2
        _ = AppFont.title3
        _ = AppFont.headline
        _ = AppFont.body
        _ = AppFont.callout
        _ = AppFont.subheadline
        _ = AppFont.footnote
        _ = AppFont.caption
        _ = AppFont.caption2
    }
}
