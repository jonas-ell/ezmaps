import Foundation

/// „Stadt aufdecken“ (GM-041): gefahrene Strecken werden zu Straßenzellen (Kacheln Zoom 20, in Deutschland
/// etwa 24 × 24 m). Funktioniert überall in Deutschland ohne eigene Straßendaten: Für „+12 % neue Straßen“
/// reicht der Vergleich mit den schon gefahrenen Zellen. Für Prozent je Ortsteil liefert die App die Zellen
/// der Straßen im Ortsteil (aus den Kartenkacheln, gleiche Funktion `cells(along:)`).
/// Mirror in tools/prototype/js/explore.js – change both.
public enum ExploreCell {
    public static let zoom = 20

    /// Zelle als eine Zahl: x · 2^20 + y (passt in 40 Bit, auch in JavaScript genau)
    public static func key(_ c: Coordinate) -> UInt64 {
        let n = Double(1 << zoom)
        let lat = max(-85.0511, min(85.0511, c.latitude)) * .pi / 180
        let x = UInt64(max(0, min(n - 1, floor((c.longitude + 180) / 360 * n))))
        let y = UInt64(max(0, min(n - 1, floor((1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2 * n))))
        return x << 20 | y
    }

    /// Mittelpunkt einer Zelle (zum Zeichnen)
    public static func center(_ key: UInt64) -> Coordinate {
        let n = Double(1 << zoom), x = Double(key >> 20) + 0.5, y = Double(key & 0xFFFFF) + 0.5
        let lon = x / n * 360 - 180
        let lat = atan(sinh(.pi * (1 - 2 * y / n))) * 180 / .pi
        return Coordinate(latitude: lat, longitude: lon)
    }

    /// Alle Zellen entlang einer Linie, in Schritten von `step` Metern. Sprünge über `maxGap` (GPS-Lücke,
    /// Tunnel) werden nicht aufgefüllt, damit keine Straßen aufgedeckt werden, die man nicht gefahren ist.
    public static func cells(along line: [Coordinate], step: Double = 8, maxGap: Double = 400) -> [UInt64] {
        guard let first = line.first else { return [] }
        var out: [UInt64] = [key(first)]
        var seen: Set<UInt64> = [out[0]]
        func add(_ c: Coordinate) { let k = key(c); if seen.insert(k).inserted { out.append(k) } }
        for (a, b) in zip(line, line.dropFirst()) {
            let d = a.distance(to: b)
            if d > maxGap { add(b); continue }
            let n = max(1, Int(ceil(d / step)))
            for i in 1...n {
                let t = Double(i) / Double(n)
                add(Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * t, longitude: a.longitude + (b.longitude - a.longitude) * t))
            }
        }
        return out
    }
}

/// Ergebnis einer Fahrt für den Ankunft-Screen
public struct TripReveal: Equatable, Sendable {
    /// Zellen, die vorher noch nie gefahren wurden (für das Aufleuchten)
    public var newCells: [UInt64]
    public var totalCells: Int
    /// 0…100, gerundet
    public var newPercent: Int { totalCells == 0 ? 0 : Int((Double(newCells.count) / Double(totalCells) * 100).rounded()) }
}

/// Stufe in einem Ort, aus dem Anteil der aufgedeckten Straßen
public struct ExploreLevel: Equatable, Sendable {
    public var number: Int
    public var title: String
    /// Anteil (0…1) für die nächste Stufe; nil = höchste Stufe
    public var next: Double?

    /// Grenzen 0 / 10 / 25 / 50 / 75 %
    public static let thresholds: [Double] = [0, 0.10, 0.25, 0.50, 0.75]
    static let titles = ["Neu hier", "Unterwegs", "Kenner", "Insider", "Legende"]

    public static func forShare(_ share: Double) -> ExploreLevel {
        let i = thresholds.lastIndex { share >= $0 } ?? 0
        return ExploreLevel(number: i + 1, title: titles[i], next: i + 1 < thresholds.count ? thresholds[i + 1] : nil)
    }
}

/// Gespeicherter Fortschritt (nur auf dem Gerät; die App sichert ihn als Datei, optional iCloud)
public struct ExplorationStore: Codable, Equatable, Sendable {
    public private(set) var driven: Set<UInt64> = []
    public private(set) var totalMeters: Double = 0
    public private(set) var trips: Int = 0

    public init() {}

    /// Nach einer Fahrt aufrufen. `track` = tatsächlich gefahrene GPS-Punkte (schon gefiltert: Genauigkeit ≤ 30 m).
    @discardableResult
    public mutating func addTrip(_ track: [Coordinate]) -> TripReveal {
        let cells = ExploreCell.cells(along: track)
        let fresh = cells.filter { !driven.contains($0) }
        driven.formUnion(cells)
        totalMeters += zip(track, track.dropFirst()).reduce(0) { $0 + min($1.0.distance(to: $1.1), 400) }
        if cells.count > 1 { trips += 1 }
        return TripReveal(newCells: fresh, totalCells: cells.count)
    }

    /// Anteil neuer Straßen auf einer geplanten Route (für „Neues entdecken · +38 % neue Straßen“)
    public func newShare(of route: [Coordinate]) -> Double {
        let cells = ExploreCell.cells(along: route)
        guard !cells.isEmpty else { return 0 }
        return Double(cells.filter { !driven.contains($0) }.count) / Double(cells.count)
    }

    /// Anteil eines Ortsteils: `roadCells` = Zellen aller Straßen im Ortsteil (aus den Kartenkacheln)
    public func share(of roadCells: Set<UInt64>) -> Double {
        roadCells.isEmpty ? 0 : Double(roadCells.intersection(driven).count) / Double(roadCells.count)
    }

    public mutating func reset() { self = ExplorationStore() }
}

/// Abzeichen (eigene Namen, keine Spielinhalte)
public enum Badge: String, CaseIterable, Codable, Sendable {
    case firstDrive, km10, km100, km1000, nightOwl, earlyBird, districtComplete, explorer25, explorer50, explorer100

    public var title: String {
        switch self {
        case .firstDrive: return "Erste Fahrt"
        case .km10: return "10 km"
        case .km100: return "100 km"
        case .km1000: return "1000 km"
        case .nightOwl: return "Nachteule"
        case .earlyBird: return "Frühstarter"
        case .districtComplete: return "Ortsteil komplett"
        case .explorer25: return "Entdecker 25 %"
        case .explorer50: return "Entdecker 50 %"
        case .explorer100: return "Entdecker 100 %"
        }
    }

    /// Welche Abzeichen nach einer Fahrt neu dazukommen. `hour` = Stunde der Ankunft (0…23),
    /// `bestDistrict` / `cityShare` = Anteile 0…1.
    public static func earned(store: ExplorationStore, hour: Int, bestDistrict: Double, cityShare: Double, have: Set<Badge>) -> [Badge] {
        var out: [Badge] = []
        func check(_ b: Badge, _ ok: Bool) { if ok && !have.contains(b) { out.append(b) } }
        check(.firstDrive, store.trips >= 1)
        check(.km10, store.totalMeters >= 10_000)
        check(.km100, store.totalMeters >= 100_000)
        check(.km1000, store.totalMeters >= 1_000_000)
        check(.nightOwl, hour >= 23 || hour < 4)
        check(.earlyBird, hour >= 5 && hour < 7)
        check(.districtComplete, bestDistrict >= 0.95)
        check(.explorer25, cityShare >= 0.25)
        check(.explorer50, cityShare >= 0.50)
        check(.explorer100, cityShare >= 0.95)
        return out
    }
}
