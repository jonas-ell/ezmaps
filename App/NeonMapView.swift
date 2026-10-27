import CoreLocation
import SwiftUI
import UIKit
import MapLibre
import EzMapsCore

/// Karte mit MapLibre Native. Stile: App/MapStyles/style-*.json (GM-043: alle 5, erzeugt von
/// tools/maplibre/build_style.py aus den Prototyp-Werten), Kacheln von OpenFreeMap.
enum MapStyleResource {
    static func url(for style: MapStyle) -> URL? {
        let name = (style.styleFileName as NSString).deletingPathExtension
        return Bundle.main.url(forResource: name, withExtension: "json")
    }

    /// Idstein – Startpunkt, solange kein Standort da ist
    static let idstein = CLLocationCoordinate2D(latitude: 50.2215, longitude: 8.268)
}

/// Farben aus dem Prototyp (tools/prototype/js/map.js, STYLES.neon) – change both.
enum NeonColors {
    static let route = UIColor(red: 0xa1 / 255.0, green: 0x3d / 255.0, blue: 0xf0 / 255.0, alpha: 1)
    static let routeEdge = UIColor(red: 0x4b / 255.0, green: 0x1a / 255.0, blue: 0x73 / 255.0, alpha: 1)
    static let alternative = UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 205 / 255.0, alpha: 0.55)
    static let destination = UIColor(red: 0xf5 / 255.0, green: 0xd7 / 255.0, blue: 0x42 / 255.0, alpha: 1)
    static let background = UIColor(red: 0x1c / 255.0, green: 0x1c / 255.0, blue: 0x1d / 255.0, alpha: 1)
}

/// Gemeinsamer Aufbau für iPhone und CarPlay
enum NeonMap {
    // GM-027: Startzoom 15 (vorher 13), damit der Spiel-Look sichtbar ist
    static func make(frame: CGRect = .zero, zoom: Double = 15, style: MapStyle = .classic) -> MLNMapView {
        let map = MLNMapView(frame: frame, styleURL: MapStyleResource.url(for: style))
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.backgroundColor = StyleTheme.of(style).background
        map.setCenter(MapStyleResource.idstein, zoomLevel: zoom, animated: false)
        map.showsUserLocation = FollowCamera.locationAllowed // GM-045: sonst fragt MapLibre beim Start selbst nach dem Standort
        map.showsUserHeadingIndicator = true // GM-048: Kompass-Richtung für den Standort-Pfeil (PlayerLocationView)
        map.logoView.isHidden = true
        // Den OSM-Hinweis zeigen wir immer selbst als Text (ODbL), das (i)-Symbol bleibt für Details
        map.attributionButtonPosition = .topRight
        map.attributionButton.isHidden = true // GM-027: ragte in die Suchleiste; der Hinweis steht als Text auf jedem Bildschirm
        return map
    }
}

/// Route, Alternativen und Ziel auf der Karte. Wird von iPhone und CarPlay benutzt.
/// GM-020: Ebenen werden erst nach dem Laden des Stils angelegt; bis dahin merkt sich der Zeichner die Daten.
final class RouteOverlay {
    private weak var map: MLNMapView?
    private var styleReady = false
    private var pending: (routes: [Route], selected: Int, destination: Coordinate?)?
    private var pendingMe: (Coordinate?, Double)?
    /// GM-043: zuletzt gezeigte Daten – nach einem Stilwechsel (neuer Stil = leere Karte) wieder zeichnen
    private var lastShown: (routes: [Route], selected: Int, destination: Coordinate?)?
    private var lastTrail: [Coordinate] = []
    /// GM-043: Routenfarben je Stil
    var theme = StyleTheme.of(.classic)

    init(map: MLNMapView) { self.map = map }

