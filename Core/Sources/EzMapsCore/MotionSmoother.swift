import Foundation

/// GM-064: gegen das Ruckeln des Pfeils/der Kamera. GPS kommt ~1×/s; dazwischen wird weitergerechnet.
/// Vorher sprang das Kameraziel bei jeder neuen Meldung auf den neuen Punkt (Schätzung und Messung weichen fast
/// immer etwas ab – GPS hinkt hinterher, Tempo schwankt) → sichtbarer Ruck einmal pro Sekunde, Richtung in Stufen.
/// Jetzt: Weiterrechnen inkl. Kurve (Drehrate aus den letzten Meldungen) und die Abweichung bei einer neuen Meldung
/// **weich** über `blend` Sekunden ausgleichen statt sofort. Ergebnis ist zu jeder Zeit stetig.
/// Mirror in tools/prototype/js/navcore.js (MotionSmoother) – change both.
public struct FreeMotionSmoother: Sendable {
    public struct Pose: Equatable, Sendable {
        public var coordinate: Coordinate
        /// Grad, 0 = Norden
        public var heading: Double
    }

    /// Zeit (s), in der eine Abweichung zu ~95 % ausgeglichen ist
    public var blend: Double = 0.6
    /// längstes Weiterrechnen ohne neue Meldung (Tunnel): danach bleibt der Pfeil stehen
    public var maxPredict: Double = 2.5
    /// unter diesem Tempo (m/s) kein Weiterrechnen und keine neue Richtung (Stand, Ampel)
    public var minSpeed: Double = 1.5

    private var anchor: (c: Coordinate, mps: Double, heading: Double, turn: Double, t: TimeInterval)?
    /// Rest-Abweichung beim letzten Fix (Meter Nord/Ost, Grad), klingt ab
    private var offset: (north: Double, east: Double, heading: Double, t: TimeInterval) = (0, 0, 0, 0)

    public init() {}

    /// Neue GPS-Meldung. `course` < 0 oder nil = unbekannt.
    public mutating func fix(_ c: Coordinate, speed: Double, course: Double?, at t: TimeInterval) {
        let mps = max(0, speed)
        let old = pose(at: t)
        var heading = anchor?.heading ?? (course ?? 0)
        var turn: Double = 0
        if let a = anchor, mps >= minSpeed, let course, course >= 0 {
            let dt = max(0.2, t - a.t)
            turn = max(-45, min(45, Self.delta(a.heading, course) / dt)) // Grad pro Sekunde, gedeckelt
            heading = course
        } else if mps >= minSpeed, let course, course >= 0 {
            heading = course
        }
        anchor = (c, mps, heading, turn, t)
        if let old {
            // Abweichung = wo der Pfeil gerade war − wo er nach der neuen Meldung wäre; die klingt dann ab
            let raw = predict(at: t)!
            let k = 111_320 * cos(c.latitude * .pi / 180)
            offset = ((old.coordinate.latitude - raw.coordinate.latitude) * 110_540,
                      (old.coordinate.longitude - raw.coordinate.longitude) * k,
                      Self.delta(raw.heading, old.heading), t)
            // große Sprünge (> 60 m, z. B. erster Fix nach Tunnel) nicht weich ziehen – sonst „schwimmt“ der Pfeil
            if (offset.north * offset.north + offset.east * offset.east).squareRoot() > 60 { offset = (0, 0, 0, t) }
        }
    }

    /// Pose zum Zeitpunkt `t` (für jedes Bild der Kamera)
    public func pose(at t: TimeInterval) -> Pose? {
        guard let p = predict(at: t) else { return nil }
        let f = decay(t - offset.t)
        let k = 111_320 * cos(p.coordinate.latitude * .pi / 180)
        let c = Coordinate(latitude: p.coordinate.latitude + offset.north * f / 110_540,
                           longitude: p.coordinate.longitude + offset.east * f / k)
        return Pose(coordinate: c, heading: Self.norm(p.heading + offset.heading * f))
    }

    /// Weiterrechnen ab der letzten Meldung: Bogen mit fester Drehrate, Tempo bleibt
    private func predict(at t: TimeInterval) -> Pose? {
        guard let a = anchor else { return nil }
        let dt = max(0, min(maxPredict, t - a.t))
        guard a.mps >= minSpeed, dt > 0 else { return Pose(coordinate: a.c, heading: a.heading) }
        let h = a.heading + a.turn * dt
        let mid = a.heading + a.turn * dt / 2 // mittlere Richtung über den Bogen
        return Pose(coordinate: a.c.moved(meters: a.mps * dt, bearing: mid), heading: Self.norm(h))
    }

    private func decay(_ age: Double) -> Double { age <= 0 ? 1 : exp(-3 * age / blend) }

    static func delta(_ from: Double, _ to: Double) -> Double {
        var d = (to - from).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        return d
    }

    static func norm(_ h: Double) -> Double { (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
}

/// GM-064: dasselbe für die Navigation, aber auf der Route: Fortschritt (Meter) weiterrechnen und die Abweichung
/// bei einer neuen Meldung weich ausgleichen. Position und Richtung holt die App aus der Route am Fortschritt.
public struct RouteProgressSmoother: Sendable {
    public var blend: Double = 0.6
    public var maxPredict: Double = 2.5

    private var anchor: (progress: Double, mps: Double, t: TimeInterval)?
    private var offset: (value: Double, t: TimeInterval) = (0, 0)

    public init() {}

    public mutating func reset() { anchor = nil; offset = (0, 0) }

    public mutating func fix(progress: Double, speed: Double, at t: TimeInterval) {
        let old = value(at: t)
        anchor = (progress, max(0, speed), t)
        if let old {
            let d = old - progress
            // Rückwärts nie weich „zurückschieben“ über 40 m (z. B. Neuberechnung) – dann direkt setzen
            offset = abs(d) > 40 ? (0, t) : (d, t)
        }
    }

    /// Fortschritt zum Zeitpunkt t; nie größer als `limit` (Routenlänge)
    public func value(at t: TimeInterval, limit: Double = .greatestFiniteMagnitude) -> Double? {
        guard let a = anchor else { return nil }
        let dt = max(0, min(maxPredict, t - a.t))
        let age = t - offset.t
        let f = age <= 0 ? 1 : exp(-3 * age / blend)
        return min(limit, max(0, a.progress + a.mps * dt + offset.value * f))
    }
}
