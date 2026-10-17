import Foundation

/// Ortssuche über Photon (OSM). Prototyp: photon.komoot.io; für die App eigener Server oder MapKit (docs/KARTENDATEN.md).
/// Mirror in tools/prototype/js/phone.js (remote) – change both.
public struct PhotonClient: Sendable {
    public struct Place: Equatable, Sendable {
        public var name: String
        public var subtitle: String
        public var coordinate: Coordinate
        public var kind: String
    }

    public let baseURL: URL
    let http: HTTPClient

    public init(baseURL: URL = URL(string: "https://photon.komoot.io")!, http: HTTPClient = URLSessionHTTPClient()) {
        self.baseURL = baseURL
        self.http = http
    }

    static let labels: [String: String] = [
        "city": "Stadt", "town": "Stadt", "village": "Dorf", "suburb": "Ortsteil", "fuel": "Tankstelle", "parking": "Parkplatz",
        "restaurant": "Restaurant", "cafe": "Café", "fast_food": "Imbiss", "supermarket": "Supermarkt", "pharmacy": "Apotheke",
        "square": "Platz", "station": "Bahnhof", "attraction": "Sehenswürdigkeit", "hotel": "Hotel", "residential": "Straße",
    ]

    public func search(_ query: String, near: Coordinate?, limit: Int = 8) async throws -> [Place] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "q", value: q), URLQueryItem(name: "lang", value: "de"), URLQueryItem(name: "limit", value: String(limit))]
        if let n = near {
            items.append(URLQueryItem(name: "lat", value: String(n.latitude)))
            items.append(URLQueryItem(name: "lon", value: String(n.longitude)))
        }
        comps.queryItems = items
        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 15
        let data = try await http.send(request)
        let response = try JSONDecoder().decode(FeatureCollection.self, from: data)
        var result: [Place] = []
        for f in response.features {
            guard f.geometry.coordinates.count >= 2 else { continue }
            let p = f.properties
            let c = Coordinate(latitude: f.geometry.coordinates[1], longitude: f.geometry.coordinates[0])
            let address = [p.street, p.housenumber].compactMap { $0 }.joined(separator: " ")
            let name = p.name ?? (address.isEmpty ? (p.city ?? "Ort") : address)
            let kindLabel = Self.labels[p.osmValue ?? ""] ?? "Ort"
            let subtitle = [kindLabel, p.name != nil ? address : "", p.city ?? p.county ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
            // doppelte Treffer (gleicher Name, < 400 m) nur einmal
            if result.contains(where: { $0.name == name && $0.coordinate.distance(to: c) < 400 }) { continue }
            result.append(Place(name: name, subtitle: subtitle, coordinate: c, kind: p.osmValue ?? ""))
        }
        return result
    }

    struct FeatureCollection: Decodable { let features: [Feature] }
    struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }
    struct Geometry: Decodable { let coordinates: [Double] }
    struct Properties: Decodable {
        let name: String?
        let street: String?
        let housenumber: String?
        let city: String?
        let county: String?
        let osmValue: String?

        enum CodingKeys: String, CodingKey {
            case name, street, housenumber, city, county
            case osmValue = "osm_value"
        }
    }
}