    /// GM-043: Stil wechseln – MapLibre lädt neu, `styleLoaded` legt die Ebenen wieder an
    func switchStyle(_ style: MapStyle) {
        guard let map = map, let url = MapStyleResource.url(for: style) else { return }
        theme = StyleTheme.of(style)
        styleReady = false
        if pending == nil { pending = lastShown }
        map.backgroundColor = theme.background
        map.styleURL = url
    }

    func styleLoaded(_ style: MLNStyle) {
        styleReady = true
        for (name, image) in RouteOverlay.poiImages() { style.setImage(image, forName: name) } // GM-026
        let empty = MLNShapeCollectionFeature(shapes: [])
        let alt = MLNShapeSource(identifier: "ez-alt", shape: empty, options: nil)
        let main = MLNShapeSource(identifier: "ez-route", shape: empty, options: nil)
        let dest = MLNShapeSource(identifier: "ez-dest", shape: empty, options: nil)
        style.addSource(alt)
        style.addSource(main)
        style.addSource(dest)

        // GM-043: frisch gefahrene Strecke – dünnes Leuchten hinter dem Auto (Stadt aufdecken, GM-041)
        let trail = MLNShapeSource(identifier: "ez-trail", shape: empty, options: nil)
        style.addSource(trail)
        let trailGlow = MLNLineStyleLayer(identifier: "ez-trail-glow", source: trail)
        trailGlow.lineColor = NSExpression(forConstantValue: UIColor(red: 0.77, green: 0.47, blue: 1, alpha: 0.35))
        trailGlow.lineWidth = NSExpression(forConstantValue: 12)
        trailGlow.lineBlur = NSExpression(forConstantValue: 6)
        trailGlow.lineCap = NSExpression(forConstantValue: "round")
        trailGlow.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(trailGlow)
        let trailLine = MLNLineStyleLayer(identifier: "ez-trail-line", source: trail)
        trailLine.lineColor = NSExpression(forConstantValue: UIColor(red: 0.85, green: 0.65, blue: 1, alpha: 0.9))
        trailLine.lineWidth = NSExpression(forConstantValue: 3)
        trailLine.lineCap = NSExpression(forConstantValue: "round")
        trailLine.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(trailLine)

        let altLayer = MLNLineStyleLayer(identifier: "ez-alt-line", source: alt)
        altLayer.lineColor = NSExpression(forConstantValue: theme.alternative)
        altLayer.lineWidth = NSExpression(forConstantValue: 5)
        altLayer.lineCap = NSExpression(forConstantValue: "round")
        altLayer.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(altLayer)

        let edge = MLNLineStyleLayer(identifier: "ez-route-edge", source: main)
        edge.lineColor = NSExpression(forConstantValue: theme.routeEdge)
        edge.lineWidth = NSExpression(forConstantValue: 9)
        edge.lineCap = NSExpression(forConstantValue: "round")
        edge.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(edge)

        let line = MLNLineStyleLayer(identifier: "ez-route-line", source: main)
        line.lineColor = NSExpression(forConstantValue: theme.route)
        line.lineWidth = NSExpression(forConstantValue: 6)
        line.lineCap = NSExpression(forConstantValue: "round")
        line.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(line)

        // GM-022: eigener Positionspfeil (weiß, schwarze Kontur – wie im Prototyp), dreht sich mit der Fahrtrichtung
        let me = MLNShapeSource(identifier: "ez-me", shape: MLNShapeCollectionFeature(shapes: []), options: nil)
        style.addSource(me)
        style.setImage(RouteOverlay.arrowImage(), forName: "ez-arrow")
        let arrow = MLNSymbolStyleLayer(identifier: "ez-me-arrow", source: me)
        arrow.iconImageName = NSExpression(forConstantValue: "ez-arrow")
        arrow.iconRotation = NSExpression(forKeyPath: "heading")
        arrow.iconRotationAlignment = NSExpression(forConstantValue: "map")
        arrow.iconPitchAlignment = NSExpression(forConstantValue: "viewport") // GM-023: steht aufrecht wie im Prototyp, nicht flach gedrückt
        arrow.iconScale = NSExpression(forConstantValue: 0.8)
        arrow.iconAllowsOverlap = NSExpression(forConstantValue: true)
        arrow.iconIgnoresPlacement = NSExpression(forConstantValue: true)

        let dot = MLNCircleStyleLayer(identifier: "ez-dest-dot", source: dest)
        dot.circleColor = NSExpression(forConstantValue: NeonColors.destination)
        dot.circleRadius = NSExpression(forConstantValue: 8)
        dot.circleStrokeColor = NSExpression(forConstantValue: UIColor.black)
        dot.circleStrokeWidth = NSExpression(forConstantValue: 2)
        style.addLayer(dot)
        style.addLayer(arrow)

        if let p = pendingMe { showPosition(p.0, heading: p.1) }
        if let p = pending ?? lastShown { show(routes: p.routes, selected: p.selected, destination: p.destination) }
        if !lastTrail.isEmpty { showTrail(lastTrail) }
    }

