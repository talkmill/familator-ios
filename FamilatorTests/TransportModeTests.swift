import XCTest
@testable import Familator

final class TransportModeTests: XCTestCase {
    func testOsrmProfileMatchesRawValue() {
        for mode in TransportMode.allCases {
            XCTAssertEqual(mode.osrmProfile, mode.rawValue)
        }
    }

    func testAllCasesHaveSystemImages() {
        for mode in TransportMode.allCases {
            XCTAssertFalse(mode.systemImage.isEmpty)
        }
    }

    func testAllCasesHaveDisplayNames() {
        for mode in TransportMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
        }
    }

    func testDecodingFromJSON() throws {
        let json = #"{"mode": "walking"}"#
        struct Wrapper: Decodable { let mode: TransportMode }
        let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.mode, .walking)
    }
}
