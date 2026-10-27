import CarPlay
import MapKit
import Observation
import UIKit
import MapLibre
import EzMapsCore

/// CarPlay-Szene für Navi-Apps: eigenes Kartenfenster (carWindow) mit der Neon-Karte, darüber CPMapTemplate.
/// Ziele, Suche, Routen-Vorschau und Abbiegehinweise zeichnet iOS selbst (Vorlagen) – wir liefern nur Karte und Daten.
/// Zustand kommt aus AppModel.shared (dieselbe Navigation wie auf dem iPhone, LESSONS_SWIFT 6).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPMapTemplateDelegate, CPSearchTemplateDelegate {
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var mapTemplate: CPMapTemplate?
    private var mapController: CarMapViewController?
    private var trip: CPTrip?
    private var navSession: CPNavigationSession?
    private var shownRevision = -1
    private var lastManeuverKey = ""
    private var searchTask: Task<Void, Never>?

    @MainActor private var model: AppModel { AppModel.shared }

    /// GM-024: CarPlay zeigt die Einheit so, wie wir sie geben – ab 1 km in Kilometern (eine Nachkommastelle), sonst gerundete Meter
    static func distance(_ meters: Double) -> Measurement<UnitLength> {
        let d = Formatting.carPlayDistance(meters) // GM-029: Logik in Core, getestet
        return Measurement(value: d.value, unit: d.kilometers ? .kilometers : .meters)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window
        let controller = CarMapViewController()
        window.rootViewController = controller
        mapController = controller

        let template = CPMapTemplate()
        template.mapDelegate = self
        template.automaticallyHidesNavigationBar = false
        let destinations = CPBarButton(title: L("Ziele")) { [weak self] _ in
            MainActor.assumeIsolated { self?.showDestinations() }
        }
        template.leadingNavigationBarButtons = [destinations]
        template.mapButtons = [
            mapButton("plus.magnifyingglass") { [weak self] in self?.mapController?.zoom(by: 1) },
            mapButton("minus.magnifyingglass") { [weak self] in self?.mapController?.zoom(by: -1) },
            mapButton("location.north.line") { [weak self] in self?.mapController?.recenter() },
            // GM-045: Karte verschieben – Pflicht für CarPlay-Navis (Autos mit Drehknopf haben keinen Touchscreen)
            mapButton("arrow.up.and.down.and.arrow.left.and.right") { [weak self] in
                self?.mapController?.beginPan()
                self?.mapTemplate?.showPanningInterface(animated: true)
            },
        ]
        mapTemplate = template
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
        MainActor.assumeIsolated {
            model.carPlayConnected = true // GM-043: Stil-Test zählt auch im Auto
            observe()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        navSession = nil
        trip = nil
        mapTemplate = nil
        mapController = nil
        self.interfaceController = nil
        self.carWindow = nil
        MainActor.assumeIsolated {
            model.carPlayConnected = false
            model.saveTrialNow()
            model.parkCar() // GM-043: „Wo hab ich geparkt?“ – Standort beim Trennen merken
        }
    }

    private func mapButton(_ symbol: String, action: @escaping () -> Void) -> CPMapButton {
        let b = CPMapButton { _ in action() }
        b.image = GlassRoundButton.hud[symbol].flatMap { UIImage(named: $0) } ?? UIImage(systemName: symbol) // GM-045: HUD-Knöpfe
        return b
    }

    // MARK: Zustand beobachten (Observation ohne SwiftUI)

    @MainActor private func observe() {
        guard mapTemplate != nil else { return }
        withObservationTracking {
            _ = model.screen
            _ = model.nav
            _ = model.routeRevision
            _ = model.selectedRoute
            _ = model.isRouting
            _ = model.navCoordinate
            _ = model.activeStyle
            _ = model.trail
            _ = model.trialRemaining
            _ = model.rerouting
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.sync()
                    self?.observe()
                }
            }
        }
        sync()
    }

    @MainActor private func sync() {
        guard let template = mapTemplate else { return }
        mapController?.show(routes: model.routes, selected: model.selectedRoute, destination: model.destination?.coordinate,
                            revision: model.routeRevision, navigating: model.screen == .navigating, limit: model.settings.showSpeedLimit ? model.nav?.speedLimit : nil,
                            follow: model.navCoordinate, heading: model.navHeading, speedKmh: model.navSpeedKmh)
        mapController?.update(style: model.activeStyle, trail: model.trail, trialRemaining: model.trialRemaining)
        switch model.screen {
        case .preview:
            if !model.routes.isEmpty && shownRevision != model.routeRevision, let t = makeTrip() {
                shownRevision = model.routeRevision
                trip = t
                let text = CPTripPreviewTextConfiguration(startButtonTitle: L("Los"), additionalRoutesButtonTitle: L("Routen"), overviewButtonTitle: L("Übersicht"))
                template.showTripPreviews([t], textConfiguration: text)
            }
        case .navigating:
            if navSession == nil, let t = trip ?? makeTrip() {
                template.hideTripPreviews()
                trip = t
                navSession = template.startNavigationSession(for: t)
                lastManeuverKey = ""
            }
            if model.selected != nil, shownRevision != model.routeRevision {
                // Neuberechnung: neue Route im Kartenfenster, Hinweise werden unten neu gesetzt
                shownRevision = model.routeRevision
                lastManeuverKey = ""
            }
            if model.rerouting {
                // GM-045: Abbiegekarte zeigt „Route wird neu berechnet“; die nächsten Hinweise (neue Revision) setzen sie fort
                if lastManeuverKey != "pause" {
                    lastManeuverKey = "pause"
                    navSession?.pauseTrip(for: .rerouting, description: L("Route wird neu berechnet"))
                }
            } else {
                updateGuidance()
            }
        case .arrived:
            navSession?.finishTrip()
            navSession = nil
            trip = nil
        case .map, .search:
            if navSession != nil { navSession?.cancelTrip(); navSession = nil }
            if trip != nil { template.hideTripPreviews(); trip = nil }
            shownRevision = -1
        }
    }

    @MainActor private func makeTrip() -> CPTrip? {
        guard let dest = model.destination, let from = model.currentCoordinate, !model.routes.isEmpty else { return nil }
        let origin = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: from.latitude, longitude: from.longitude)))
        let target = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: dest.coordinate.latitude, longitude: dest.coordinate.longitude)))
        target.name = dest.name
        var choices: [CPRouteChoice] = []
        for (i, r) in model.routes.enumerated() {
            let title: String = i == 0 ? L("Schnellste") : String(format: L("Alternative %d"), i)
            let choice = CPRouteChoice(
                summaryVariants: [title + " · " + Formatting.minutes(r.duration)],
                additionalInformationVariants: [Formatting.distance(r.length)],
                selectionSummaryVariants: [Formatting.minutes(r.duration)]
            )
            choice.userInfo = i
            choices.append(choice)
        }
        return CPTrip(origin: origin, destination: target, routeChoices: choices)
    }

    /// Abbiegehinweis und Restzeit an CarPlay geben (Abbiegekarte und Tacho-Anzeige zeichnet iOS)
    @MainActor private func updateGuidance() {
        guard let session = navSession, let state = model.nav, let m = state.maneuver, let t = trip else { return }
        let key = "\(model.routeRevision)-\(Int(m.distance))"
        let estimates = CPTravelEstimates(distanceRemaining: Self.distance(state.distanceToManeuver), timeRemaining: 0)
        if key != lastManeuverKey {
            lastManeuverKey = key
            let man = CPManeuver()
            let street = m.kind == .destination ? (model.destination?.name ?? "") : m.street
            man.instructionVariants = street.isEmpty ? [m.text] : [m.text + " · " + street, street]
            man.symbolImage = UIImage(systemName: NavigationHUD.symbol(for: m.kind))
            man.initialTravelEstimates = estimates
            session.upcomingManeuvers = [man]
        } else if let current = session.upcomingManeuvers.first {
            session.updateEstimates(estimates, for: current)
        }
        let total = CPTravelEstimates(distanceRemaining: Self.distance(state.remainingDistance), timeRemaining: state.remainingTime)
        mapTemplate?.update(total, for: t, with: .default)
    }

    // MARK: Ziele und Suche

    @MainActor private func showDestinations() {
        let search = CPListItem(text: L("Suchen"), detailText: nil, image: UIImage(systemName: "magnifyingglass"))
        search.handler = { [weak self] _, done in
            MainActor.assumeIsolated { self?.showSearch() }
            done()
        }
        var items: [CPListItem] = [search]
        for place in model.recents.prefix(8) {
            let item = CPListItem(text: place.name, detailText: place.subtitle, image: UIImage(systemName: "clock.arrow.circlepath"))
            item.handler = { [weak self] _, done in
                MainActor.assumeIsolated { self?.choose(place) }
                done()
            }
            items.append(item)
        }
        let list = CPListTemplate(title: L("Ziele"), sections: [CPListSection(items: items)])
        interfaceController?.pushTemplate(list, animated: true, completion: nil)
    }

    @MainActor private func showSearch() {
        let template = CPSearchTemplate()
        template.delegate = self
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    @MainActor private func choose(_ place: PhotonClient.Place) {
        interfaceController?.popToRootTemplate(animated: true, completion: nil)
        model.choose(place)
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        searchTask?.cancel()
        let text = searchText
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            let client = PhotonClient(baseURL: AppConfig.photonURL, http: AppConfig.http)
            let found = (try? await client.search(text, near: self.model.currentCoordinate)) ?? []
            guard !Task.isCancelled else { return }
            completionHandler(found.map { place in
                let item = CPListItem(text: place.name, detailText: place.subtitle)
                item.userInfo = place
                return item
            })
        }
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        if let place = item.userInfo as? PhotonClient.Place {
            MainActor.assumeIsolated { choose(place) }
        }
        completionHandler()
    }

    // MARK: CPMapTemplateDelegate

    func mapTemplate(_ mapTemplate: CPMapTemplate, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice) {
        if let i = routeChoice.userInfo as? Int { MainActor.assumeIsolated { model.selectedRoute = i } }
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        MainActor.assumeIsolated {
            if let i = routeChoice.userInfo as? Int { model.selectedRoute = i }
            self.trip = trip
            model.startNavigation()
        }
    }

    // GM-045: Verschieben – Pfeiltasten (Drehknopf) und Wischen (Touchscreen). Der Knopf „Mitte“ führt zurück zum Auto.

    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        MainActor.assumeIsolated { mapController?.pan(direction) }
    }

    func mapTemplateDidBeginPanGesture(_ mapTemplate: CPMapTemplate) {
        MainActor.assumeIsolated { mapController?.beginPan() }
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, didUpdatePanGestureWithTranslation translation: CGPoint, velocity: CGPoint) {
        MainActor.assumeIsolated { mapController?.drag(to: translation) }
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, didEndPanGestureWithVelocity velocity: CGPoint) {
        MainActor.assumeIsolated { mapController?.endDrag() }
    }

    func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate) {
        MainActor.assumeIsolated { mapController?.recenter() }
    }

    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        MainActor.assumeIsolated {
            navSession = nil
            if model.screen == .navigating { model.endNavigation() }
        }
    }
}