    /// GM-043: gefahrene Strecke als Leuchtlinie (leer = aus)
    func showTrail(_ coords: [Coordinate]) {
        lastTrail = coords
        guard styleReady, let style = map?.style else { return }
        var shapes: [MLNShape & MLNFeature] = []
        if coords.count > 1 {
            var c: [CLLocationCoordinate2D] = coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            shapes.append(MLNPolylineFeature(coordinates: &c, count: UInt(c.count)))
        }
        (style.source(withIdentifier: "ez-trail") as? MLNShapeSource)?.shape = MLNShapeCollectionFeature(shapes: shapes)
    }

    func show(routes: [Route], selected: Int, destination: Coordinate?) {
        lastShown = (routes, selected, destination)
        guard styleReady, let style = map?.style else {
            pending = (routes, selected, destination)
            return
        }
        pending = nil
        var alts: [MLNShape & MLNFeature] = []
        var main: [MLNShape & MLNFeature] = []
        for (i, r) in routes.enumerated() where r.shape.count > 1 {
            var coords: [CLLocationCoordinate2D] = r.shape.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let f = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
            if i == selected { main.append(f) } else { alts.append(f) }
        }
        (style.source(withIdentifier: "ez-alt") as? MLNShapeSource)?.shape = MLNShapeCollectionFeature(shapes: alts)
        (style.source(withIdentifier: "ez-route") as? MLNShapeSource)?.shape = MLNShapeCollectionFeature(shapes: main)
        var points: [MLNShape & MLNFeature] = []
        if let d = destination {
            let p = MLNPointFeature()
            p.coordinate = CLLocationCoordinate2D(latitude: d.latitude, longitude: d.longitude)
            points.append(p)
        }
        (style.source(withIdentifier: "ez-dest") as? MLNShapeSource)?.shape = MLNShapeCollectionFeature(shapes: points)
    }

    /// Positionspfeil setzen (nil = ausblenden)
    func showPosition(_ c: Coordinate?, heading: Double) {
        guard styleReady, let style = map?.style else {
            pendingMe = (c, heading)
            return
        }
        pendingMe = nil
        var shapes: [MLNShape & MLNFeature] = []
        if let c = c {
            let p = MLNPointFeature()
            p.coordinate = CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
            p.attributes = ["heading": heading]
            shapes.append(p)
        }
        (style.source(withIdentifier: "ez-me") as? MLNShapeSource)?.shape = MLNShapeCollectionFeature(shapes: shapes)
    }

    /// GM-022: Kamerahöhe nach Tempo – in der Stadt nah, auf der Autobahn weit (sonst nur Asphalt im Bild)
    static func altitude(forKmh kmh: Double) -> Double {
        let k: Double = min(130, max(30, kmh))
        return 320 + (k - 30) * 6 // GM-030: näher wie die Vorlage – 30 km/h → 320 m, 50 → 440 m, 130 → 920 m
    }

