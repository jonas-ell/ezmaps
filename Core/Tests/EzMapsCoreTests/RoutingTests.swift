import XCTest
@testable import EzMapsCore

/// Netzwerk-Attrappe: liefert vorbereitete Antworten je Pfad und merkt sich die Anfragen.
final class MockHTTP: HTTPClient, @unchecked Sendable {
    var responses: [String: [Data]] = [:]
    var failures: [String: Int] = [:]
    private(set) var requests: [URLRequest] = []
    private let lock = NSLock()

    func send(_ request: URLRequest) async throws -> Data {
        lock.lock(); defer { lock.unlock() }
        requests.append(request)
        let path = request.url?.path ?? ""
        if let left = failures[path], left > 0 {
            failures[path] = left - 1
            throw HTTPError.status(400, "No path could be found for input")
        }
        guard var list = responses[path], !list.isEmpty else { throw HTTPError.status(404, path) }
        let d = list.removeFirst()
        responses[path] = list.isEmpty ? [d] : list
        return d
    }

    func body(_ i: Int) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: requests[i].httpBody ?? Data())) as? [String: Any] ?? [:]
    }
}

final class PolylineTests: XCTestCase {
    func testGoogleExamplePrecision5() {
        let pts = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@", precision: 5)
        XCTAssertEqual(pts.count, 3)
        XCTAssertEqual(pts[0].latitude, 38.5, accuracy: 1e-6)
        XCTAssertEqual(pts[0].longitude, -120.2, accuracy: 1e-6)
        XCTAssertEqual(pts[2].latitude, 43.252, accuracy: 1e-6)
        XCTAssertEqual(pts[2].longitude, -126.453, accuracy: 1e-6)
    }

    func testRoundTripPrecision6() {
        let pts = [Coordinate(latitude: 50.2215, longitude: 8.268), Coordinate(latitude: 50.110644, longitude: 8.682127)]
        let back = Polyline.decode(Polyline.encode(pts))
        XCTAssertEqual(back.count, 2)
        XCTAssertEqual(back[1].latitude, 50.110644, accuracy: 1e-6)
        XCTAssertEqual(back[1].longitude, 8.682127, accuracy: 1e-6)
    }
}

final class ValhallaClientTests: XCTestCase {
    /// Kleine Route: 3 Punkte, rechts abbiegen auf „Limburger Straße“, dann Ziel.
    static let shape = [
        Coordinate(latitude: 50.2200, longitude: 8.2600),
        Coordinate(latitude: 50.2210, longitude: 8.2600),
        Coordinate(latitude: 50.2210, longitude: 8.2620),
    ]

    static func routeJSON(time: Double = 60) -> Data {
        let s = Polyline.encode(shape)
        let json = """
        {"trip":{"summary":{"time":\(time)},"legs":[{"shape":"\(s)","maneuvers":[
          {"type":1,"length":0.11,"time":20,"begin_shape_index":0,"end_shape_index":1,"street_names":["Bahnhofstraße"]},
          {"type":10,"length":0.14,"time":30,"begin_shape_index":1,"end_shape_index":2,"street_names":["Limburger Straße"]},
          {"type":4,"length":0,"time":0,"begin_shape_index":2,"end_shape_index":2}
        ]}]},
         "alternates":[{"trip":{"summary":{"time":90},"legs":[{"shape":"\(s)","maneuvers":[{"type":4,"length":0,"time":0,"begin_shape_index":2,"end_shape_index":2}]}]}}]}
        """
        return Data(json.utf8)
    }

    func testRoutesParsesManeuversAndAlternates() async throws {
        let http = MockHTTP()
        http.responses["/route"] = [Self.routeJSON()]
        let client = ValhallaClient(http: http)
        let routes = try await client.routes(from: Self.shape[0], to: Self.shape[2])
        XCTAssertEqual(routes.count, 2)
        let r = routes[0]
        XCTAssertEqual(r.shape.count, 3)
        XCTAssertEqual(r.duration, 60)
        XCTAssertEqual(r.length, Self.shape[0].distance(to: Self.shape[1]) + Self.shape[1].distance(to: Self.shape[2]), accuracy: 0.5)
        XCTAssertEqual(r.maneuvers.map(\.kind), [.right, .destination])
        XCTAssertEqual(r.maneuvers[0].street, "Limburger Straße")
        XCTAssertEqual(r.maneuvers[0].text, "Rechts abbiegen")
        XCTAssertEqual(r.segmentNames, ["Bahnhofstraße", "Limburger Straße"])
        XCTAssertEqual(r.nextManeuver(after: 0)?.kind, .right)
    }

    func testOptionsGoIntoRequest() async throws {
        let http = MockHTTP()
        http.responses["/route"] = [Self.routeJSON()]
        var o = ValhallaClient.Options()
        o.avoidHighway = true
        o.heading = -90
        _ = try await ValhallaClient(http: http).routes(from: Self.shape[0], to: Self.shape[2], options: o)
        let body = http.body(0)
        let auto = ((body["costing_options"] as? [String: Any])?["auto"] as? [String: Any]) ?? [:]
        XCTAssertEqual(auto["use_highways"] as? Int, 0)
        XCTAssertEqual(auto["use_tolls"] as? Int, 1)
        let start = (body["locations"] as? [[String: Any]])?.first ?? [:]
        XCTAssertEqual(start["heading"] as? Int, 270)
    }