/// Kartenfenster im Auto: flach von oben wie ein Spiel-Radar (Prototyp GM-008), während der Fahrt mitdrehend.
/// Tempolimit-Schild und OSM-Hinweis liegen in unserem eigenen Fenster (erlaubt – es ist Teil der Karte).
final class CarMapViewController: UIViewController, MLNMapViewDelegate {
    private var mapView: MLNMapView?
    private var overlay: RouteOverlay?
    private let limitLabel = UILabel()
    private var revision = -1
    private var selected = -1
    private var navigating = false
    private var camera: FollowCamera?
    /// GM-045: Nutzer verschiebt die Karte – Kamera folgt dem Auto erst wieder nach „Mitte“ oder Bildschirmwechsel
    private var dragDone = CGPoint.zero
    private var lastScreen: AppModel.Screen?
    /// GM-043: Kartenstil im Auto (gleich wie auf dem iPhone, inkl. Stil-Test)
    private var shownStyle: MapStyle = .classic
    private var trailCount = 0
    private let trialLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = NeonColors.background
        shownStyle = AppModel.shared.activeStyle
        let map = NeonMap.make(frame: view.bounds, zoom: 15, style: shownStyle)
        map.isPitchEnabled = false
        map.compassView.isHidden = true // GM-024: kein Kompass im Auto (Norden steht ohnehin über die Fahrtrichtung fest)
        map.attributionButton.isHidden = true // Hinweis steht als Text unten rechts
        map.delegate = self
        if FollowCamera.locationAllowed { map.userTrackingMode = .follow } // GM-045: nie selbst nach dem Standort fragen
        view.addSubview(map)
        mapView = map
        let cam = FollowCamera(map: map, pitch: 0)
        cam.altitudeFactor = 1.0 // GM-030: vorher 1,6 – viel zu weit weg, keine Straßennamen
        cam.target = { AppModel.shared.cameraTarget }
        cam.glow = { AppModel.shared.screen == .navigating }
        cam.restoreAttribution = false
        cam.maxFPS = 30
        map.preferredFramesPerSecond = .lowPower // GM-028: 30 Bilder/s im Auto
        cam.restoreUserLocation = false // GM-027: im Auto nie den GPS-Punkt von MapLibre
        camera = cam
        cam.start()
        let ov = RouteOverlay(map: map)
        ov.theme = StyleTheme.of(shownStyle)
        overlay = ov

