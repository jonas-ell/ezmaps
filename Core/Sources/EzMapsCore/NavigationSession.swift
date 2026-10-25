import Foundation

/// Eine laufende Navigation: macht aus GPS-Positionen den Fortschritt auf der Route, entscheidet über Ansagen,
/// Neuberechnung und Ankunft. Ohne UIKit/CoreLocation, damit alles mit `swift test` geprüft werden kann.
/// Mirror in tools/prototype/js/app.js (announce, loop) – change both.
public struct NavigationSession: Sendable {
    /// Was die Oberfläche (iPhone und CarPlay) anzeigt
    public struct State: Equatable, Sendable {
        public var progress: Double
        public var maneuver: Maneuver?
        public var distanceToManeuver: Double
        /// Schritt danach, wenn er kurz auf den nächsten folgt („danach links …“)
        public var thenManeuver: Maneuver?
        public var remainingDistance: Double
        public var remainingTime: TimeInterval
        public var currentStreet: String
        /// km/h; nil = unbekannt (kein Schild), -1 = unbegrenzt
        public var speedLimit: Int?
        public var offRoute: Bool
        public var arrived: Bool
    }

    public struct Update: Sendable {
        public var state: State
        /// Text für die Sprachausgabe, falls jetzt etwas gesagt werden soll
        public var announcement: String?
        /// `true`: Route neu berechnen (Position zu weit weg)
        public var shouldReroute: Bool
    }

    public private(set) var route: Route
    public private(set) var progress: Double = 0
    public private(set) var arrived = false
    public let destinationName: String
    private var spoken: Set<String> = []
    private var monitor: RerouteMonitor
    /// Abstand zur Route (Meter), ab dem die Position nicht mehr auf die Route gesetzt wird
    public var snapTolerance: Double = 30
    /// Rest bis zum Ziel, ab dem „angekommen“ gilt
    public var arrivalRadius: Double = 25

    public init(route: Route, destinationName: String, monitor: RerouteMonitor = RerouteMonitor()) {
        self.route = route
        self.destinationName = destinationName
        self.monitor = monitor
    }

    /// Nach einer Neuberechnung: neue Route ab der aktuellen Position
    public mutating func replaceRoute(_ newRoute: Route) {
        route = newRoute
        progress = 0
        spoken = []
        monitor.reset()
    }

    /// Tempolimits kommen erst nach dem Start (eigene Anfrage) – ohne den Fortschritt zu verlieren
    public mutating func setSpeedLimits(_ limits: [Int]) {
        route.speedLimits = limits
    }

    /// Start-Ansage („Route nach … gestartet. 42 Minuten.“)
    public func startAnnouncement() -> String {
        let minutes = max(1, Int((route.duration / 60).rounded()))
        return "Route nach \(destinationName) gestartet. \(minutes) \(minutes == 1 ? "Minute" : "Minuten")."
    }

    /// Neue GPS-Position verarbeiten. `speed` in m/s (negativ/nil = unbekannt).
    public mutating func update(position: Coordinate, speed: Double? = nil, now: Date = Date()) -> Update {
        let v: Double = max(0, speed ?? 0)
        var offRoute = false
        var reroute = false
        if !arrived {
            // GM-020: erst nahe der bisherigen Stelle suchen, sonst die ganze restliche Route (z. B. nach einem Tunnel ohne GPS)
            var found = Self.snap(position, on: route, near: progress, lookahead: max(400, v * 40))
            if found.map({ $0.distance > snapTolerance }) ?? true {
                found = Self.snap(position, on: route, near: progress, lookahead: route.length)
            }
            if let snap = found, snap.distance <= snapTolerance {
                // GM-020: GPS springt etwas – kleine Rücksprünge ignorieren, sonst wiederholt sich eine Ansage
                if snap.along > progress || progress - snap.along > 40 { progress = snap.along }
                monitor.reset()
            } else {
                offRoute = true
                reroute = monitor.update(position: position, route: route, now: now)
            }
            let end = route.shape.last.map { position.distance(to: $0) } ?? .infinity
            if route.length - progress <= arrivalRadius || (end <= arrivalRadius && progress > route.length * 0.5) {
                arrived = true
                progress = route.length
                offRoute = false
                reroute = false
            }
        }
        let state = makeState(offRoute: offRoute)
        let text = reroute ? nil : announcement(for: state, speed: v)
        return Update(state: state, announcement: text, shouldReroute: reroute)
    }

