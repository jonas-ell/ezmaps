import XCTest
@testable import EzMapsCore

/// GM-050: Helfer für die weiterrechnende Kamera
final class CoordinateMotionTests: XCTestCase {
    let idstein = Coordinate(latitude: 50.21712, longitude: 8.25734)

    func testBearingCardinalDirections() {
        XCTAssertEqual(idstein.bearing(to: Coordinate(latitude: 50.22, longitude: 8.25734)), 0, accuracy: 0.5)
        XCTAssertEqual(idstein.bearing(to: Coordinate(latitude: 50.21712, longitude: 8.26)), 90, accuracy: 0.5)
        XCTAssertEqual(idstein.bearing(to: Coordinate(latitude: 50.21, longitude: 8.25734)), 180, accuracy: 0.5)
        XCTAssertEqual(idstein.bearing(to: Coordinate(latitude: 50.21712, longitude: 8.25)), 270, accuracy: 0.5)
    }

    func testMovedKeepsDistanceAndDirection() {
        for b in [0.0, 45, 90, 200, 315] {
            let p = idstein.moved(meters: 100, bearing: b)
            XCTAssertEqual(idstein.distance(to: p), 100, accuracy: 1)
            XCTAssertEqual(idstein.bearing(to: p), b, accuracy: 1)
        }
    }
}
