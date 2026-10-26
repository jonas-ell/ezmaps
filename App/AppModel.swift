import CoreLocation
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

    @ObservationIgnored private var session: NavigationSession?
    @ObservationIgnored private let speech = SpeechService()
    @ObservationIgnored private let valhalla = ValhallaClient(baseURL: AppConfig.valhallaURL, http: AppConfig.http)
    @ObservationIgnored private let photon = PhotonClient(baseURL: AppConfig.photonURL, http: AppConfig.http)
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private var rerouting = false
    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        if let data = defaults.data(forKey: "settings"), let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = s
        } else {
            settings = AppSettings()
        }
        if let data = defaults.data(forKey: "recents"), let r = try? JSONDecoder().decode([PhotonClient.Place].self, from: data) {
            recents = r
        }
        speech.enabled = settings.voice
        speech.duckOthers = settings.duckMusic
        speech.onSpeakingChange = { [weak self] on in self?.isSpeaking = on }
        location.onUpdate = { [weak self] loc in self?.handleGPS(loc) }
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
        location.setNavigating(true)
        speech.say(s.startAnnouncement())
        loadSpeedLimits(for: route)
        if settings.demoDrive { startDemo(on: route) }
    }

    func endNavigation() {
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
        guard demoPosition == nil else { return } // Demo-Fahrt hat Vorrang
        let speed: Double? = loc.speed >= 0 ? loc.speed : nil
        let course: Double? = loc.course >= 0 ? loc.course : nil
        feed(Coordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude), speed: speed, course: course)
    }

    private func feed(_ position: Coordinate, speed: Double?, course: Double?) {
        guard var s = session else { return }
        let u = s.update(position: position, speed: speed)
        session = s
        nav = u.state
        navCoordinate = s.route.coordinate(at: u.state.progress) ?? position
        navHeading = s.route.heading(at: u.state.progress)
        let seg = s.route.segmentIndex(at: u.state.progress)
        if seg < s.route.segmentSpeeds.count { navSpeedKmh = s.route.segmentSpeeds[seg] }
        if let text = u.announcement, settings.voice { speech.say(text) }
        if u.shouldReroute { reroute(from: position, heading: course) }
        if u.state.arrived && screen == .navigating {
            demoTask?.cancel()
            location.setNavigating(false)
            screen = .arrived
        }
    }

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
