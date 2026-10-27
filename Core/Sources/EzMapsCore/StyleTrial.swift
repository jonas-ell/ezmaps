import Foundation

/// Kurzes Testen eines Kauf-Stils (GM-041). Regeln:
/// - Jeder Kauf-Stil hat **einmal** ein Budget (10 Minuten), danach nie wieder.
/// - Es zählt die Zeit, in der der Stil auf dem iPhone **oder** in CarPlay sichtbar ist (beides gleichzeitig
///   zählt nur einmal), also lässt sich CarPlay nicht als Schlupfloch nutzen.
/// - Läuft nie mitten in einer Fahrt ab: Ist das Budget während einer Navigation aufgebraucht, bleibt der Stil
///   bis zur Ankunft, dann geht es zurück zu Klassik.
/// - Nicht umgehbar durch Löschen und Neuinstallieren: Die App speichert `used` im Schlüsselbund (bleibt nach
///   dem Löschen erhalten) und in iCloud (gleiche Apple-ID, anderes Gerät). Beim Start wird mit `merge` der
///   **größere** Wert genommen. Gezählt wird mit der Laufzeit seit dem Gerätestart, nicht mit der Uhrzeit,
///   damit Uhr-Verstellen nichts bringt.
public struct StyleTrial: Codable, Equatable, Sendable {
    public static let budget: TimeInterval = 600

    public enum Event: Equatable, Sendable {
        /// Noch eine Minute (einmal je Test)
        case oneMinuteLeft
        /// Budget leer, aber Fahrt läuft – Stil bleibt bis zur Ankunft
        case expiresAfterArrival
        /// Zurück zu Klassik
        case expired
    }

    /// Verbrauchte Sekunden je Stil-ID (z. B. "neon")
    public private(set) var used: [String: TimeInterval] = [:]
    /// Gerade getesteter Stil
    public private(set) var active: String?
    private var warned = false
    private var holding = false

    public init() {}

    public func remaining(_ style: String) -> TimeInterval { max(0, Self.budget - (used[style] ?? 0)) }
    public func canStart(_ style: String) -> Bool { remaining(style) > 0 }

    /// Test starten. `false`, wenn das Budget schon verbraucht ist.
    public mutating func start(_ style: String) -> Bool {
        guard canStart(style) else { return false }
        active = style; warned = remaining(style) <= 60; holding = false
        return true
    }

    /// Test beenden (Nutzer wechselt zurück oder kauft)
    public mutating func stop() { active = nil; holding = false }

    /// Regelmäßig aufrufen (z. B. jede Sekunde). `visible`: Stil ist auf iPhone oder CarPlay zu sehen.
    public mutating func tick(seconds: TimeInterval, visible: Bool, navigating: Bool) -> Event? {
        guard let s = active, seconds > 0 else { return nil }
        if visible { used[s] = min(Self.budget, (used[s] ?? 0) + seconds) }
        if remaining(s) > 0 {
            if remaining(s) <= 60 && !warned { warned = true; return .oneMinuteLeft }
            return nil
        }
        if navigating {
            if holding { return nil }
            holding = true; return .expiresAfterArrival
        }
        active = nil; holding = false
        return .expired
    }

    /// Navigation zu Ende: wenn das Budget während der Fahrt leer wurde, jetzt beenden
    public mutating func navigationEnded() -> Event? {
        guard let s = active, remaining(s) <= 0 else { return nil }
        active = nil; holding = false
        return .expired
    }

    /// Stände aus Schlüsselbund und iCloud zusammenführen: je Stil der größere Verbrauch gilt
    public mutating func merge(_ other: [String: TimeInterval]) {
        for (k, v) in other { used[k] = max(used[k] ?? 0, min(Self.budget, v)) }
    }
}