    /// Kamera hinter dem Auto: nah, geneigt, Fahrtrichtung oben
    static func follow(_ map: MLNMapView, at c: Coordinate, heading: Double, pitch: CGFloat, altitude: Double) {
        map.userTrackingMode = .none
        let center = CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
        let cam = MLNMapCamera(lookingAtCenter: center, altitude: altitude, pitch: pitch, heading: heading)
        map.setCamera(cam, withDuration: 0.5, animationTimingFunction: CAMediaTimingFunction(name: .linear))
    }

    /// GM-026: Kartensymbole wie in der Vorlage – weißes Symbol mit schwarzem Rand (Namen passen zu build_style.py POI)
    static func poiImages() -> [String: UIImage] {
        let white = UIColor(white: 0.96, alpha: 1)
        let pink = UIColor(red: 0xff / 255.0, green: 0x5f / 255.0, blue: 0xa2 / 255.0, alpha: 1)
        let green = UIColor(red: 0x5f / 255.0, green: 0xd0 / 255.0, blue: 0x68 / 255.0, alpha: 1)
        let symbols: [String: (String, UIColor)] = [
            "ez-poi-shop": ("basket.fill", white), "ez-poi-cross": ("cross.fill", white), "ez-poi-fuel": ("fuelpump.fill", white),
            "ez-poi-parking": ("parkingsign", white), "ez-poi-food": ("fork.knife", white), "ez-poi-charge": ("bolt.car.fill", white),
            // GM-045: Neon City – farbige Symbole wie auf der Übersichtskarte der Vorlage (eigene Zeichnung, SF Symbols)
            // GM-048: wie die Pausenkarten-Bilder meist weiß, nur Krankenhaus (rosa) und Laden-Säule (grün) farbig
            "ez-poi-shop-neon": ("basket.fill", white), "ez-poi-cross-neon": ("cross.fill", pink), "ez-poi-fuel-neon": ("fuelpump.fill", white),
            "ez-poi-parking-neon": ("parkingsign", white), "ez-poi-food-neon": ("fork.knife", white), "ez-poi-charge-neon": ("bolt.car.fill", green),
        ]
        var out: [String: UIImage] = [:]
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .heavy)
        for (name, (sym, color)) in symbols {
            guard let base = UIImage(systemName: sym, withConfiguration: cfg) else { continue }
            let size = CGSize(width: base.size.width + 10, height: base.size.height + 10)
            out[name] = UIGraphicsImageRenderer(size: size).image { _ in
                let black = base.withTintColor(.black, renderingMode: .alwaysOriginal)
                let white = base.withTintColor(color, renderingMode: .alwaysOriginal)
                for dx in stride(from: -3.0, through: 3.0, by: 1.5) {
                    for dy in stride(from: -3.0, through: 3.0, by: 1.5) where dx * dx + dy * dy <= 9 {
                        black.draw(at: CGPoint(x: 5 + dx, y: 5 + dy))
                    }
                }
                white.draw(at: CGPoint(x: 5, y: 5))
            }
        }
        return out
    }

    /// Pfeil als Bild (64 × 64 pt), exakt wie Assets/Generated/Player/player-neon.svg (Prototyp):
    /// Spitze (32,5), Flügel (56,56)/(8,56), Kerbe (32,45); Füllung #E9E9E9, Kontur 5 pt schwarz, weicher Schatten
    static func arrowImage() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 32, y: 5))
            p.addLine(to: CGPoint(x: 56, y: 56))
            p.addLine(to: CGPoint(x: 32, y: 45))
            p.addLine(to: CGPoint(x: 8, y: 56))
            p.close()
            p.lineJoinStyle = .round // UIBezierPath: lineJoinStyle (nicht lineJoin)
            p.lineWidth = 5
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.6).cgColor)
            UIColor.black.setStroke()
            p.stroke()
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor(red: 0xE9 / 255.0, green: 0xE9 / 255.0, blue: 0xE9 / 255.0, alpha: 1).setFill()
            p.fill()
        }
    }

    /// Ausschnitt so wählen, dass alle Routen zu sehen sind
    func fit(routes: [Route], padding: UIEdgeInsets) {
        guard let map = map else { return }
        let all: [Coordinate] = routes.flatMap { $0.shape }
        guard let first = all.first else { return }
        var sw = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
        var ne = sw
        for c in all {
            sw.latitude = min(sw.latitude, c.latitude)
            sw.longitude = min(sw.longitude, c.longitude)
            ne.latitude = max(ne.latitude, c.latitude)
            ne.longitude = max(ne.longitude, c.longitude)
        }
        map.userTrackingMode = .none
        map.setVisibleCoordinateBounds(MLNCoordinateBounds(sw: sw, ne: ne), edgePadding: padding, animated: true, completionHandler: nil)
    }
}

