import CoreLocation
import UIKit
import Foundation
import Observation
import EzMapsCore

/// Einstellungen (in UserDefaults gespeichert)
struct AppSettings: Codable, Equatable {
    var voice = true
    var duckMusic = true
    var showSpeedLimit = true
    var avoidHighway = false
    var avoidToll = false
    /// Simulierte Fahrt entlang der Route – zum Ausprobieren ohne Auto (auch für die App-Prüfung durch Apple)
    var demoDrive = false
    /// GM-043: gewählter Kartenstil (gilt nur, wenn freigeschaltet oder im Test – sonst Klassik)
    var style: MapStyle = .classic
    /// GM-043: Stimme (nil = beste deutsche) und Sprechtempo
    var voiceIdentifier: String?
    var speechRate: Double = 1
    /// GM-043: Onboarding (GM-031/032) schon gesehen
    var onboarded = false

    init() {}

    // GM-043: alte gespeicherte Einstellungen ohne neue Felder weiter lesen (sonst gingen sie verloren)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        voice = try c.decodeIfPresent(Bool.self, forKey: .voice) ?? true
        duckMusic = try c.decodeIfPresent(Bool.self, forKey: .duckMusic) ?? true
        showSpeedLimit = try c.decodeIfPresent(Bool.self, forKey: .showSpeedLimit) ?? true
        avoidHighway = try c.decodeIfPresent(Bool.self, forKey: .avoidHighway) ?? false
        avoidToll = try c.decodeIfPresent(Bool.self, forKey: .avoidToll) ?? false
        demoDrive = try c.decodeIfPresent(Bool.self, forKey: .demoDrive) ?? false
        style = try c.decodeIfPresent(MapStyle.self, forKey: .style) ?? .classic
        voiceIdentifier = try c.decodeIfPresent(String.self, forKey: .voiceIdentifier)
        speechRate = try c.decodeIfPresent(Double.self, forKey: .speechRate) ?? 1
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
    }
}

