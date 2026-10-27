import XCTest
@testable import EzMapsCore

final class StoreAndJournalTests: XCTestCase {
    func testClassicIsFreeAndEverythingElseLocked() {
        let a = StyleAccess()
        XCTAssertEqual(a.unlocked, [.classic])
        XCTAssertEqual(MapStyle.free, .classic)
    }

    func testPlusUnlocksAllSingleUnlocksOne() {
        XCTAssertEqual(StyleAccess(owned: [ProductID.monthly]).unlocked.count, MapStyle.allCases.count)
        XCTAssertEqual(StyleAccess(owned: [ProductID.lifetime]).unlocked.count, MapStyle.allCases.count)
        let neon = StyleAccess(owned: ["ezmaps.style.neon"])
        XCTAssertEqual(Set(neon.unlocked), [.classic, .neonCity])
        XCTAssertTrue(neon.ownsSingle(.neonCity))
        XCTAssertFalse(neon.hasPlus)
    }

    func testProductIDsUnique() {
        XCTAssertEqual(Set(ProductID.all).count, ProductID.all.count)
        XCTAssertEqual(ProductID.all.count, 7)
    }

    func testPlanMath() {
        XCTAssertEqual(PlanMath.perMonth(yearly: Decimal(string: "29.99")!), Decimal(string: "2.49")!)
        XCTAssertEqual(PlanMath.savingsPercent(monthly: Decimal(string: "4.99")!, yearly: Decimal(string: "29.99")!), 45)
        XCTAssertEqual(PlanMath.savingsPercent(monthly: 1, yearly: 20), 0)
    }

    func testJournalTripsFavoritesAndCodable() throws {
        var j = Journal()
        let a = Coordinate(latitude: 50.2215, longitude: 8.268), b = Coordinate(latitude: 50.23, longitude: 8.27)
        j.add(.init(date: Date(timeIntervalSince1970: 0), destination: "Hexenturm", meters: 1900, seconds: 360, newPercent: 12, track: [a, b]))
        XCTAssertEqual(j.trips.count, 1)
        XCTAssertLessThan(j.trips[0].track[1].distance(to: b), 2)
        let p = PhotonClient.Place(name: "Hexenturm", subtitle: "Idstein", coordinate: a, kind: "tower")
        j.toggleFavorite(p); XCTAssertTrue(j.isFavorite(p))
        j.toggleFavorite(p); XCTAssertFalse(j.isFavorite(p))
        j.badges = [.firstDrive]
        j.parked = .init(coordinate: a, date: Date(timeIntervalSince1970: 5))
        let back = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(back, j)
        // alte Datei ohne neue Felder
        let old = try JSONDecoder().decode(Journal.self, from: Data("{}".utf8))
        XCTAssertTrue(old.keepTrips)
        j.keepTrips = false
        j.add(.init(date: Date(), destination: "X", meters: 1, seconds: 1, newPercent: 0, track: [a, b]))
        XCTAssertEqual(j.trips.count, 1, "Speichern aus → nichts dazu")
    }

    func testWeeklyMissionRollsAndCompletes() {
        var m = WeeklyMission()
        let cal = Calendar(identifier: .iso8601)
        let day = Date(timeIntervalSince1970: 1_793_000_000)
        m.roll(to: day, calendar: cal)
        let firstKind = m.kind
        let reveal = TripReveal(newCells: Array(0..<200), totalCells: 300)
        var finished = false
        for _ in 0..<5 { if m.record(reveal, date: day, calendar: cal) { finished = true } }
        XCTAssertTrue(m.done)
        XCTAssertTrue(finished)
        m.roll(to: day.addingTimeInterval(7 * 86_400), calendar: cal)
        XCTAssertNotEqual(m.kind, firstKind, "nächste Woche andere Mission")
        XCTAssertEqual(m.value, 0)
    }

    func testAutobahnParseAndRoads() {
        let json = """
        {"roadworks":[{"identifier":"x1","isBlocked":"false","future":false,"display_type":"SHORT_TERM_ROADWORKS","subtitle":" Frankfurt -> Köln","title":"A3 | Niedernhausen - Idstein ",
        "coordinate":{"lat":50.20,"long":8.30},"description":["gültig","Länge: 0.2 km | Max. 80 km/h"],
        "geometry":{"type":"LineString","coordinates":[[8.3000,50.2000],[8.3000,50.2050]]}},
        {"identifier":"x2","isBlocked":"true","future":true,"display_type":"ROADWORKS","title":"A3 | B","subtitle":"","coordinate":{"lat":"50.1","long":"8.1"},"description":[]}]}
        """
        let n = AutobahnClient.parse(Data(json.utf8), key: "roadworks")
        XCTAssertEqual(n.count, 2)
        XCTAssertEqual(n[0].kind, .shortRoadworks)
        XCTAssertEqual(n[0].maxSpeed, 80)
        XCTAssertEqual(n[0].direction, "Frankfurt -> Köln")
        XCTAssertEqual(n[0].label, "Baustelle")
        XCTAssertTrue(n[1].blocked)
        XCTAssertEqual(n[1].label, "Sperrung")
        XCTAssertEqual(n[1].line.count, 1, "ohne Geometrie: Punkt aus coordinate (Text)")

        // Route nach Norden über die Baustelle, dann Gegenrichtung
        let shape = (0...40).map { Coordinate(latitude: 50.19 + Double($0) * 0.0005, longitude: 8.3) }
        let route = Route(shape: shape, duration: 600, maneuvers: [], segmentNames: Array(repeating: "A 3", count: shape.count - 1), segmentSpeeds: Array(repeating: 100, count: shape.count - 1))
        XCTAssertEqual(AutobahnClient.roads(on: route), ["A3"])
        let ahead = RoadNoticeFilter.ahead(n, route: route, progress: 0)
        XCTAssertEqual(ahead.map(\.notice.id), ["x1"], "künftige Meldung nicht")
        XCTAssertEqual(ahead[0].distance, 1110, accuracy: 30)
        var reversed = n[0]; reversed.line.reverse()
        XCTAssertTrue(RoadNoticeFilter.ahead([reversed], route: route, progress: 0).isEmpty, "Gegenrichtung nicht")
        XCTAssertTrue(RoadNoticeFilter.ahead(n, route: route, progress: 1500).isEmpty, "schon vorbei")
    }
}
