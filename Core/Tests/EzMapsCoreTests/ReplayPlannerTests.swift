import XCTest
@testable import EzMapsCore

final class ReplayPlannerTests: XCTestCase {
    let a = Coordinate(latitude: 50.2215, longitude: 8.2680)
    /// 2 km nach Norden, dann 1 km nach Osten
    var track: [Coordinate] {
        let north = (0...40).map { Coordinate(latitude: a.latitude + Double($0) * 50 / 110_540, longitude: a.longitude) }
        let k = 111_320 * cos(a.latitude * .pi / 180)
        let east = (1...20).map { Coordinate(latitude: north.last!.latitude, longitude: a.longitude + Double($0) * 50 / k) }
        return north + east
    }

    func testFrameCountAndEnds() {
        let f = ReplayPlanner().frames(for: track)
        XCTAssertEqual(f.count, 300)
        XCTAssertLessThan(f[0].center.distance(to: a), 1)
        XCTAssertEqual(f[0].progress, 0)
        XCTAssertEqual(f.last!.progress, 1)
        XCTAssertEqual(f.last!.pitch, 0, accuracy: 0.001)
        XCTAssertEqual(f.last!.heading, 0, accuracy: 0.001, "am Ende nach Norden ausgerichtet")
    }

    func testProgressNeverGoesBack() {
        let f = ReplayPlanner().frames(for: track)
        for (x, y) in zip(f, f.dropFirst()) { XCTAssertGreaterThanOrEqual(y.progress, x.progress) }
    }

    func testHeadingFollowsRoadSmoothly() {
        let f = ReplayPlanner().frames(for: track)
        XCTAssert(f[20].heading < 5 || f[20].heading > 355, "fährt nach Norden: \(f[20].heading)")
        let followEnd = Int(0.72 * 299) - 1
        XCTAssertEqual(f[followEnd].heading, 90, accuracy: 15, "fährt am Schluss nach Osten")
        for (x, y) in zip(f, f.dropFirst()) {
            var d = abs(y.heading - x.heading); if d > 180 { d = 360 - d }
            XCTAssertLessThan(d, 12, "keine Sprünge")
        }
    }

    func testFitZoomShowsWholeTrack() {
        let p = ReplayPlanner()
        let z = p.fitZoom(track)
        XCTAssertLessThan(z, p.followZoom)
        // bei z passt die Nord-Süd-Ausdehnung (2 km) in 70 % der Höhe
        let metersPerPoint = 78_271.517 * cos(a.latitude * .pi / 180) / pow(2, z)
        XCTAssertGreaterThanOrEqual(1920 * 0.7 * metersPerPoint, 1995)
    }

    func testShortTrackGivesNoFrames() {
        XCTAssertTrue(ReplayPlanner().frames(for: [a]).isEmpty)
    }
}
