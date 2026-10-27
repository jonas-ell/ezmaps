import Foundation

/// Eigene Kartenstile. Bewusst keine Spielnamen (Marken-/Urheberrecht).
/// GM-043: „Klassik“ ist gratis (GM-025), alle anderen sind Kauf-Stile (Plus oder Einzelkauf, GM-038/039).
/// Mirror in tools/prototype/js/map.js (STYLES) – change both.
public enum MapStyle: String, CaseIterable, Codable, Sendable {
    case classic = "classic"
    case neonCity = "neon-city"
    case wildWest = "wild-west"
    case pixelQuest = "pixel-quest"
    case toyTown = "toy-town"

    /// Der Stil, der gratis enthalten ist (inkl. CarPlay).
    public static let free: MapStyle = .classic

    /// Deutscher Lokalisierungsschlüssel für den Anzeigenamen.
    public var titleKey: String {
        switch self {
        case .classic: return "Klassik"
        case .neonCity: return "Neon City"
        case .wildWest: return "Wild West"
        case .pixelQuest: return "Pixel Quest"
        case .toyTown: return "Toy Town"
        }
    }

    /// Kurzbeschreibung (Shop, Onboarding)
    public var subtitleKey: String {
        switch self {
        case .classic: return "Heller Stadtplan"
        case .neonCity: return "Dunkle Open-World-Karte"
        case .wildWest: return "Papierkarte, rote Route"
        case .pixelQuest: return "Retro-Oberwelt"
        case .toyTown: return "Spielteppich"
        }
    }

    /// Dateiname der MapLibre-Style-JSON im App-Bundle.
    public var styleFileName: String { "style-\(rawValue).json" }

    public var isFree: Bool { self == Self.free }

    /// Kurzer Schlüssel für Stil-Test und Speicher (wie im Prototyp: neon, western, pixel, toy)
    public var trialKey: String {
        switch self {
        case .classic: return "classic"
        case .neonCity: return "neon"
        case .wildWest: return "western"
        case .pixelQuest: return "pixel"
        case .toyTown: return "toy"
        }
    }
}
