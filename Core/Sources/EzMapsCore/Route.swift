import Foundation

/// Art eines Abbiegehinweises. Mirror in tools/prototype/js/valhalla.js (KIND/TEXT) – change both.
public enum ManeuverKind: String, Codable, Sendable, CaseIterable {
    case slightRight = "slight-right"
    case right
    case sharpRight = "sharp-right"
    case uturnRight = "uturn-right"
    case uturnLeft = "uturn-left"
    case sharpLeft = "sharp-left"
    case left
    case slightLeft = "slight-left"
    case destination

    /// Kurzer deutscher Text (Schlüssel für L(…) in der App).
    public var text: String {
        switch self {
        case .slightRight: return "Leicht rechts halten"
        case .right: return "Rechts abbiegen"
        case .sharpRight: return "Scharf rechts abbiegen"
        case .uturnRight, .uturnLeft: return "Wenden"
        case .sharpLeft: return "Scharf links abbiegen"
        case .left: return "Links abbiegen"
        case .slightLeft: return "Leicht links halten"
        case .destination: return "Ziel erreicht"
        }
    }
}

public struct Maneuver: Equatable, Sendable {
    /// Entfernung vom Routen-Anfang in Metern
    public var distance: Double
    public var kind: ManeuverKind
    public var text: String
    /// Straßenname; leer, wenn OSM keinen kennt (kein Platzhalter, GM-016)
    public var street: String
}

public struct Route: Equatable, Sendable {
    public var shape: [Coordinate]
    /// aufsummierte Meter je Punkt (cumulative[0] == 0)
    public var cumulative: [Double]
    public var length: Double
    public var duration: TimeInterval
    public var maneuvers: [Maneuver]
    /// je Teilstück (shape.count - 1): Straßenname und geschätzte Geschwindigkeit in km/h
    public var segmentNames: [String]
    public var segmentSpeeds: [Double]
    /// je Teilstück: Tempolimit in km/h, 0 = unbekannt, -1 = unbegrenzt; nil bis geladen
    public var speedLimits: [Int]?

    public init(shape: [Coordinate], duration: TimeInterval, maneuvers: [Maneuver], segmentNames: [String], segmentSpeeds: [Double]) {
        self.shape = shape
        var cum: [Double] = [0]
        for i in 1..<max(1, shape.count) { cum.append(cum[i - 1] + shape[i - 1].distance(to: shape[i])) }
        self.cumulative = cum
        self.length = cum.last ?? 0
        self.duration = duration
        self.maneuvers = maneuvers
        self.segmentNames = segmentNames
        self.segmentSpeeds = segmentSpeeds
        self.speedLimits = nil
    }

    /// Nächster Hinweis nach der gefahrenen Strecke `progress` (Meter).
    public func nextManeuver(after progress: Double) -> Maneuver? {
        maneuvers.first { $0.distance > progress + 3 } ?? maneuvers.last
    }

    /// Index des Teilstücks bei `progress` Metern.
    public func segmentIndex(at progress: Double) -> Int {
        guard cumulative.count > 1 else { return 0 }
        let d = min(max(progress, 0), length)
        var lo = 1
        var hi = cumulative.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cumulative[mid] < d { lo = mid + 1 } else { hi = mid }
        }
        return max(0, lo - 1)
    }

    /// Punkt auf der Route nach `distance` Metern (für die Demo-Fahrt und die verpasste Abbiegung). Mirror: route.js pointAt.
    public func coordinate(at distance: Double) -> Coordinate? {
        guard let first = shape.first else { return nil }
        guard shape.count > 1 else { return first }
        let i = segmentIndex(at: distance)
        let a = shape[i], b = shape[i + 1]
        let len: Double = cumulative[i + 1] - cumulative[i]
        let t: Double = len > 0 ? min(1, max(0, (min(max(distance, 0), length) - cumulative[i]) / len)) : 0
        return Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * t, longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    /// Fahrtrichtung in Grad (0 = Norden, im Uhrzeigersinn) an der Stelle
    public func heading(at distance: Double) -> Double {
        guard shape.count > 1 else { return 0 }
        let i = segmentIndex(at: distance)
        let a = shape[i], b = shape[i + 1]
        let dx: Double = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
        let dy: Double = b.latitude - a.latitude
        let deg: Double = atan2(dx, dy) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Tempolimit an der Stelle; nil = unbekannt (dann kein Schild anzeigen), -1 = unbegrenzt.
    public func speedLimit(at progress: Double) -> Int? {
        guard let limits = speedLimits, !limits.isEmpty else { return nil }
        let v = limits[min(segmentIndex(at: progress), limits.count - 1)]
        return v == 0 ? nil : v
    }
}

public enum SpeedLimits {
    /// Lücken (OSM ohne maxspeed) mit dem letzten bekannten Limit füllen, am Anfang mit dem ersten bekannten.
    /// Mirror in tools/prototype/js/app.js (fillLimits) – change both.
    public static func fill(_ limits: [Int]) -> [Int] {
        var out = limits
        var last = 0
        for i in out.indices {
            if out[i] != 0 { last = out[i] } else if last != 0 { out[i] = last }
        }
        if let first = out.first(where: { $0 != 0 }) {
            for i in out.indices {
                if out[i] != 0 { break }
                out[i] = first
            }
        }
        return out
    }
}