/// iPhone-Karte. Bekommt nur einfache Werte, damit SwiftUI Änderungen sicher erkennt.
struct NeonMapView: UIViewRepresentable {
    var routes: [Route]
    var selected: Int
    var destination: Coordinate?
    var revision: Int
    var navigating: Bool
    var recenterRequest: Int
    /// GM-022: Fahrposition (auf der Route) und Richtung – während der Navigation folgt die Kamera dem
    var follow: Coordinate? = nil
    var heading: Double = 0
    var speedKmh: Double = 50
    /// Platz, den Bedienelemente oben/unten belegen (für das Einpassen der Route)
    var padding: UIEdgeInsets
    /// GM-028: false, wenn die iPhone-Oberfläche nicht zu sehen ist (gesperrt, Hintergrund, nur CarPlay) – dann nicht zeichnen
    var visible: Bool = true
    /// GM-043: Kartenstil und gefahrene Strecke (Leuchtlinie)
    var style: MapStyle = .classic
    var trail: [Coordinate] = []
    /// GM-045: Standort erst zeigen, wenn erlaubt (Frage kommt im Onboarding, nicht beim Start)
    var locationAllowed: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = NeonMap.make(style: style)
        map.delegate = context.coordinator
        let overlay = RouteOverlay(map: map)
        overlay.theme = StyleTheme.of(style)
        context.coordinator.overlay = overlay
        context.coordinator.style = style
        if locationAllowed { map.userTrackingMode = .follow }
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let c = context.coordinator
        if c.style != style {
            c.style = style
            c.overlay?.switchStyle(style)
        }
        if c.trailCount != trail.count {
            c.trailCount = trail.count
            c.overlay?.showTrail(trail)
        }
        if c.revision != revision || c.selected != selected {
            let isNew = c.revision != revision
            c.revision = revision
            c.selected = selected
            c.overlay?.show(routes: routes, selected: selected, destination: destination)
            if isNew && !navigating && !routes.isEmpty { c.overlay?.fit(routes: routes, padding: padding) }
        }
        if c.navigating != navigating {
            c.navigating = navigating
            map.showsUserLocation = !navigating && locationAllowed // GM-022: in der Navigation zeigt unser Pfeil die Fahrposition
            if !navigating {
                let cam = map.camera
                cam.pitch = 0
                map.setCamera(cam, animated: true)
                if locationAllowed { map.userTrackingMode = .follow }
            }
        }
        // GM-025: Navigation – Kamera gleitet weich, fester Pfeil (unteres Drittel)
        if c.camera == nil {
            // GM-045: wie CarPlay und das Foto des Nutzers – flach von oben statt 55° schräg
            let cam = FollowCamera(map: map, pitch: 0)
            cam.arrowY = 0.62
            cam.target = { AppModel.shared.screen == .navigating ? AppModel.shared.cameraTarget : nil }
            cam.glow = { true }
            c.camera = cam
        }
        if c.allowed != locationAllowed {
            c.allowed = locationAllowed
            if locationAllowed && !navigating { map.showsUserLocation = true; map.userTrackingMode = .follow }
        }
        if navigating && visible { c.camera?.start() } else if c.camera?.isRunning == true { c.camera?.stop() }
        if map.isHidden == visible {
            map.isHidden = !visible
            map.preferredFramesPerSecond = visible ? .default : .lowPower
        }
        if c.recenter != recenterRequest {
            c.recenter = recenterRequest
            if !navigating { if locationAllowed { map.userTrackingMode = .follow } } else { c.camera?.attach() } // GM-045: Mitte → Pfeil wieder fest
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var overlay: RouteOverlay?
        var revision = -1
        var selected = -1
        var navigating = false
        var recenter = 0
        var camera: FollowCamera?
        var style: MapStyle = .classic
        var trailCount = 0
        var allowed = false

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            overlay?.styleLoaded(style)
        }

