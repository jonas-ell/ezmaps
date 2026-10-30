import CoreLocation
import MapLibre
import SceneKit
import UIKit

/// GM-092: Pixel Quest – echte 3D-Villager-Häuser (Codex, Assets/Generated/PixelQuest/3d/*.scn) auf kleinen Gebäuden.
/// MapLibre kann keine Modelle zeichnen, deshalb liegt eine durchsichtige SceneKit-Ebene über der Karte: Jedes Haus steht
/// auf der Bildschirm-Position seines Gebäudes, gedreht nach der längsten Gebäudekante, geneigt wie die Karte.
/// Kleine Blöcke (unter 8 m) blendet der Stil ab Zoom 15 aus (build_style.py house_models). Ohne Modelle im Bundle bleibt die Ebene aus.
@MainActor
final class VillageLayer {
    static let minZoom = 15.0
    private static let maxHouses = 80
    private weak var map: MLNMapView?
    private let view = SCNView()
    private let scene = SCNScene()
    private let camNode = SCNNode()
    private var templates: [SCNNode] = []
    private struct House { let coord: CLLocationCoordinate2D; let angle: Double; let size: Double; let node: SCNNode }
    private var houses: [House] = []
    private let debug = UILabel() // GM-092: Zählanzeige nur in Test-Builds

    /// Modelle vorhanden (Test-Builds schicken sie mit, nicht im öffentlichen Repo)
    var available: Bool { !templates.isEmpty }
    var enabled = false {
        didSet { if enabled != oldValue { if !enabled { clear() }; view.isHidden = !enabled } }
    }

