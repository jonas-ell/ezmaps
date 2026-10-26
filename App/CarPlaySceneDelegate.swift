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
        if meters >= 1000 { return Measurement(value: (meters / 100).rounded() / 10, unit: .kilometers) }
        let step: Double = meters >= 100 ? 50 : 10
        return Measurement(value: max(0, (meters / step).rounded() * step), unit: .meters)
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
        ]
        mapTemplate = template
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
        MainActor.assumeIsolated { observe() }
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
    }

    private func mapButton(_ symbol: String, action: @escaping () -> Void) -> CPMapButton {
        let b = CPMapButton { _ in action() }
        b.image = UIImage(systemName: symbol)
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
            updateGuidance()
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
    private var lastFollow: Coordinate?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = NeonColors.background
        let map = NeonMap.make(frame: view.bounds, zoom: 15)
        map.isPitchEnabled = false
        map.compassView.isHidden = true // GM-024: kein Kompass im Auto (Norden steht ohnehin über die Fahrtrichtung fest)
        map.attributionButton.isHidden = true // Hinweis steht als Text unten rechts
        map.delegate = self
        map.userTrackingMode = .follow
        view.addSubview(map)
        mapView = map
        overlay = RouteOverlay(map: map)

        let label = UILabel()
        label.text = L("© OpenMapTiles · © OpenStreetMap-Mitwirkende")
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
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            limitLabel.widthAnchor.constraint(equalToConstant: 48),
            limitLabel.heightAnchor.constraint(equalToConstant: 48),
            limitLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            limitLabel.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -8),
        ])
    }

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        overlay?.styleLoaded(style)
    }

    func show(routes: [Route], selected: Int, destination: Coordinate?, revision: Int, navigating: Bool, limit: Int?,
              follow: Coordinate? = nil, heading: Double = 0, speedKmh: Double = 50) {
        guard let map = mapView else { return }
        if revision != self.revision || selected != self.selected {
            let isNew = revision != self.revision
            self.revision = revision
            self.selected = selected
            overlay?.show(routes: routes, selected: selected, destination: destination)
            // Platz links für die Routen-Vorschau von CarPlay lassen
            if isNew && !navigating && !routes.isEmpty {
                let left: CGFloat = min(330, view.bounds.width * 0.42) + 30
                overlay?.fit(routes: routes, padding: UIEdgeInsets(top: 60, left: left, bottom: 30, right: 60))
            }
        }
        if navigating != self.navigating {
            self.navigating = navigating
            map.showsUserLocation = !navigating
            if !navigating { overlay?.showPosition(nil, heading: 0); map.userTrackingMode = .follow }
        }
        // GM-022: Kamera folgt der Fahrposition (auch bei der Demo-Fahrt), flach von oben wie ein Spiel-Radar
        if navigating, let f = follow, f != lastFollow {
            lastFollow = f
            overlay?.showPosition(f, heading: heading)
            RouteOverlay.follow(map, at: f, heading: heading, pitch: 0, altitude: RouteOverlay.altitude(forKmh: speedKmh) * 1.6)
        }
        if let l = limit {
            limitLabel.text = String(l)
            limitLabel.isHidden = !navigating || l < 0 // GM-022: kein „∞“ – ohne Limit kein Schild im Auto
        } else {
            limitLabel.isHidden = true
        }
    }

    func zoom(by step: Double) {
        guard let map = mapView else { return }
        map.setZoomLevel(map.zoomLevel + step, animated: true)
    }

    func recenter() {
        if navigating { lastFollow = nil } else { mapView?.userTrackingMode = .follow }
    }
}
