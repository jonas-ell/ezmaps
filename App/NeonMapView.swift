import CoreLocation
import SwiftUI
import UIKit
import MapLibre
import EzMapsCore

/// Karte „Neon City“ mit MapLibre Native. Stil: App/MapStyles/style-neon-city.json
/// (erzeugt von tools/maplibre/build_style.py aus den Prototyp-Werten), Kacheln vorerst von OpenFreeMap.
/// Wild West, Pixel Quest und Toy Town folgen später.
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
    static func make(frame: CGRect = .zero, zoom: Double = 13) -> MLNMapView {
        let map = MLNMapView(frame: frame, styleURL: MapStyleResource.url(for: .neonCity))
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.backgroundColor = NeonColors.background
        map.setCenter(MapStyleResource.idstein, zoomLevel: zoom, animated: false)
        map.showsUserLocation = true
        map.logoView.isHidden = true
        // Den OSM-Hinweis zeigen wir immer selbst als Text (ODbL), das (i)-Symbol bleibt für Details
        map.attributionButtonPosition = .topRight
        return map
    }
}

/// Route, Alternativen und Ziel auf der Karte. Wird von iPhone und CarPlay benutzt.
/// GM-020: Ebenen werden erst nach dem Laden des Stils angelegt; bis dahin merkt sich der Zeichner die Daten.
final class RouteOverlay {
    private weak var map: MLNMapView?
    private var styleReady = false
    private var pending: (routes: [Route], selected: Int, destination: Coordinate?)?

    init(map: MLNMapView) { self.map = map }

    func styleLoaded(_ style: MLNStyle) {
        styleReady = true
        let empty = MLNShapeCollectionFeature(shapes: [])
        let alt = MLNShapeSource(identifier: "ez-alt", shape: empty, options: nil)
        let main = MLNShapeSource(identifier: "ez-route", shape: empty, options: nil)
        let dest = MLNShapeSource(identifier: "ez-dest", shape: empty, options: nil)
        style.addSource(alt)
        style.addSource(main)
        style.addSource(dest)

        let altLayer = MLNLineStyleLayer(identifier: "ez-alt-line", source: alt)
        altLayer.lineColor = NSExpression(forConstantValue: NeonColors.alternative)
        altLayer.lineWidth = NSExpression(forConstantValue: 5)
        altLayer.lineCap = NSExpression(forConstantValue: "round")
        altLayer.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(altLayer)

        let edge = MLNLineStyleLayer(identifier: "ez-route-edge", source: main)
        edge.lineColor = NSExpression(forConstantValue: NeonColors.routeEdge)
        edge.lineWidth = NSExpression(forConstantValue: 9)
        edge.lineCap = NSExpression(forConstantValue: "round")
        edge.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(edge)

        let line = MLNLineStyleLayer(identifier: "ez-route-line", source: main)
        line.lineColor = NSExpression(forConstantValue: NeonColors.route)
        line.lineWidth = NSExpression(forConstantValue: 6)
        line.lineCap = NSExpression(forConstantValue: "round")
        line.lineJoin = NSExpression(forConstantValue: "round")
        style.addLayer(line)

        let dot = MLNCircleStyleLayer(identifier: "ez-dest-dot", source: dest)
        dot.circleColor = NSExpression(forConstantValue: NeonColors.destination)
        dot.circleRadius = NSExpression(forConstantValue: 8)
        dot.circleStrokeColor = NSExpression(forConstantValue: UIColor.black)
        dot.circleStrokeWidth = NSExpression(forConstantValue: 2)
        style.addLayer(dot)

        if let p = pending { show(routes: p.routes, selected: p.selected, destination: p.destination) }
    }

    func show(routes: [Route], selected: Int, destination: Coordinate?) {
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
    /// Platz, den Bedienelemente oben/unten belegen (für das Einpassen der Route)
    var padding: UIEdgeInsets

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = NeonMap.make()
        map.delegate = context.coordinator
        context.coordinator.overlay = RouteOverlay(map: map)
        map.userTrackingMode = .follow
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let c = context.coordinator
        if c.revision != revision || c.selected != selected {
            let isNew = c.revision != revision
            c.revision = revision
            c.selected = selected
            c.overlay?.show(routes: routes, selected: selected, destination: destination)
            if isNew && !navigating && !routes.isEmpty { c.overlay?.fit(routes: routes, padding: padding) }
        }
        if c.navigating != navigating {
            c.navigating = navigating
            if navigating {
                map.userTrackingMode = .followWithCourse
                let cam = map.camera
                cam.pitch = 50
                map.setCamera(cam, animated: true)
            } else {
                let cam = map.camera
                cam.pitch = 0
                map.setCamera(cam, animated: true)
                map.userTrackingMode = .follow
            }
        }
        if c.recenter != recenterRequest {
            c.recenter = recenterRequest
            map.userTrackingMode = navigating ? .followWithCourse : .follow
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var overlay: RouteOverlay?
        var revision = -1
        var selected = -1
        var navigating = false
        var recenter = 0

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            overlay?.styleLoaded(style)
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
