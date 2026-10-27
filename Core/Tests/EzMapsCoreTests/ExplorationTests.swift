import XCTest
@testable import EzMapsCore

final class ExplorationTests: XCTestCase {
    let a = Coordinate(latitude: 50.2215, longitude: 8.2680)

    /// Gerade Strecke mit einem GPS-Punkt alle 50 m (wie echte Fahrten, keine Lücken)
    func line(meters: Double, from s: Coordinate, east: Bool = true) -> [Coordinate] {
        let n = max(1, Int(meters / 50))
        let dLon = meters / (111_320 * cos(s.latitude * .pi / 180)), dLat = meters / 110_540
        return (0...n).map { i in
            let t = Double(i) / Double(n)
            return east ? Coordinate(latitude: s.latitude, longitude: s.longitude + dLon * t) : Coordinate(latitude: s.latitude + dLat * t, longitude: s.longitude)
        }
    }

    func testCellSizeAndRoundTrip() {
        let k = ExploreCell.key(a)
        let c = ExploreCell.center(k)
        XCTAssertLessThan(a.distance(to: c), 25, "Zellmitte liegt in der Zelle")
        XCTAssertEqual(ExploreCell.key(c), k)
        // 1 km nach Osten ≈ 1000 / 24,5 m ≈ 41 Zellen
        let n = ExploreCell.cells(along: line(meters: 1000, from: a)).count
        XCTAssert((38...44).contains(n), "\(n)")
    }

    func testKeyFitsJavaScriptNumbers() {
        XCTAssertLessThan(ExploreCell.key(Coordinate(latitude: -85, longitude: 179.99)), UInt64(1) << 53)
    }

    func testGapsAreNotFilled() {
        let far = [a, line(meters: 5000, from: a).last!]
        XCTAssertEqual(ExploreCell.cells(along: far).count, 2, "Tunnel/GPS-Lücke deckt nichts dazwischen auf")
    }

    func testTripRevealOnlyCountsNewCells() {
        var s = ExplorationStore()
        let r1 = s.addTrip(line(meters: 500, from: a))
        XCTAssertEqual(r1.newPercent, 100)
        let r2 = s.addTrip(line(meters: 500, from: a))
        XCTAssertEqual(r2.newPercent, 0)
        XCTAssertTrue(r2.newCells.isEmpty)
        let r3 = s.addTrip(line(meters: 1000, from: a))
        XCTAssert((45...55).contains(r3.newPercent), "\(r3.newPercent)")
        XCTAssertEqual(s.trips, 3)
        XCTAssertEqual(s.totalMeters, 2000, accuracy: 5)
    }

    func testNewShareOfPlannedRoute() {
        var s = ExplorationStore()
        s.addTrip(line(meters: 500, from: a))
        XCTAssertEqual(s.newShare(of: line(meters: 500, from: a)), 0, accuracy: 0.001)
        XCTAssertEqual(s.newShare(of: line(meters: 500, from: a, east: false)), 1, accuracy: 0.05)
    }

    func testDistrictShareAndLevels() {
        var s = ExplorationStore()
        let road = Set(ExploreCell.cells(along: line(meters: 1000, from: a)))
        s.addTrip(line(meters: 300, from: a))
        let share = s.share(of: road)
        XCTAssertEqual(share, 0.3, accuracy: 0.05)
        XCTAssertEqual(ExploreLevel.forShare(share).number, 3)
        XCTAssertEqual(ExploreLevel.forShare(share).title, "Kenner")
        XCTAssertEqual(ExploreLevel.forShare(0).number, 1)
        XCTAssertNil(ExploreLevel.forShare(0.9).next)
    }

    func testBadges() {
        var s = ExplorationStore()
        // 12 km in 300-m-Schritten (ein Sprung über 400 m gälte als GPS-Lücke)
        var track = [a]
        for _ in 0..<40 { track.append(contentsOf: line(meters: 300, from: track.last!).dropFirst()) }
        s.addTrip(track)
        let got = Badge.earned(store: s, hour: 23, bestDistrict: 0.2, cityShare: 0.3, have: [])
        XCTAssertEqual(Set(got), [.firstDrive, .km10, .nightOwl, .explorer25])
        XCTAssertTrue(Badge.earned(store: s, hour: 12, bestDistrict: 0, cityShare: 0, have: [.firstDrive, .km10]).isEmpty)
    }

    func testStoreIsCodable() throws {
        var s = ExplorationStore(); s.addTrip(line(meters: 200, from: a))
        let back = try JSONDecoder().decode(ExplorationStore.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }
}
