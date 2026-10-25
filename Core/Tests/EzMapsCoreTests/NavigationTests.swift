import XCTest
@testable import EzMapsCore

/// GM-020: Navigation aus GPS-Positionen (Fortschritt, Ansagen, Neuberechnung, Ankunft) und Formatierung.
final class NavigationTests: XCTestCase {
    /// Gerade Strecke nach Osten auf 50° N, 20 Teilstücke à ~71,6 m (~1431 m); Abbiegung bei 700 m
    func makeRoute() -> Route {
        let shape = (0...20).map { Coordinate(latitude: 50, longitude: 8 + Double($0) * 0.001) }
        var r = Route(shape: shape, duration: 180, maneuvers: [], segmentNames: Array(repeating: "Bahnhofstraße", count: 20), segmentSpeeds: Array(repeating: 50, count: 20))
        r.maneuvers = [
            Maneuver(distance: 700, kind: .right, text: "Rechts abbiegen", street: "Hauptstraße"),
            Maneuver(distance: r.length, kind: .destination, text: "Ziel erreicht", street: ""),
        ]
        return r
    }

    /// Punkt `meters` hinter dem Start auf der Route (optional seitlich versetzt nach Norden)
    func point(_ meters: Double, north: Double = 0) -> Coordinate {
        let kx: Double = cos(50 * Double.pi / 180) * 111_320
        return Coordinate(latitude: 50 + north / 110_540, longitude: 8 + meters / kx)
    }

    func testProgressFollowsPositionAndShowsNextManeuver() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Römerberg")
        let u = s.update(position: point(300, north: 8))
        XCTAssertEqual(u.state.progress, 300, accuracy: 3)
        XCTAssertEqual(u.state.distanceToManeuver, 400, accuracy: 3)
        XCTAssertEqual(u.state.maneuver?.street, "Hauptstraße")
        XCTAssertEqual(u.state.currentStreet, "Bahnhofstraße")
        XCTAssertFalse(u.state.offRoute)
        XCTAssertFalse(u.shouldReroute)
        XCTAssertEqual(u.state.remainingTime, 180 * (u.state.remainingDistance / s.route.length), accuracy: 0.01)
    }

    func testAnnouncementsInCityOnceEach() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Römerberg")
        var said: [String] = []
        for m in stride(from: 0.0, through: 760, by: 10) {
            if let a = s.update(position: point(m), speed: 13).announcement { said.append(a) }
        }
        XCTAssertEqual(said, [
            "In 400 Metern rechts abbiegen auf Hauptstraße.",
            "In 150 Metern rechts abbiegen auf Hauptstraße.",
            "Jetzt rechts abbiegen auf Hauptstraße.",
        ])
    }

    func testGpsJitterBackwardsDoesNotRepeat() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Ziel")
        _ = s.update(position: point(300))
        let a = s.update(position: point(310), speed: 10).announcement
        XCTAssertNotNil(a)
        _ = s.update(position: point(295), speed: 10) // kleiner Rücksprung
        XCTAssertEqual(s.progress, 310, accuracy: 3)
        XCTAssertNil(s.update(position: point(312), speed: 10).announcement)
    }

    func testOffRouteTriggersRerouteOnce() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Ziel")
        _ = s.update(position: point(200))
        let t0 = Date(timeIntervalSince1970: 1000)
        let u1 = s.update(position: point(220, north: 60), now: t0)
        XCTAssertTrue(u1.state.offRoute)
        XCTAssertTrue(u1.shouldReroute)
        XCTAssertNil(u1.announcement)
        let u2 = s.update(position: point(230, north: 60), now: t0.addingTimeInterval(2))
        XCTAssertFalse(u2.shouldReroute) // Sperrzeit
    }

    func testArrivalAnnouncedOnce() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Römerberg")
        for m in stride(from: 0.0, through: 1400, by: 20) { _ = s.update(position: point(m), speed: 10) }
        let u = s.update(position: point(1420), speed: 3)
        XCTAssertTrue(u.state.arrived || s.arrived)
        var texts: [String] = []
        if let a = u.announcement { texts.append(a) }
        if let a = s.update(position: point(1425)).announcement { texts.append(a) }
        XCTAssertEqual(texts.filter { $0 == "Sie haben Römerberg erreicht." }.count, 1)
    }

    func testReplaceRouteStartsOver() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Ziel")
        _ = s.update(position: point(500))
        s.replaceRoute(makeRoute())
        XCTAssertEqual(s.progress, 0)
        XCTAssertNotNil(s.update(position: point(310), speed: 10).announcement)
    }

    func testHighwayThresholdsStartEarlier() {
        XCTAssertEqual(NavigationSession.thresholds(speed: 33).first?.0, 2000)
        XCTAssertEqual(NavigationSession.thresholds(speed: 10).first?.0, 400)
    }

    func testStartAnnouncement() {
        let s = NavigationSession(route: makeRoute(), destinationName: "Römerberg")
        XCTAssertEqual(s.startAnnouncement(), "Route nach Römerberg gestartet. 3 Minuten.")
    }

    func testCoordinateAndHeadingAlongRoute() {
        let r = makeRoute()
        let c = r.coordinate(at: 300)!
        XCTAssertEqual(c.distance(to: point(300)), 0, accuracy: 1)
        XCTAssertEqual(r.heading(at: 300), 90, accuracy: 0.5) // nach Osten
        XCTAssertEqual(r.coordinate(at: 99_999)!.distance(to: r.shape.last!), 0, accuracy: 0.5)
    }

    func testJumpAheadAfterTunnelIsNotOffRoute() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Ziel")
        _ = s.update(position: point(100))
        let u = s.update(position: point(1000))
        XCTAssertFalse(u.state.offRoute)
        XCTAssertEqual(u.state.progress, 1000, accuracy: 3)
    }

    func testSpeedLimitsKeepProgress() {
        var s = NavigationSession(route: makeRoute(), destinationName: "Ziel")
        _ = s.update(position: point(500))
        s.setSpeedLimits(Array(repeating: 50, count: 20))
        XCTAssertEqual(s.progress, 500, accuracy: 3)
        XCTAssertEqual(s.update(position: point(510)).state.speedLimit, 50)
    }

    func testFormatting() {
        XCTAssertEqual(Formatting.distance(45), "50 m")
        XCTAssertEqual(Formatting.distance(850), "850 m")
        XCTAssertEqual(Formatting.distance(1234), "1,2 km")
        XCTAssertEqual(Formatting.distance(12_345), "12 km")
        XCTAssertEqual(Formatting.spokenDistance(1500), "1,5 Kilometern")
        XCTAssertEqual(Formatting.spokenDistance(300), "300 Metern")
        XCTAssertEqual(Formatting.minutes(20), "1 Min")
        XCTAssertEqual(Formatting.minutes(3700), "1 Std 2 Min")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(Formatting.clock(Date(timeIntervalSince1970: 3600 * 17 + 49 * 60), calendar: cal), "17:49")
    }
}
