import Foundation

/// Erkennt, wann die Route neu berechnet werden muss: Position mehr als `threshold` Meter von der Route entfernt.
/// Eine kurze Sperrzeit verhindert, dass bei jedem GPS-Punkt erneut angefragt wird, solange die neue Route lädt.
/// Im Prototyp per Knopf „Falsch abbiegen“ ausgelöst (tools/prototype/js/app.js, reroute).
public struct RerouteMonitor: Sendable {
    public var threshold: Double
    public var cooldown: TimeInterval
    public private(set) var lastTrigger: Date?

    public init(threshold: Double = 30, cooldown: TimeInterval = 8) {
        self.threshold = threshold
        self.cooldown = cooldown
    }

    /// Kleinster Abstand (Meter) von `position` zur Linie `shape`.
    public static func distance(from position: Coordinate, to shape: [Coordinate]) -> Double {
        guard let first = shape.first else { return .infinity }
        guard shape.count > 1 else { return position.distance(to: first) }
        let proj = LocalProjection(origin: position)
        var best = Double.infinity
        for i in 1..<shape.count {
            let a = proj.project(shape[i - 1])
            let b = proj.project(shape[i])
            let dx: Double = b.x - a.x
            let dy: Double = b.y - a.y
            let len2: Double = dx * dx + dy * dy
            var t: Double = len2 > 0 ? (-a.x * dx - a.y * dy) / len2 : 0
            t = min(1, max(0, t))
            let px: Double = a.x + t * dx
            let py: Double = a.y + t * dy
            best = min(best, (px * px + py * py).squareRoot())
        }
        return best
    }

    /// `true`, wenn jetzt neu berechnet werden soll.
    public mutating func update(position: Coordinate, route: Route, now: Date = Date()) -> Bool {
        let off = Self.distance(from: position, to: route.shape) > threshold
        guard off else { return false }
        if let last = lastTrigger, now.timeIntervalSince(last) < cooldown { return false }
        lastTrigger = now
        return true
    }

    /// Nach erfolgreicher Neuberechnung aufrufen.
    public mutating func reset() { lastTrigger = nil }
}