    // MARK: intern

    func makeState(offRoute: Bool) -> State {
        let m = route.nextManeuver(after: progress)
        var then: Maneuver?
        if let m = m, let i = route.maneuvers.firstIndex(of: m), i + 1 < route.maneuvers.count {
            let n = route.maneuvers[i + 1]
            if n.distance - m.distance < 300 { then = n }
        }
        let remaining: Double = max(0, route.length - progress)
        let share: Double = route.length > 0 ? remaining / route.length : 0
        let seg = route.segmentIndex(at: progress)
        let street = seg < route.segmentNames.count ? route.segmentNames[seg] : ""
        return State(
            progress: progress,
            maneuver: m,
            distanceToManeuver: max(0, (m?.distance ?? route.length) - progress),
            thenManeuver: then,
            remainingDistance: remaining,
            remainingTime: route.duration * share,
            currentStreet: street,
            speedLimit: route.speedLimit(at: progress),
            offRoute: offRoute,
            arrived: arrived
        )
    }

    /// Ansage-Schwellen je nach Tempo: Stadt 400/150/30 m wie im Prototyp, schneller früher
    static func thresholds(speed: Double) -> [(Double, String)] {
        if speed > 25 { return [(2000, "far"), (800, "near"), (120, "now")] }   // > 90 km/h
        if speed > 14 { return [(800, "far"), (300, "near"), (60, "now")] }     // > 50 km/h
        return [(400, "far"), (150, "near"), (30, "now")]
    }

    mutating func announcement(for state: State, speed: Double) -> String? {
        if state.arrived {
            guard !spoken.contains("arrived") else { return nil }
            spoken.insert("arrived")
            return "Sie haben \(destinationName) erreicht."
        }
        guard let m = state.maneuver else { return nil }
        let d = state.distanceToManeuver
        let key = String(Int(m.distance.rounded()))
        let steps = Self.thresholds(speed: speed)
        // GM-020: immer die engste Stufe, in der wir gerade sind (erst „jetzt“, dann „nah“, dann „weit“) –
        // sonst blockiert eine schon gesprochene „nah“-Ansage die „jetzt“-Ansage (Test testAnnouncementsInCityOnceEach)
        for (limit, tag) in steps.reversed() where d <= limit {
            // „weit“ nur, wenn noch deutlich vor „nah“ – sonst doppelt kurz hintereinander
            if tag == "far" && d <= steps[1].0 + 50 { return nil }
            if spoken.contains(key + tag) { return nil }
            spoken.insert(key + tag)
            if m.kind == .destination {
                if tag == "now" { return nil }
                return "In \(Formatting.spokenDistance(d)) erreichen Sie Ihr Ziel."
            }
            let action = Self.lowerFirst(m.text)
            let onto = m.street.isEmpty ? "" : " auf \(m.street)"
            return tag == "now" ? "Jetzt \(action)\(onto)." : "In \(Formatting.spokenDistance(d)) \(action)\(onto)."
        }
        return nil
    }

    public static func lowerFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return f.lowercased() + s.dropFirst()
    }

    /// Nächster Punkt auf der Route im Fenster [progress − 50 m, progress + lookahead]
    static func snap(_ p: Coordinate, on route: Route, near progress: Double, lookahead: Double) -> (along: Double, distance: Double)? {
        guard route.shape.count > 1 else { return nil }
        let from = route.segmentIndex(at: progress - 50)
        let to = min(route.shape.count - 2, route.segmentIndex(at: progress + lookahead))
        guard from <= to else { return nil }
        let proj = LocalProjection(origin: p)
        var best: (along: Double, distance: Double)?
        for i in from...to {
            let a = proj.project(route.shape[i])
            let b = proj.project(route.shape[i + 1])
            let dx: Double = b.x - a.x
            let dy: Double = b.y - a.y
            let len2: Double = dx * dx + dy * dy
            var t: Double = len2 > 0 ? (-a.x * dx - a.y * dy) / len2 : 0
            t = min(1, max(0, t))
            let px: Double = a.x + t * dx
            let py: Double = a.y + t * dy
            let dist: Double = (px * px + py * py).squareRoot()
            let segLen: Double = route.cumulative[i + 1] - route.cumulative[i]
            let along: Double = route.cumulative[i] + t * segLen
            if best == nil || dist < best!.distance { best = (along, dist) }
        }
        return best
    }
}
