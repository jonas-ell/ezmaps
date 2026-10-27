import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// GM-043: Baustellen und Sperrungen der Autobahn GmbH (verkehr.autobahn.de, offen, ohne Schlüssel).
/// Nur Baustellen, Sperrungen und Warnungen – **keine** Blitzer o. Ä. (§ 23 Abs. 1c StVO).
/// Quelle in den Einstellungen nennen: „Verkehrsdaten: Autobahn GmbH des Bundes“.
public struct RoadNotice: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case roadworks, shortRoadworks, closure, warning }
    public var id: String
    public var kind: Kind
    /// z. B. „A3 | Niedernhausen - Theißtal“
    public var title: String
    /// Richtung, z. B. „Frankfurt -> Köln“
    public var direction: String
    public var line: [Coordinate]
    public var blocked: Bool
    public var future: Bool
    public var details: [String]
    /// „Max. 80 km/h“ aus der Beschreibung
    public var maxSpeed: Int?

    /// Kurzer Text für den Hinweis („Baustelle“, „Sperrung“ …)
    public var label: String {
        if blocked || kind == .closure { return "Sperrung" }
        switch kind {
        case .roadworks, .shortRoadworks: return "Baustelle"
        case .closure: return "Sperrung"
        case .warning: return "Warnung"
        }
    }

    /// Erste Detailzeile, die eher Nutzen hat als „gültig von …“ (z. B. „Länge 0.2 km | Max. 80 km/h“)
    public var summary: String {
        details.first { $0.contains("km/h") || $0.lowercased().contains("fahrstreifen") || $0.lowercased().contains("gesperrt") }
            ?? details.first { !$0.isEmpty } ?? ""
    }
}

public struct AutobahnClient: Sendable {
    public let baseURL: URL
    public let http: HTTPClient

    public init(baseURL: URL = URL(string: "https://verkehr.autobahn.de/o/autobahn")!, http: HTTPClient) {
        self.baseURL = baseURL
        self.http = http
    }

    /// Alle Meldungen einer Autobahn (z. B. "A3"): Baustellen, Sperrungen, Warnungen
    public func notices(road: String) async throws -> [RoadNotice] {
        var out: [RoadNotice] = []
        for (service, key) in [("roadworks", "roadworks"), ("closure", "closure"), ("warning", "warning")] {
            let url = baseURL.appendingPathComponent(road).appendingPathComponent("services").appendingPathComponent(service)
            if let data = try? await http.send(URLRequest(url: url)) { out += Self.parse(data, key: key) }
        }
        return out
    }