        // GM-043: kleine Test-Uhr oben rechts unter dem Hinweis („Test 4:12“), nur während eines Stil-Tests
        trialLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        trialLabel.textColor = .white
        trialLabel.textAlignment = .center
        trialLabel.backgroundColor = UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 32 / 255.0, alpha: 0.8)
        trialLabel.layer.cornerRadius = 11
        trialLabel.clipsToBounds = true
        trialLabel.isHidden = true
        trialLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trialLabel)
        NSLayoutConstraint.activate([
            trialLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            trialLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            trialLabel.heightAnchor.constraint(equalToConstant: 22),
            trialLabel.widthAnchor.constraint(equalToConstant: 92),
        ])

        let label = UILabel()
        label.text = "© OpenMapTiles\n" + L("© OpenStreetMap-Mitwirkende") // GM-027: zweizeilig, schmal genug für die Ecke
        label.numberOfLines = 2
        label.textAlignment = .right
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        limitLabel.font = .systemFont(ofSize: 20, weight: .heavy)
        limitLabel.textAlignment = .center
        limitLabel.textColor = .black
        limitLabel.backgroundColor = .white
        limitLabel.layer.cornerRadius = 24
        limitLabel.layer.borderColor = UIColor.systemRed.cgColor
        limitLabel.layer.borderWidth = 5
        limitLabel.clipsToBounds = true
        limitLabel.isHidden = true
        limitLabel.adjustsFontSizeToFitWidth = true
        limitLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(limitLabel)

        NSLayoutConstraint.activate([
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            // GM-027: oben rechts – unten links verdeckt die Ankunftsbox von iOS den Hinweis
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.centerXAnchor, constant: 40), // nie unter die iOS-Fenster links
            limitLabel.widthAnchor.constraint(equalToConstant: 48),
            limitLabel.heightAnchor.constraint(equalToConstant: 48),
            limitLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -72), // links neben den Kartenknöpfen
            limitLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        overlay?.styleLoaded(style)
    }

    /// GM-043: Stil, Leuchtspur und Test-Uhr (vom CarPlay-Delegate bei jeder Änderung aufgerufen)
    func update(style: MapStyle, trail: [Coordinate], trialRemaining: TimeInterval?) {
        if style != shownStyle {
            shownStyle = style
            overlay?.switchStyle(style)
        }
        if trail.count != trailCount {
            trailCount = trail.count
            overlay?.showTrail(trail)
        }
        if let r = trialRemaining {
            let s = Int(r.rounded(.up))
            trialLabel.text = String(format: L("Test %d:%02d"), s / 60, s % 60)
            trialLabel.isHidden = false
        } else {
            trialLabel.isHidden = true
        }
    }

    func show(routes: [Route], selected: Int, destination: Coordinate?, revision: Int, navigating: Bool, limit: Int?,
              follow: Coordinate? = nil, heading: Double = 0, speedKmh: Double = 50) {
        guard let map = mapView else { return }
        // GM-027: Kamera zuerst umschalten – sonst überschreibt sie den gerade eingepassten Vorschau-Ausschnitt
        let screen = AppModel.shared.screen
        if screen != lastScreen { lastScreen = screen; camera?.attach() } // GM-045: neuer Bildschirm → wieder dem Auto folgen
        if screen == .preview { camera?.stop() } else { camera?.start() }
        if revision != self.revision || selected != self.selected {
            let isNew = revision != self.revision
            self.revision = revision
            self.selected = selected
            overlay?.show(routes: routes, selected: selected, destination: destination)
            // Platz links für die Routen-Vorschau von CarPlay lassen
            if isNew && !navigating && !routes.isEmpty {
                // GM-027: Routen-Vorschau von iOS belegt links knapp die halbe Breite – Strecke rechts davon einpassen
                let safe = view.safeAreaInsets
                // Fenster ist nur ~400 pt breit: knapp rechts vom iOS-Fenster (endet bei ~55 %) bis vor die Kartenknöpfe
                let left: CGFloat = safe.left + view.bounds.width * 0.56 + 10
                overlay?.fit(routes: routes, padding: UIEdgeInsets(top: safe.top + 24, left: left, bottom: safe.bottom + 14, right: safe.right + 58))
            }
        }
        self.navigating = navigating
        // GM-025: CarPlay ist auch ohne Route der Hauptmodus – Karte flach von oben, Pfeil in der Mitte,
        // Kamera gleitet dem Auto nach. Nur die Routen-Vorschau zeigt die ganze Strecke (eingepasst).
        if let l = limit {
            limitLabel.text = String(l)
            limitLabel.isHidden = !navigating || l < 0 // GM-022: kein „∞“ – ohne Limit kein Schild im Auto
        } else {
            limitLabel.isHidden = true
        }
    }

    func zoom(by step: Double) {
        if camera?.isRunning == true { camera?.zoom(by: step); return }
        guard let map = mapView else { return }
        map.setZoomLevel(map.zoomLevel + step, animated: true)
    }

    func beginPan() {
        dragDone = .zero
        camera?.detach() // Pfeil bleibt auf dem Auto, die Karte bewegt sich
    }

    /// Ein Schritt per Pfeiltaste: ein Drittel des Bildschirms, bezogen auf die Bildschirmrichtung
    func pan(_ direction: CPMapTemplate.PanDirection) {
        if camera?.detached != true { beginPan() }
        let dx = view.bounds.width / 3, dy = view.bounds.height / 3
        var d = CGPoint.zero
        if direction.contains(.left) { d.x -= dx }
        if direction.contains(.right) { d.x += dx }
        if direction.contains(.up) { d.y -= dy }
        if direction.contains(.down) { d.y += dy }
        move(by: d, animated: true)
    }

    /// Wischen: CarPlay liefert die Gesamtverschiebung seit Beginn, wir bewegen nur um den neuen Teil
    func drag(to translation: CGPoint) {
        if camera?.detached != true { beginPan() }
        move(by: CGPoint(x: dragDone.x - translation.x, y: dragDone.y - translation.y), animated: false)
        dragDone = translation
    }

    func endDrag() { dragDone = .zero }

    private func move(by d: CGPoint, animated: Bool) {
        guard let map = mapView else { return }
        let c = map.convert(map.centerCoordinate, toPointTo: map)
        map.setCenter(map.convert(CGPoint(x: c.x + d.x, y: c.y + d.y), toCoordinateFrom: map), animated: animated)
    }

    func recenter() {
        camera?.attach()
        camera?.altitudeFactor = 1.0 // GM-030: gleiche Höhe wie beim Start
        camera?.start()
    }
}
