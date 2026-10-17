import XCTest
@testable import EzMapsCore

final class MapStyleTests: XCTestCase {
    func testExactlyOneFreeStyle() {
        XCTAssertEqual(MapStyle.allCases.filter(\.isFree).count, 1)
    }

    func testStyleFileNamesAreUnique() {
        let names = MapStyle.allCases.map(\.styleFileName)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testRawValueRoundTrip() {
        for style in MapStyle.allCases {
            XCTAssertEqual(MapStyle(rawValue: style.rawValue), style)
        }
    }
}
