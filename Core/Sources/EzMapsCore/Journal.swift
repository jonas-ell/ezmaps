import Foundation

/// GM-043: Was die App lokal über den Nutzer weiß – Fahrten, Favoriten, Zuhause/Arbeit, geparktes Auto,
/// Abzeichen, Wochenmission. Alles bleibt auf dem Gerät (eine JSON-Datei, `GameStorage`).
public struct Journal: Codable, Equatable, Sendable {
    public struct Trip: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var date: Date
        public var destination: String
        public var meters: Double
        public var seconds: TimeInterval
        public var newPercent: Int
        /// Strecke als Polyline (Präzision 5, klein) – für Vorschaubild, Replay und „nochmal fahren“
        public var polyline: String

        public init(id: UUID = UUID(), date: Date, destination: String, meters: Double, seconds: TimeInterval, newPercent: Int, track: [Coordinate]) {
            self.id = id
            self.date = date
            self.destination = destination
            self.meters = meters
            self.seconds = seconds
            self.newPercent = newPercent
            self.polyline = Polyline.encode(track, precision: 5)
        }

        public var track: [Coordinate] { Polyline.decode(polyline, precision: 5) }
    }

    public struct ParkedCar: Codable, Equatable, Sendable {
        public var coordinate: Coordinate
        public var date: Date
        public init(coordinate: Coordinate, date: Date) {
            self.coordinate = coordinate
            self.date = date
        }
    }

    public static let maxTrips = 200

    public private(set) var trips: [Trip] = []
    public var favorites: [PhotonClient.Place] = []
    public var home: PhotonClient.Place?
    public var work: PhotonClient.Place?
    public var parked: ParkedCar?
    public var badges: Set<Badge> = []
    public var mission = WeeklyMission()
    /// Fahrten speichern (Einstellungen: abschaltbar, GM-033)
    public var keepTrips = true

    public init() {}

    public mutating func add(_ trip: Trip) {
        guard keepTrips else { return }
        trips.insert(trip, at: 0)
        if trips.count > Self.maxTrips { trips.removeLast(trips.count - Self.maxTrips) }
    }

    public mutating func deleteTrip(_ id: UUID) { trips.removeAll { $0.id == id } }
    public mutating func deleteAllTrips() { trips = [] }

    public func isFavorite(_ p: PhotonClient.Place) -> Bool {
        favorites.contains { $0.name == p.name && $0.coordinate.distance(to: p.coordinate) < 30 }
    }

    public mutating func toggleFavorite(_ p: PhotonClient.Place) {
        if isFavorite(p) { favorites.removeAll { $0.name == p.name && $0.coordinate.distance(to: p.coordinate) < 30 } }
        else { favorites.insert(p, at: 0) }
    }

    /// Summen für „Meine Fahrten“ (dieser Monat)
    public func monthSummary(now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> (meters: Double, trips: Int, seconds: TimeInterval) {
        let month = trips.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        return (month.reduce(0) { $0 + $1.meters }, month.count, month.reduce(0) { $0 + $1.seconds })
    }

    // Abwärtskompatibel lesen: fehlende Felder = Standard
    enum CodingKeys: String, CodingKey { case trips, favorites, home, work, parked, badges, mission, keepTrips }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trips = try c.decodeIfPresent([Trip].self, forKey: .trips) ?? []
        favorites = try c.decodeIfPresent([PhotonClient.Place].self, forKey: .favorites) ?? []
        home = try c.decodeIfPresent(PhotonClient.Place.self, forKey: .home)
        work = try c.decodeIfPresent(PhotonClient.Place.self, forKey: .work)
        parked = try c.decodeIfPresent(ParkedCar.self, forKey: .parked)
        badges = try c.decodeIfPresent(Set<Badge>.self, forKey: .badges) ?? []
        mission = try c.decodeIfPresent(WeeklyMission.self, forKey: .mission) ?? WeeklyMission()
        keepTrips = try c.decodeIfPresent(Bool.self, forKey: .keepTrips) ?? true
    }
}

/// Eine Mission pro Kalenderwoche (ohne Druck, GM-041). Wechselt jede Woche reihum.
public struct WeeklyMission: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable { case newKm, trips, newPercentTrip }

    /// Woche als „2026-44“
    public private(set) var week: String = ""
    public private(set) var kind: Kind = .newKm
    public private(set) var value: Double = 0

    public init() {}

    public var target: Double {
        switch kind {
        case .newKm: return 3
        case .trips: return 5
        case .newPercentTrip: return 1
        }
    }

    public var title: String {
        switch kind {
        case .newKm: return "Fahre 3 km neue Straßen"
        case .trips: return "Fahre 5 Mal mit EzMaps"
        case .newPercentTrip: return "Eine Fahrt mit mindestens 30 % neuen Straßen"
        }
    }

    public var progress: Double { min(1, value / target) }
    public var done: Bool { value >= target }
    public var progressText: String {
        switch kind {
        case .newKm: return String(format: "%.1f / %.0f km", min(value, target), target).replacingOccurrences(of: ".", with: ",")
        case .trips, .newPercentTrip: return "\(Int(min(value, target))) / \(Int(target))"
        }
    }

    static func weekKey(_ date: Date, calendar: Calendar) -> (key: String, index: Int) {
        var cal = calendar
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let y = cal.component(.yearForWeekOfYear, from: date), w = cal.component(.weekOfYear, from: date)
        return ("\(y)-\(w)", y * 53 + w)
    }

    /// Neue Woche → neue Mission (reihum), alter Fortschritt verfällt
    public mutating func roll(to date: Date, calendar: Calendar = Calendar(identifier: .iso8601)) {
        let wk = Self.weekKey(date, calendar: calendar)
        guard wk.key != week else { return }
        week = wk.key
        kind = Kind.allCases[wk.index % Kind.allCases.count]
        value = 0
    }

    /// Nach einer Fahrt eintragen. Gibt `true` zurück, wenn die Mission gerade erfüllt wurde.
    @discardableResult
    public mutating func record(_ reveal: TripReveal, date: Date, calendar: Calendar = Calendar(identifier: .iso8601)) -> Bool {
        roll(to: date, calendar: calendar)
        let was = done
        switch kind {
        case .newKm: value += Double(reveal.newCells.count) * ExploreCell.approxMeters / 1000
        case .trips: value += reveal.totalCells > 1 ? 1 : 0
        case .newPercentTrip: value += reveal.newPercent >= 30 ? 1 : 0
        }
        return !was && done
    }
}

extension ExploreCell {
    /// Kantenlänge einer Zelle in Deutschland (~24 m), für grobe Kilometer-Angaben
    public static let approxMeters: Double = 24
}