    func testRerouteFallsBackWithoutExclusion() async throws {
        // GM-016: mit gesperrter Abbiegung „No path“ → zweiter Versuch ohne Sperre
        let http = MockHTTP()
        http.responses["/route"] = [Self.routeJSON()]
        http.failures["/route"] = 1
        let r = try await ValhallaClient(http: http).reroute(from: Self.shape[0], heading: 0, to: Self.shape[2], missedTurn: Self.shape[1])
        XCTAssertNotNil(r)
        XCTAssertEqual(http.requests.count, 2)
        XCTAssertNotNil(http.body(0)["exclude_locations"])
        XCTAssertNil(http.body(1)["exclude_locations"])
    }

    func testSpeedLimitsFillGapsAndUnlimited() async throws {
        let http = MockHTTP()
        http.responses["/route"] = [Self.routeJSON()]
        // Punkt 0: unbekannt, Punkt 1: 50, Punkt 2: unbegrenzt
        http.responses["/trace_attributes"] = [Data("""
        {"edges":[{"speed_limit":0},{"speed_limit":50},{"speed_limit":"unlimited"}],
         "matched_points":[{"edge_index":0},{"edge_index":1},{"edge_index":2}]}
        """.utf8)]
        let client = ValhallaClient(http: http)
        var route = try await client.routes(from: Self.shape[0], to: Self.shape[2])[0]
        route.speedLimits = try await client.speedLimits(for: route)
        XCTAssertEqual(route.speedLimits, [50, 50])          // Lücke am Anfang mit erstem bekannten Wert
        XCTAssertEqual(route.speedLimit(at: 10), 50)
    }

    func testFillLimits() {
        XCTAssertEqual(SpeedLimits.fill([0, 0, 30, 0, 50, 0]), [30, 30, 30, 30, 50, 50])
        XCTAssertEqual(SpeedLimits.fill([0, -1, 0]), [-1, -1, -1])
        XCTAssertEqual(SpeedLimits.fill([0, 0]), [0, 0])
    }
}

final class PhotonClientTests: XCTestCase {
    func testSearchParsesAndDeduplicates() async throws {
        let http = MockHTTP()
        // URL.path liefert "/api" ohne Schrägstrich am Ende
        http.responses["/api"] = [Data("""
        {"features":[
          {"geometry":{"coordinates":[8.6822,50.1104]},"properties":{"name":"Römerberg","osm_value":"square","city":"Frankfurt am Main"}},
          {"geometry":{"coordinates":[8.6823,50.1105]},"properties":{"name":"Römerberg","osm_value":"square","city":"Frankfurt am Main"}},
          {"geometry":{"coordinates":[8.6810,50.1110]},"properties":{"street":"Römerberg","housenumber":"34","city":"Frankfurt am Main"}}
        ]}
        """.utf8)]
        let places = try await PhotonClient(http: http).search("Römerberg Frankfurt", near: Coordinate(latitude: 50.2215, longitude: 8.268))
        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(places[0].name, "Römerberg")
        XCTAssertEqual(places[0].subtitle, "Platz · Frankfurt am Main")
        XCTAssertEqual(places[1].name, "Römerberg 34")
        let url = http.requests[0].url!.absoluteString
        XCTAssertTrue(url.contains("lang=de"))
        XCTAssertTrue(url.contains("lat=50.2215"))
    }

    func testEmptyQueryDoesNotCallNetwork() async throws {
        let http = MockHTTP()
        let places = try await PhotonClient(http: http).search("   ", near: nil)
        XCTAssertTrue(places.isEmpty)
        XCTAssertTrue(http.requests.isEmpty)
    }
}

final class RerouteMonitorTests: XCTestCase {
    let route = Route(shape: ValhallaClientTests.shape, duration: 60, maneuvers: [], segmentNames: ["", ""], segmentSpeeds: [30, 30])

    func testOnRouteNoReroute() {
        var m = RerouteMonitor()
        let onLine = Coordinate(latitude: 50.2205, longitude: 8.2600)  // auf dem ersten Stück
        XCTAssertLessThan(RerouteMonitor.distance(from: onLine, to: route.shape), 1)
        XCTAssertFalse(m.update(position: onLine, route: route))
    }

    func testMoreThan30MetersTriggersOnceThenCooldown() {
        var m = RerouteMonitor(threshold: 30, cooldown: 8)
        let off = Coordinate(latitude: 50.2205, longitude: 8.2605)   // ~36 m östlich der Linie
        XCTAssertGreaterThan(RerouteMonitor.distance(from: off, to: route.shape), 30)
        let t0 = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(m.update(position: off, route: route, now: t0))
        XCTAssertFalse(m.update(position: off, route: route, now: t0.addingTimeInterval(3)))
        XCTAssertTrue(m.update(position: off, route: route, now: t0.addingTimeInterval(9)))
    }

    func testJustUnderThresholdNoReroute() {
        var m = RerouteMonitor()
        let near = Coordinate(latitude: 50.2205, longitude: 8.2603)  // ~21 m
        XCTAssertLessThan(RerouteMonitor.distance(from: near, to: route.shape), 30)
        XCTAssertFalse(m.update(position: near, route: route))
    }
}