        /// GM-048: eigener Standort als heller Pfeil (Minikarte der Vorlage) statt lila Punkt
        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard annotation is MLNUserLocation else { return nil }
            return MainActor.assumeIsolated { PlayerLocationView() }
        }

        /// GM-045: Nutzer wischt/zoomt in der Navigation → Kamera hält an, Pfeil bleibt auf der Fahrposition (vorher wanderte er mit)
        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            let gestures: MLNCameraChangeReason = [.gesturePan, .gesturePinch, .gestureRotate, .gestureZoomIn, .gestureZoomOut, .gestureOneFingerZoom, .gestureTilt]
            guard !reason.intersection(gestures).isEmpty else { return }
            MainActor.assumeIsolated { if camera?.isRunning == true { camera?.detach() } }
        }
    }
}

/// Hinweis „© OpenStreetMap-Mitwirkende“ – auf jedem Kartenbildschirm sichtbar (rechtlich Pflicht)
struct OSMAttribution: View {
    var body: some View {
        Text(L("© OpenMapTiles · © OpenStreetMap-Mitwirkende")) // GM-020: OpenFreeMap verlangt beide Hinweise
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel(L("© OpenMapTiles · © OpenStreetMap-Mitwirkende"))
    }
}

/// GM-048: Standort ohne Fahrt/Navi wie die Minikarte eines Open-World-Spiels: schmaler heller Pfeil mit dunklem Rand,
/// zeigt in Fahrtrichtung (ab 1 m/s) bzw. Blickrichtung (Kompass). Eigene Form, nicht aus einem Spiel übernommen.
final class PlayerLocationView: MLNUserLocationAnnotationView {
    private let arrow = UIImageView(image: PlayerLocationView.image)
    private var lastHeading: Double = 0

    override func update() {
        if arrow.superview == nil {
            frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            arrow.frame = bounds
            addSubview(arrow)
        }
        if let l = userLocation?.location, l.course >= 0, l.speed > 1 {
            lastHeading = l.course
        } else if let h = userLocation?.heading?.trueHeading, h >= 0 {
            lastHeading = h
        }
        let rot: Double = (lastHeading - (mapView?.direction ?? 0)) * .pi / 180
        arrow.transform = CGAffineTransform(rotationAngle: CGFloat(rot))
    }

    static let image: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30)).image { ctx in
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 15, y: 3))
        p.addLine(to: CGPoint(x: 25, y: 26))
        p.addLine(to: CGPoint(x: 15, y: 20.5))
        p.addLine(to: CGPoint(x: 5, y: 26))
        p.close()
        p.lineJoinStyle = .round
        ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: UIColor.black.withAlphaComponent(0.6).cgColor)
        UIColor(white: 0.1, alpha: 1).setStroke()
        p.lineWidth = 3
        p.stroke()
        ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        UIColor(white: 0.95, alpha: 1).setFill()
        p.fill()
    }()
}
