import Foundation

/// Eigene Kartenstile. Bewusst keine Spielnamen (Marken-/Urheberrecht).
public enum MapStyle: String, CaseIterable, Codable, Sendable {
    case neonCity = "neon-city"
    case wildWest = "wild-west"
    case pixelQuest = "pixel-quest"
    case toyTown = "toy-town"

    /// Der Stil, der gratis enthalten ist (inkl. CarPlay).
    public static let free: MapStyle = .neonCity

    /// Deutscher Lokalisierungsschlüssel für den Anzeigenamen.
    public var titleKey: String {
        switch self {
        case .neonCity: return "Neon City"
        case .wildWest: return "Wilder Westen"
        case .pixelQuest: return "Pixel Quest"
        case .toyTown: return "Toy Town"
        }
    }

    /// Dateiname der MapLibre-Style-JSON im App-Bundle.
    public var styleFileName: String { "style-\(rawValue).json" }

    public var isFree: Bool { self == Self.free }
}
