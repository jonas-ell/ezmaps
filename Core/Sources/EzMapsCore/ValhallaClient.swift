import Foundation

/// Routing über Valhalla (OSM). Prototyp und erste Tests: öffentlicher FOSSGIS-Server; für die App ein eigener Server
/// (siehe docs/KARTENDATEN.md). Mirror in tools/prototype/js/valhalla.js – change both.
public struct ValhallaClient: Sendable {
    public struct Options: Sendable {
        public var avoidHighway = false
        public var avoidToll = false
        /// Fahrtrichtung in Grad (0 = Norden) – wichtig bei der Neuberechnung, damit nicht „Wenden“ vorgeschlagen wird
        public var heading: Double?
        public var exclude: [Coordinate] = []
        public var alternates = 2
        public init() {}
    }

    public let baseURL: URL
    let http: HTTPClient

    public init(baseURL: URL = URL(string: "https://valhalla1.openstreetmap.de")!, http: HTTPClient = URLSessionHTTPClient()) {
        self.baseURL = baseURL
        self.http = http
    }

    // MARK: Route + Alternativen

    public func routes(from: Coordinate, to: Coordinate, options: Options = Options()) async throws -> [Route] {
        var start: [String: Any] = ["lat": from.latitude, "lon": from.longitude]
        if let h = options.heading {
            start["heading"] = Int(((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360).rounded())
            start["heading_tolerance"] = 45
        }
        var body: [String: Any] = [
            "locations": [start, ["lat": to.latitude, "lon": to.longitude]],
            "costing": "auto",
            "costing_options": ["auto": ["use_highways": options.avoidHighway ? 0 : 1, "use_tolls": options.avoidToll ? 0 : 1]],
            "directions_options": ["language": "de-DE", "units": "kilometers"],
            "alternates": options.alternates,
        ]
        if !options.exclude.isEmpty {
            body["exclude_locations"] = options.exclude.map { ["lat": $0.latitude, "lon": $0.longitude] }
        }
        let data = try await http.send(try request("/route", body))
        let response = try Self.decoder.decode(RouteResponse.self, from: data)
        let trips: [Trip] = [response.trip] + (response.alternates ?? []).map { $0.trip }
        return trips.map(Self.makeRoute)
    }

    /// Neuberechnung nach Abweichung: erst mit gesperrter verpasster Abbiegung, dann ohne Sperre.
    /// (GM-016: mit Sperre gibt es manchmal keinen Weg, z. B. an Sackgassen.)
    public func reroute(from position: Coordinate, heading: Double?, to destination: Coordinate, missedTurn: Coordinate?, options: Options = Options()) async throws -> Route? {
        var o = options
        o.alternates = 0
        o.heading = heading
        if let turn = missedTurn {
            o.exclude = [turn]
            if let r = try? await routes(from: position, to: destination, options: o).first { return r }
        }
        o.exclude = []
        return try await routes(from: position, to: destination, options: o).first
    }

    // MARK: Tempolimits (OSM maxspeed über trace_attributes)

    /// Tempolimit je Teilstück der Route: km/h, 0 = unbekannt, -1 = unbegrenzt. Lücken sind bereits gefüllt.
    public func speedLimits(for route: Route, maxDistance: Double = 150_000) async throws -> [Int] {
        guard route.shape.count > 1 else { return [] }
        let avgStep = route.length / Double(route.shape.count)
        let step = max(1, Int((15 / max(1, avgStep)).rounded()))
        var idx: [Int] = []
        var i = 0
        while i < route.shape.count && route.cumulative[i] < maxDistance { idx.append(i); i += step }
        let shape = idx.map { ["lat": route.shape[$0].latitude, "lon": route.shape[$0].longitude] }
        let body: [String: Any] = [
            "shape": shape, "costing": "auto", "shape_match": "map_snap",
            "filters": ["attributes": ["edge.speed_limit", "matched.edge_index"], "action": "include"],
        ]
        let data = try await http.send(try request("/trace_attributes", body))
        let response = try Self.decoder.decode(TraceResponse.self, from: data)
        var limits = [Int](repeating: 0, count: route.shape.count - 1)
        for (k, point) in response.matchedPoints.enumerated() where k < idx.count {
            guard let e = point.edgeIndex, e >= 0, e < response.edges.count else { continue }
            let value = response.edges[e].speedLimit?.kmh ?? 0
            let end = k + 1 < idx.count ? idx[k + 1] : route.shape.count - 1
            for s in idx[k]..<max(idx[k], end) where s < limits.count { limits[s] = value }
        }
        return SpeedLimits.fill(limits)
    }

    // MARK: intern

    private func request(_ path: String, _ body: [String: Any]) throws -> URLRequest {
        var r = URLRequest(url: baseURL.appendingPathComponent(path))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        r.timeoutInterval = 20
        return r
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    /// Valhalla-Manövertyp → unsere Art (nil = kein eigener Hinweis)
    static func kind(for type: Int) -> ManeuverKind? {
        switch type {
        case 9, 18, 20, 23: return .slightRight
        case 10, 26, 27: return .right
        case 11: return .sharpRight
        case 12: return .uturnRight
        case 13: return .uturnLeft
        case 14: return .sharpLeft
        case 15: return .left
        case 16, 19, 21, 24: return .slightLeft
        case 4, 5, 6: return .destination
        default: return nil
        }
    }

    static func makeRoute(_ trip: Trip) -> Route {
        guard let leg = trip.legs.first else { return Route(shape: [], duration: 0, maneuvers: [], segmentNames: [], segmentSpeeds: []) }
        let shape = Polyline.decode(leg.shape, precision: 6)
        let n = max(0, shape.count - 1)
        var names = [String](repeating: "", count: n)
        var speeds = [Double](repeating: 50, count: n)
        var route = Route(shape: shape, duration: trip.summary.time, maneuvers: [], segmentNames: [], segmentSpeeds: [])
        var maneuvers: [Maneuver] = []
        for (mi, m) in leg.maneuvers.enumerated() {
            let next = mi + 1 < leg.maneuvers.count ? leg.maneuvers[mi + 1] : nil
            var street = m.streetName
            if street.isEmpty, m.type == 26 { street = next?.streetName ?? "" }
            let kmh: Double = m.time > 0 ? min(130, max(8, m.length * 3600 / m.time)) : 30
            let end = min(n, m.endShapeIndex)
            if m.beginShapeIndex < end {
                for i in m.beginShapeIndex..<end { names[i] = street; speeds[i] = kmh }
            }
            // GM-017: lokaler Name ≠ Funktionsname (LESSONS_SWIFT 1: „ambiguous expression“)
            guard let mk = Self.kind(for: m.type) else { continue }
            if m.type == 27 { continue } // Ausfahrt aus dem Kreisverkehr steckt schon in der Einfahrt
            let at = mk == .destination ? route.length : route.cumulative[min(m.beginShapeIndex, route.cumulative.count - 1)]
            var text = mk.text
            switch m.type {
            case 26: text = "Im Kreisverkehr \(m.roundaboutExitCount ?? 1). Ausfahrt"
            case 20, 21: text = ("Ausfahrt " + (m.sign?.exitNumberElements?.first?.text ?? "")).trimmingCharacters(in: .whitespaces) + " nehmen"
            case 18, 19: text = "Auffahrt nehmen"
            default: break
            }
            maneuvers.append(Maneuver(distance: at, kind: mk, text: text, street: mk == .destination ? "" : street))
        }
        if maneuvers.last?.kind != .destination {
            maneuvers.append(Maneuver(distance: route.length, kind: .destination, text: ManeuverKind.destination.text, street: ""))
        }
        route.maneuvers = maneuvers
        route.segmentNames = names
        route.segmentSpeeds = speeds
        return route
    }

    // MARK: Antwort-Typen

    struct RouteResponse: Decodable {
        let trip: Trip
        let alternates: [Alternate]?
    }
    struct Alternate: Decodable { let trip: Trip }
    struct Trip: Decodable {
        let legs: [Leg]
        let summary: Summary
    }
    struct Summary: Decodable { let time: Double }
    struct Leg: Decodable {
        let shape: String
        let maneuvers: [VManeuver]
    }
    struct VManeuver: Decodable {
        let type: Int
        let length: Double
        let time: Double
        let beginShapeIndex: Int
        let endShapeIndex: Int
        let streetNames: [String]?
        let beginStreetNames: [String]?
        let roundaboutExitCount: Int?
        let sign: Sign?

        var streetName: String {
            streetNames?.first ?? beginStreetNames?.first ?? sign?.exitTowardElements?.first?.text ?? ""
        }
    }
    struct Sign: Decodable {
        let exitNumberElements: [SignElement]?
        let exitTowardElements: [SignElement]?
    }
    struct SignElement: Decodable { let text: String }

    struct TraceResponse: Decodable {
        let edges: [Edge]
        let matchedPoints: [MatchedPoint]
    }
    struct MatchedPoint: Decodable { let edgeIndex: Int? }
    struct Edge: Decodable { let speedLimit: SpeedLimitValue? }

    /// `speed_limit` ist eine Zahl oder der Text „unlimited“.
    enum SpeedLimitValue: Decodable {
        case kmh(Int)
        case unlimited
        case unknown

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let v = try? c.decode(Int.self) { self = .kmh(v) }
            else if let s = try? c.decode(String.self) { self = s == "unlimited" ? .unlimited : (Int(s).map { .kmh($0) } ?? .unknown) }
            else { self = .unknown }
        }

        var kmh: Int {
            switch self {
            case .kmh(let v): return v
            case .unlimited: return -1
            case .unknown: return 0
            }
        }
    }
}