    /// JSON der Autobahn-API lesen (Zahlen kommen mal als Zahl, mal als Text)
    public static func parse(_ data: Data, key: String) -> [RoadNotice] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root[key] as? [[String: Any]] else { return [] }
        return list.compactMap { m in
            let type = (m["display_type"] as? String) ?? ""
            let kind: RoadNotice.Kind
            switch type {
            case "ROADWORKS": kind = .roadworks
            case "SHORT_TERM_ROADWORKS": kind = .shortRoadworks
            case "CLOSURE", "CLOSURE_ENTRY_EXIT": kind = .closure
            case "WARNING": kind = .warning
            default:
                if key == "closure" { kind = .closure } else if key == "warning" { kind = .warning } else { kind = .roadworks }
            }
            var line: [Coordinate] = []
            if let g = m["geometry"] as? [String: Any], let coords = g["coordinates"] as? [[Any]] {
                line = coords.compactMap { p in
                    guard p.count >= 2, let lon = num(p[0]), let lat = num(p[1]) else { return nil }
                    return Coordinate(latitude: lat, longitude: lon)
                }
            }
            if line.isEmpty, let c = m["coordinate"] as? [String: Any], let lat = num(c["lat"]), let lon = num(c["long"]) {
                line = [Coordinate(latitude: lat, longitude: lon)]
            }
            guard !line.isEmpty else { return nil }
            let details = (m["description"] as? [String]) ?? []
            return RoadNotice(
                id: (m["identifier"] as? String) ?? UUID().uuidString,
                kind: kind,
                title: (m["title"] as? String ?? "").trimmingCharacters(in: .whitespaces),
                direction: (m["subtitle"] as? String ?? "").trimmingCharacters(in: .whitespaces),
                line: line,
                blocked: bool(m["isBlocked"]),
                future: bool(m["future"]),
                details: details,
                maxSpeed: maxSpeed(in: details)
            )
        }
    }

    static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s) }
        return nil
    }

    static func bool(_ v: Any?) -> Bool {
        if let b = v as? Bool { return b }
        if let s = v as? String { return s.lowercased() == "true" }
        return false
    }

    static func maxSpeed(in lines: [String]) -> Int? {
        for l in lines {
            guard let r = l.range(of: "Max. ") else { continue }
            let digits = l[r.upperBound...].prefix { $0.isNumber }
            if let v = Int(digits) { return v }
        }
        return nil
    }

    /// Autobahn-Nummern auf einer Route aus den Straßennamen („A 3“, „A3“, „A 661“)
    public static func roads(on route: Route) -> [String] {
        var out: [String] = []
        for name in route.segmentNames + route.maneuvers.map(\.street) {
            for token in name.components(separatedBy: CharacterSet(charactersIn: ";,/")) {
                let t = token.trimmingCharacters(in: .whitespaces)
                guard t.hasPrefix("A"), t.count >= 2 else { continue }
                let rest = t.dropFirst().trimmingCharacters(in: .whitespaces)
                let digits = rest.prefix { $0.isNumber }
                guard !digits.isEmpty, digits.count <= 3, rest.count == digits.count else { continue }
                let road = "A" + digits
                if !out.contains(road) { out.append(road) }
            }
        }
        return out
    }
}

/// Meldungen, die auf der eigenen Strecke vor einem liegen
public enum RoadNoticeFilter {
    public struct Ahead: Equatable, Sendable {
        public var notice: RoadNotice
        /// Meter bis zum Beginn
        public var distance: Double
    }

    /// `corridor`: wie nah (m) die Meldung an der Route liegen muss; Meldungen der Gegenrichtung liegen meist
    /// 15–40 m daneben – deshalb muss die Meldung auch in Fahrtrichtung verlaufen (gleiche Richtung ±60°).
    public static func ahead(_ notices: [RoadNotice], route: Route, progress: Double, within: Double = 30_000, corridor: Double = 40) -> [Ahead] {
        guard route.shape.count > 1 else { return [] }
        let proj = LocalProjection(origin: route.shape[0])
        let pts = route.shape.map { proj.project($0) }
        func locate(_ c: Coordinate) -> (along: Double, dist: Double, seg: Int) {
            let p = proj.project(c)
            var best = (along: 0.0, dist: Double.greatestFiniteMagnitude, seg: 0)
            for i in 1..<pts.count {
                let a = pts[i - 1], b = pts[i]
                let dx = b.x - a.x, dy = b.y - a.y, len2 = dx * dx + dy * dy
                let t = len2 > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2)) : 0
                let qx = a.x + dx * t, qy = a.y + dy * t
                let d = ((p.x - qx) * (p.x - qx) + (p.y - qy) * (p.y - qy)).squareRoot()
                if d < best.dist { best = (route.cumulative[i - 1] + (route.cumulative[i] - route.cumulative[i - 1]) * t, d, i) }
            }
            return best
        }
        var out: [Ahead] = []
        for n in notices where !n.future {
            let start = locate(n.line[0])
            guard start.dist <= corridor else { continue }
            if n.line.count > 1 {
                let end = locate(n.line[n.line.count - 1])
                // Richtung prüfen: Meldung muss auf der Route vorwärts laufen
                if end.dist > corridor * 2 || end.along < start.along { continue }
            }
            let d = start.along - progress
            if d > -50 && d <= within { out.append(Ahead(notice: n, distance: max(0, d))) }
        }
        return out.sorted { $0.distance < $1.distance }
    }
}