    init(map: MLNMapView) {
        self.map = map
        view.backgroundColor = .clear
        view.scene = scene
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.frame = map.bounds
        view.antialiasingMode = .multisampling2X
        view.isHidden = true
        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.zNear = 1
        cam.zFar = 20000
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0, 10000)
        scene.rootNode.addChildNode(camNode)
        view.pointOfView = camNode
        let amb = SCNNode(); amb.light = SCNLight(); amb.light?.type = .ambient; amb.light?.intensity = 650
        let sun = SCNNode(); sun.light = SCNLight(); sun.light?.type = .directional; sun.light?.intensity = 650
        sun.eulerAngles = SCNVector3(-0.9, 0.6, 0)
        scene.rootNode.addChildNode(amb)
        scene.rootNode.addChildNode(sun)
        for name in ["villager-house-oak", "villager-house-spruce", "villager-house-birch", "villager-house-sand"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "scn"), let s = try? SCNScene(url: url) else { continue }
            let t = SCNNode()
            for c in s.rootNode.childNodes { t.addChildNode(c.clone()) }
            templates.append(t)
        }
        map.addSubview(view) // über der Karte (Index 1 lag hinter der Zeichenfläche – Häuser unsichtbar)
        #if DEBUG || EZTEST
        debug.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        debug.textColor = .yellow
        debug.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        debug.frame = CGRect(x: 8, y: 120, width: 300, height: 14)
        view.addSubview(debug)
        #endif
    }

    private func clear() {
        for h in houses { h.node.removeFromParentNode() }
        houses = []
    }

    /// Häuser neu suchen (nach dem Verschieben oder wenn Kacheln geladen sind)
    func refresh() {
        guard enabled, available, let map else { clear(); return }
        guard map.zoomLevel >= Self.minZoom else { clear(); debug.text = String(format: " Zoom %.1f – Häuser ab 15", map.zoomLevel); return }
        // GM-093: gezeichnete Gebäude der Probe-Ebene abfragen (Quell-Abfrage lieferte fast nichts)
        let feats = map.visibleFeatures(in: map.bounds, styleLayerIdentifiers: ["building-probe"])
        let area = map.bounds.insetBy(dx: -40, dy: -40)
        let center = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
        var seen = Set<Int64>()
        var found: [(CLLocationCoordinate2D, Double, Double, CGFloat, Int)] = []
        // GM-093: Die Kacheln fassen gleich hohe Nachbarhäuser zu einem Objekt zusammen – jedes Teil einzeln nehmen
        var polys: [MLNPolygon] = []
        for f in feats {
            if let m = f as? MLNMultiPolygon { polys.append(contentsOf: m.polygons) } else if let p = f as? MLNPolygon { polys.append(p) }
        }
        for poly in polys {
            let n = Int(poly.pointCount)
            guard n >= 3 else { continue }
            let pts = UnsafeBufferPointer(start: poly.coordinates, count: n)
            var lat = 0.0, lon = 0.0
            for p in pts { lat += p.latitude; lon += p.longitude }
            let c = CLLocationCoordinate2D(latitude: lat / Double(n), longitude: lon / Double(n))
            let key = Int64((c.latitude * 1e5).rounded()) * 100_000_000 + Int64((c.longitude * 1e5).rounded())
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let sp = map.convert(c, toPointTo: map)
            guard area.contains(sp) else { continue }
            // längste Kante → Ausrichtung und Größe (Meter)
            let k = cos(c.latitude * .pi / 180) * 111_320.0
            var best = 0.0, angle = 0.0
            for i in 0..<(n - 1) {
                let dx = (pts[i + 1].longitude - pts[i].longitude) * k, dy = (pts[i + 1].latitude - pts[i].latitude) * 110_540.0
                let l = hypot(dx, dy)
                if l > best { best = l; angle = atan2(dx, dy) * 180 / .pi }
            }
            let variant = abs(Int(key % 4))
            found.append((c, angle, min(14, max(7, best * 0.9)), hypot(sp.x - center.x, sp.y - center.y), variant))
        }
        found.sort { $0.3 < $1.3 }
        debug.text = " Modelle \(templates.count) · Gebäude \(polys.count) · sichtbar \(found.count)"
        clear()
        for (c, angle, size, _, v) in found.prefix(Self.maxHouses) {
            let node = templates[v % templates.count].clone()
            scene.rootNode.addChildNode(node)
            houses.append(House(coord: c, angle: angle, size: size, node: node))
        }
        layout()
    }

    /// Häuser an die aktuelle Kamera anpassen (bei jeder Kartenbewegung)
    func layout() {
        guard enabled, let map else { return }
        if map.zoomLevel < Self.minZoom { if !houses.isEmpty { clear() }; return }
        view.frame = map.bounds
        let w = map.bounds.width, h = map.bounds.height
        camNode.camera?.orthographicScale = Double(h / 2)
        let pitch = Float(map.camera.pitch * .pi / 180)
        let dir = map.direction
        let area = map.bounds.insetBy(dx: -60, dy: -60)
        for house in houses {
            let p = map.convert(house.coord, toPointTo: map)
            house.node.isHidden = !area.contains(p)
            guard !house.node.isHidden else { continue }
            let east = CLLocationCoordinate2D(latitude: house.coord.latitude,
                                              longitude: house.coord.longitude + 10 / (cos(house.coord.latitude * .pi / 180) * 111_320))
            let e = map.convert(east, toPointTo: map)
            let ppm = Float(hypot(e.x - p.x, e.y - p.y) / 10)
            let s = ppm * Float(house.size)
            house.node.scale = SCNVector3(s, s, s)
            house.node.position = SCNVector3(Float(p.x - w / 2), Float(h / 2 - p.y), Float(p.y))
            // Modell Y-up: um 90° minus Kartenneigung kippen (flach von oben sieht man nur das Dach), um Y nach Gebäudekante drehen
            // GM-093: erst um die eigene Hochachse drehen, dann kippen (eulerAngles drehte in falscher Reihenfolge – Häuser kippten seitlich)
            let yaw = simd_quatf(angle: -Float((house.angle - dir) * .pi / 180), axis: SIMD3<Float>(0, 1, 0))
            let tilt = simd_quatf(angle: .pi / 2 - pitch, axis: SIMD3<Float>(1, 0, 0))
            house.node.simdOrientation = tilt * yaw
        }
    }
}
