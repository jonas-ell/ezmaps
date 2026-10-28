import Foundation

/// Geografische Koordinate (WGS84). Bewusst ohne CoreLocation, damit `swift test` überall läuft.
public struct Coordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Entfernung in Metern (Haversine).
    public func distance(to other: Coordinate) -> Double {
        let r: Double = 6_371_000
        let dLat: Double = (other.latitude - latitude) * .pi / 180
        let dLon: Double = (other.longitude - longitude) * .pi / 180
        let a: Double = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    /// GM-050: Richtung zu `other` in Grad (0 = Norden, im Uhrzeigersinn), eben genähert – für kurze Strecken
    public func bearing(to other: Coordinate) -> Double {
        let dx: Double = (other.longitude - longitude) * cos(latitude * .pi / 180)
        let dy: Double = other.latitude - latitude
        return (atan2(dx, dy) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// GM-050: um `meters` in Richtung `bearing` (Grad) verschoben – für das Weiterrechnen der Kamera zwischen GPS-Punkten
    public func moved(meters: Double, bearing: Double) -> Coordinate {
        let b: Double = bearing * .pi / 180
        return Coordinate(latitude: latitude + meters * cos(b) / 110_540,
                          longitude: longitude + meters * sin(b) / (111_320 * cos(latitude * .pi / 180)))
    }
}

/// Lokale ebene Projektion (Meter) um einen Bezugspunkt – genau genug für Abstände von wenigen Kilometern.
/// Mirror in tools/prototype/js/geo.js (toLocal) – change both.
struct LocalProjection {
    let origin: Coordinate
    private let kx: Double
    private let ky: Double = 110_540

    init(origin: Coordinate) {
        self.origin = origin
        self.kx = cos(origin.latitude * .pi / 180) * 111_320
    }

    func project(_ c: Coordinate) -> (x: Double, y: Double) {
        ((c.longitude - origin.longitude) * kx, -(c.latitude - origin.latitude) * ky)
    }
}