/// Gemeinsamer Zustand für iPhone und CarPlay (wie `app.state` im Prototyp, LESSONS_SWIFT 6).
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    enum Screen: Equatable { case map, search, preview, navigating, arrived }

    var screen: Screen = .map
    /// Nur über `updateSettings` ändern (speichert und gibt an die Sprachausgabe weiter)
    private(set) var settings: AppSettings
    let location = LocationService()

    // Suche
    var query = ""
    private(set) var results: [PhotonClient.Place] = []
    private(set) var isSearching = false
    private(set) var recents: [PhotonClient.Place] = []

    // Route
    private(set) var destination: PhotonClient.Place?
    private(set) var routes: [Route] = []
    var selectedRoute = 0
    private(set) var isRouting = false
    /// Zählt bei jeder neuen Route hoch – die Karte zeichnet dann neu und passt den Ausschnitt an
    private(set) var routeRevision = 0

    // Navigation
    private(set) var nav: NavigationSession.State?
    private(set) var isSpeaking = false
    private(set) var demoPosition: Coordinate?
    /// GM-022: Position auf der Route (eingerastet) und Fahrtrichtung in Grad – Kamera und Pfeil folgen dem,
    /// nicht dem GPS-Punkt von MapLibre (sonst bleibt die Karte bei der Demo-Fahrt stehen)
    private(set) var navCoordinate: Coordinate?
    private(set) var navHeading: Double = 0
    /// geschätzte Fahrgeschwindigkeit des Teilstücks (km/h) – für die Kamerahöhe, geglättet über die Route statt GPS
    private(set) var navSpeedKmh: Double = 50
    /// GM-025: freie Fahrt (ohne Route): Richtung und Tempo aus dem GPS (Richtung bleibt im Stand stehen)
    @ObservationIgnored private(set) var driveHeading: Double = 0
    @ObservationIgnored private(set) var driveKmh: Double = 30
    /// Kurzer Hinweis unten (Fehler, „Route wird neu berechnet“)
    var message: String?
    /// Zählt hoch, wenn die Karte wieder dem Standort folgen soll
    private(set) var recenterRequest = 0
    /// GM-041: Ergebnis „Stadt aufdecken“ der letzten Fahrt (für den Ankunft-Screen)
    private(set) var lastReveal: TripReveal?
    /// GM-043: Fahrten, Favoriten, Zuhause/Arbeit, Parkplatz, Abzeichen, Mission (lokal)
    private(set) var journal: Journal
    /// GM-043: aufgedeckte Straßen gesamt (für Entdecken)
    private(set) var exploredCells = 0
    private(set) var exploredKm: Double = 0
    /// GM-043: neue Abzeichen dieser Fahrt / Mission gerade geschafft
    private(set) var newBadges: [Badge] = []
    private(set) var missionJustDone = false
    /// GM-043: Stil-Test (GM-041) – nicht umgehbar, zählt auf iPhone und CarPlay
    private(set) var trial: StyleTrial
    /// Stil, dessen Test gerade abgelaufen ist (Blatt „Test vorbei“, nie in CarPlay)
    var trialEnded: MapStyle?
    /// Shop/Stil-Seite öffnen (nil = zu). `.classic` = allgemeiner Shop
    var shopRequest: MapStyle?
    /// GM-043: CarPlay verbunden (Testzeit zählt dann auch, wenn das iPhone gesperrt ist)
    var carPlayConnected = false
    /// iPhone-Oberfläche im Vordergrund (setzt ContentView aus scenePhase)
    var appActive = true
    /// GM-043: Baustelle/Sperrung auf der eigenen Strecke vor einem (Autobahn GmbH)
    private(set) var roadNotice: RoadNoticeFilter.Ahead?
    /// GM-043: nach dem Trennen von CarPlay „Wo hab ich geparkt?“ zeigen
    var showParkedCar = false
    /// GM-043: gefahrene Strecke dieser Fahrt (Leuchtlinie auf der Karte, alle 5 Punkte aktualisiert)
    private(set) var trail: [Coordinate] = []

    @ObservationIgnored private var session: NavigationSession?
    @ObservationIgnored private let speech = SpeechService()
    @ObservationIgnored private let valhalla = ValhallaClient(baseURL: AppConfig.valhallaURL, http: AppConfig.http)
    @ObservationIgnored private let photon = PhotonClient(baseURL: AppConfig.photonURL, http: AppConfig.http)
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private var rerouting = false
    @ObservationIgnored private let defaults = UserDefaults.standard
    /// GM-041: aufgedeckte Straßen (Datei) und die Punkte der laufenden Fahrt
    @ObservationIgnored private var exploration = GameStorage.loadExploration()
    @ObservationIgnored private var tripTrack: [Coordinate] = []
    @ObservationIgnored private var lastAccuracy: Double = .greatestFiniteMagnitude
    @ObservationIgnored private var tripStart: Date?
    @ObservationIgnored private var trialTask: Task<Void, Never>?
    @ObservationIgnored private var trialSaveCounter = 0
    @ObservationIgnored private var notices: [RoadNotice] = []
    @ObservationIgnored private var spokenNotices: Set<String> = []
    @ObservationIgnored private let autobahn = AutobahnClient(http: AppConfig.http)
    @ObservationIgnored let purchases = PurchaseManager.shared

    private init() {
        if let data = defaults.data(forKey: "settings"), let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = s
        } else {
            settings = AppSettings()
        }
        if let data = defaults.data(forKey: "recents"), let r = try? JSONDecoder().decode([PhotonClient.Place].self, from: data) {
            recents = r
        }
        journal = GameStorage.loadJournal()
        trial = GameStorage.loadTrial()
        speech.enabled = settings.voice
        speech.duckOthers = settings.duckMusic
        speech.voiceIdentifier = settings.voiceIdentifier
        speech.rateFactor = Float(settings.speechRate)
        speech.onSpeakingChange = { [weak self] on in self?.isSpeaking = on }
        location.onUpdate = { [weak self] loc in self?.handleGPS(loc) }
        journal.mission.roll(to: Date())
        updateExplorationStats()
        startTrialClock()
    }

    var currentCoordinate: Coordinate? {
        if let d = demoPosition { return d }
        guard let l = location.location else { return nil }
        return Coordinate(latitude: l.coordinate.latitude, longitude: l.coordinate.longitude)
    }

    /// GM-025: Ziel für die gleitende Kamera – in der Navigation die Position auf der Route, sonst das GPS
    var cameraTarget: FollowCamera.Target? {
        if screen == .navigating, let c = navCoordinate { return .init(coordinate: c, heading: navHeading, kmh: navSpeedKmh) }
        guard let c = currentCoordinate else { return nil }
        return .init(coordinate: c, heading: driveHeading, kmh: driveKmh)
    }

    var selected: Route? { routes.indices.contains(selectedRoute) ? routes[selectedRoute] : nil }

    func onAppear() { location.requestPermission() }

    func recenter() { recenterRequest += 1 }

    // MARK: Suche

    func openSearch() {
        query = ""
        results = []
        screen = .search
    }

    func closeSearch() {
        searchTask?.cancel()
        screen = .map
    }

    /// Bei jeder Eingabe: kurz warten, dann suchen (alte Suche abbrechen, LESSONS_SWIFT 3)
    func queryChanged() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; isSearching = false; return }
        let near = currentCoordinate
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            do {
                let found = try await self.photon.search(q, near: near)
                guard !Task.isCancelled else { return }
                self.results = found
            } catch {
                guard !Task.isCancelled else { return }
                self.show(L("Suche gerade nicht erreichbar"))
            }
            self.isSearching = false
        }
    }

    // MARK: Route planen

    func choose(_ place: PhotonClient.Place) {
        guard let from = currentCoordinate else {
            show(location.isDenied ? L("Bitte Ortungsdienste für EzMaps erlauben") : L("Standort wird gesucht …"))
            return
        }
        searchTask?.cancel()
        destination = place
        recents = [place] + recents.filter { $0 != place }.prefix(7)
        if let data = try? JSONEncoder().encode(recents) { defaults.set(data, forKey: "recents") }
        isRouting = true
        screen = .preview
        routes = []
        var o = ValhallaClient.Options()
        o.avoidHighway = settings.avoidHighway
        o.avoidToll = settings.avoidToll
        Task { [weak self] in
            guard let self else { return }
            do {
                let found = try await self.valhalla.routes(from: from, to: place.coordinate, options: o)
                self.routes = found
                self.selectedRoute = 0
                self.routeRevision += 1
                if found.isEmpty { self.show(L("Keine Route gefunden")); self.screen = .map }
            } catch {
                self.show(L("Keine Route gefunden"))
                self.screen = .map
            }
            self.isRouting = false
        }
    }

    func cancelPreview() {
        routes = []
        destination = nil
        routeRevision += 1
        screen = .map
    }

    // MARK: Navigation

    func startNavigation() {
        guard let route = selected, let dest = destination else { return }
        let s = NavigationSession(route: route, destinationName: dest.name)
        session = s
        nav = nil
        navCoordinate = route.coordinate(at: 0)
        navHeading = route.heading(at: 0)
        screen = .navigating
        tripTrack = []
        trail = []
        tripStart = Date()
        lastReveal = nil
        newBadges = []
        missionJustDone = false
        roadNotice = nil
        notices = []
        spokenNotices = []
        loadRoadNotices(for: route)
        location.setNavigating(true)
        speech.say(s.startAnnouncement())
        loadSpeedLimits(for: route)
        if settings.demoDrive { startDemo(on: route) }
    }

    func endNavigation() {
        // abgebrochene Fahrt: gefahrene Straßen trotzdem aufdecken
        if lastReveal == nil { finishTrip() }
        tripTrack = []
        trail = []
        roadNotice = nil
        demoTask?.cancel()
        demoPosition = nil
        navCoordinate = nil
        speech.stop()
        session = nil
        nav = nil
        routes = []
        destination = nil
        routeRevision += 1
        location.setNavigating(false)
        screen = .map
        recenter()
    }

    private func loadSpeedLimits(for route: Route) {
        Task { [weak self] in
            guard let self, let limits = try? await self.valhalla.speedLimits(for: route) else { return }
            // nur übernehmen, wenn noch dieselbe Route gefahren wird
            guard self.session?.route.shape == route.shape else { return }
            self.session?.setSpeedLimits(limits)
        }
    }

    private func handleGPS(_ loc: CLLocation) {
        if loc.speed > 1.5 && loc.course >= 0 { driveHeading = loc.course }
        if loc.speed >= 0 { driveKmh = loc.speed * 3.6 }
        lastAccuracy = loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : .greatestFiniteMagnitude
        guard demoPosition == nil else { return } // Demo-Fahrt hat Vorrang
        let speed: Double? = loc.speed >= 0 ? loc.speed : nil
        let course: Double? = loc.course >= 0 ? loc.course : nil
        feed(Coordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude), speed: speed, course: course)
    }

    private func feed(_ position: Coordinate, speed: Double?, course: Double?) {
        guard var s = session else { return }
        let u = s.update(position: position, speed: speed)
        session = s
        record(position)
        nav = u.state
        navCoordinate = s.route.coordinate(at: u.state.progress) ?? position
        navHeading = s.route.heading(at: u.state.progress)
        let seg = s.route.segmentIndex(at: u.state.progress)
        if seg < s.route.segmentSpeeds.count { navSpeedKmh = s.route.segmentSpeeds[seg] }
        if let text = u.announcement, settings.voice { speech.say(text) }
        updateRoadNotice(progress: u.state.progress, route: s.route)
        if u.shouldReroute { reroute(from: position, heading: course) }
        if u.state.arrived && screen == .navigating {
            demoTask?.cancel()
            location.setNavigating(false)
            finishTrip()
            if trial.navigationEnded() != nil, let s = MapStyle.allCases.first(where: { $0 == settings.style }) {
                GameStorage.saveTrial(trial)
                updateSettings { $0.style = .classic }
                trialEnded = s
            }
            screen = .arrived
        }
    }

    // MARK: Stadt aufdecken (GM-041)

    /// Nur genaue Punkte (≤ 30 m) und erst ab 10 m Abstand aufnehmen. Die Demo-Fahrt zählt nur in Debug-Builds
    /// (zum Testen im Simulator), im Store-Build deckt sie nichts auf.
    private func record(_ position: Coordinate) {
        #if DEBUG
        let demoCounts = demoPosition != nil
        #else
        let demoCounts = false
        #endif
        guard demoCounts || (demoPosition == nil && lastAccuracy <= 30) else { return }
        if let last = tripTrack.last, last.distance(to: position) < 10 { return }
        tripTrack.append(position)
        if tripTrack.count % 5 == 0 { trail = tripTrack }
    }

    private func finishTrip() {
        guard tripTrack.count > 1 else { return }
        let reveal = exploration.addTrip(tripTrack)
        lastReveal = reveal
        GameStorage.saveExploration(exploration)
        // GM-043: Fahrtenbuch, Mission, Abzeichen
        let now = Date()
        let meters: Double = zip(tripTrack, tripTrack.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
        journal.add(.init(date: now, destination: destination?.name ?? L("Fahrt"), meters: meters,
                          seconds: now.timeIntervalSince(tripStart ?? now), newPercent: reveal.newPercent, track: tripTrack))
        missionJustDone = journal.mission.record(reveal, date: now)
        let hour = Calendar.current.component(.hour, from: now)
        let earned = Badge.earned(store: exploration, hour: hour, bestDistrict: 0, cityShare: 0, have: journal.badges)
        newBadges = earned
        journal.badges.formUnion(earned)
        GameStorage.saveJournal(journal)
        updateExplorationStats()
    }

    private func updateExplorationStats() {
        exploredCells = exploration.driven.count
        exploredKm = Double(exploredCells) * ExploreCell.approxMeters / 1000
    }

    /// Aufgedeckte Zellen (für die Leuchtlinien auf der Karte)
    var exploredCellKeys: Set<UInt64> { exploration.driven }

    /// Anteil neuer Straßen auf einer geplanten Route (Routen-Vorschau „+38 % neue Straßen“)
    func newShare(of route: Route) -> Double { exploration.newShare(of: route.shape) }

    /// Anteil eines Gebiets (Zellen aller Straßen im Kartenausschnitt, aus MapLibre)
    func share(of roadCells: Set<UInt64>) -> Double { exploration.share(of: roadCells) }

    /// Entdeckte Karte zurücksetzen (Einstellungen). Testzeit und Käufe bleiben.
    func resetExploration() {
        exploration.reset()
        GameStorage.saveExploration(exploration)
        journal.badges = []
        GameStorage.saveJournal(journal)
        updateExplorationStats()
    }

    // MARK: Fahrtenbuch, Favoriten, Zuhause/Arbeit, Parkplatz (GM-043)

    func updateJournal(_ change: (inout Journal) -> Void) {
        change(&journal)
        GameStorage.saveJournal(journal)
    }

    func toggleFavorite(_ p: PhotonClient.Place) { updateJournal { $0.toggleFavorite(p) } }

    /// Beim Trennen von CarPlay: Standort als Parkplatz merken und beim nächsten Öffnen zeigen
    func parkCar() {
        guard let c = currentCoordinate else { return }
        updateJournal { $0.parked = .init(coordinate: c, date: Date()) }
        showParkedCar = true
    }

    /// Zu Fuß zum Auto: Apple Karten (EzMaps navigiert nur Auto)
    func walkToCar() {
        guard let p = journal.parked else { return }
        let url = URL(string: "http://maps.apple.com/?daddr=\(p.coordinate.latitude),\(p.coordinate.longitude)&dirflg=w")
        if let url { UIApplication.shared.open(url) }
    }

    // MARK: Baustellen und Sperrungen (GM-043, Autobahn GmbH)

    private func loadRoadNotices(for route: Route) {
        let roads = AutobahnClient.roads(on: route)
        guard !roads.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            var all: [RoadNotice] = []
            for r in roads.prefix(4) { all += (try? await self.autobahn.notices(road: r)) ?? [] }
            guard self.session?.route.shape == route.shape else { return }
            self.notices = all
        }
    }

    private func updateRoadNotice(progress: Double, route: Route) {
        guard !notices.isEmpty else { roadNotice = nil; return }
        let next = RoadNoticeFilter.ahead(notices, route: route, progress: progress, within: 5_000).first
        if roadNotice != next { roadNotice = next }
        // einmal ansagen, ab 2 km
        if let n = next, n.distance <= 2_000, !spokenNotices.contains(n.notice.id), settings.voice {
            spokenNotices.insert(n.notice.id)
            let what = n.notice.label == "Sperrung" ? "Sperrung" : "Baustelle"
            speech.say("\(what) in \(Formatting.distance(n.distance)).")
        }
    }

    // MARK: Stile, Käufe, Stil-Test (GM-043)

    /// Stil, der wirklich gezeigt wird: gewählter Stil, wenn freigeschaltet oder im Test – sonst Klassik
    var activeStyle: MapStyle {
        let s = settings.style
        if purchases.access.isUnlocked(s) || trial.active == s.trialKey { return s }
        return .classic
    }

    func isUnlocked(_ style: MapStyle) -> Bool { purchases.access.isUnlocked(style) }

    /// Stil wählen. Freigeschaltet → sofort. Sonst Test starten, wenn noch Zeit da ist, sonst Stil-Seite öffnen.
    func selectStyle(_ style: MapStyle) {
        if isUnlocked(style) {
            if let a = trial.active, a != style.trialKey { trial.stop() }
            updateSettings { $0.style = style }
            return
        }
        if trial.start(style.trialKey) {
            updateSettings { $0.style = style }
            GameStorage.saveTrial(trial)
            show(String(format: L("%@ 10 Minuten testen"), L(style.titleKey)))
        } else {
            shopRequest = style
        }
    }

    /// Restzeit des laufenden Tests (für die Uhr auf iPhone und CarPlay)
    var trialRemaining: TimeInterval? {
        guard let a = trial.active, !isUnlocked(settings.style) else { return nil }
        return trial.remaining(a)
    }

    /// Nach einem Kauf: Test beenden, Stil bleibt
    func purchaseCompleted(for style: MapStyle?) {
        trial.stop()
        GameStorage.saveTrial(trial)
        if let s = style { updateSettings { $0.style = s } }
        trialEnded = nil
    }

    /// Jede Sekunde: Testzeit zählen, solange der Stil sichtbar ist (iPhone vorn oder CarPlay verbunden).
    /// Gemessen mit der Laufzeit seit Gerätestart, nicht mit der Uhrzeit (Uhr verstellen bringt nichts).
    private func startTrialClock() {
        trialTask?.cancel()
        trialTask = Task { [weak self] in
            var last = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let dt = min(5, max(0, now - last)) // Schlaf/Hintergrund: nicht nachzählen
                last = now
                self.tickTrial(dt)
            }
        }
    }

    private func tickTrial(_ dt: TimeInterval) {
        guard let active = trial.active else { return }
        if isUnlocked(settings.style) { trial.stop(); GameStorage.saveTrial(trial); return }
        let visible = appActive || carPlayConnected
        let event = trial.tick(seconds: dt, visible: visible, navigating: screen == .navigating)
        trialSaveCounter += 1
        if trialSaveCounter >= 10 || event != nil { trialSaveCounter = 0; GameStorage.saveTrial(trial) }
        switch event {
        case .some(.oneMinuteLeft): show(L("Noch 1 Minute Test"))
        case .some(.expiresAfterArrival): break
        case .some(.expired): endTrial(active)
        case .none: break
        }
    }

    private func endTrial(_ key: String) {
        let style = MapStyle.allCases.first { $0.trialKey == key }
        updateSettings { $0.style = .classic }
        if let style, !carPlayOnlyNow { trialEnded = style }
    }

    /// CarPlay verbunden und iPhone nicht vorn: dort nie ein Blatt zeigen
    private var carPlayOnlyNow: Bool { carPlayConnected && !appActive }

    /// Beim Wechsel in den Hintergrund sichern
    func saveTrialNow() { GameStorage.saveTrial(trial) }

    func completeOnboarding() { updateSettings { $0.onboarded = true } }

    private func reroute(from position: Coordinate, heading: Double?) {
        guard !rerouting, let s = session, let dest = destination else { return }
        rerouting = true
        show(L("Route wird neu berechnet"))
        speech.say("Route wird neu berechnet.")
        let missed = s.route.nextManeuver(after: s.progress).flatMap { s.route.coordinate(at: $0.distance) }
        var o = ValhallaClient.Options()
        o.avoidHighway = settings.avoidHighway
        o.avoidToll = settings.avoidToll
        Task { [weak self] in
            guard let self else { return }
            if let r = try? await self.valhalla.reroute(from: position, heading: heading, to: dest.coordinate, missedTurn: missed, options: o) {
                self.session?.replaceRoute(r)
                self.routes = [r]
                self.selectedRoute = 0
                self.routeRevision += 1
                self.loadSpeedLimits(for: r)
            } else {
                self.show(L("Neuberechnung fehlgeschlagen"))
            }
            self.rerouting = false
        }
    }

    /// Nur Store-Screenshots (ScreenshotMode): Demo-Fahrt startet nach so vielen Metern
    @ObservationIgnored var demoStartOffset: Double = 0

    /// Demo-Fahrt: fährt die Route mit den geschätzten Geschwindigkeiten ab (2× Echtzeit)
    private func startDemo(on route: Route) {
        demoTask?.cancel()
        let offset = min(demoStartOffset, route.length * 0.9)
        demoTask = Task { [weak self] in
            var d: Double = offset
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled, let self, let current = self.session?.route else { return }
                if current.shape != route.shape { d = self.session?.progress ?? 0 }
                let seg = current.segmentIndex(at: d)
                let kmh: Double = seg < current.segmentSpeeds.count ? current.segmentSpeeds[seg] : 50
                let mps: Double = kmh / 3.6
                d = min(current.length, d + mps * 0.5 * 2)
                guard let p = current.coordinate(at: d) else { return }
                self.demoPosition = p
                self.feed(p, speed: mps, course: current.heading(at: d))
                if self.screen != .navigating { return }
            }
        }
    }

    // MARK: Einstellungen, Hinweise

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        var s = settings
        change(&s)
        guard s != settings else { return }
        settings = s
        speech.enabled = settings.voice
        speech.duckOthers = settings.duckMusic
        speech.voiceIdentifier = settings.voiceIdentifier
        speech.rateFactor = Float(settings.speechRate)
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "settings") }
    }

    func show(_ text: String) {
        message = text
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
