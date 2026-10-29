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
        // GM-050: direkt am letzten bekannten Standort starten – vorher flog die Kamera beim Öffnen von Idstein dorthin
        let known = FollowCamera.locationAllowed ? CLLocationManager().location?.coordinate : nil
        map.setCenter(known ?? MapStyleResource.idstein, zoomLevel: zoom, animated: false)
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
    /// GM-050: Stil für das Ziel-Symbol (jeder Stil hat ein eigenes)
    var mapStyle: MapStyle = .classic

    init(map: MLNMapView) { self.map = map }

    /// GM-043: Stil wechseln – MapLibre lädt neu, `styleLoaded` legt die Ebenen wieder an
    func switchStyle(_ style: MapStyle) {
        guard let map = map, let url = MapStyleResource.url(for: style) else { return }
        theme = StyleTheme.of(style)
        mapStyle = style
        styleReady = false
        if pending == nil { pending = lastShown }
        map.backgroundColor = theme.background
        map.styleURL = url
    }

    /// GM-059: Pixel-Quest-Wasser animiert – Bilder des GIFs nacheinander als Muster setzen (MapLibre kann keine GIFs)
    private var waterTimer: Timer?
    private var waterFrame = 0
    private static let waterFrames: [UIImage] = (0..<8).compactMap { UIImage(named: "px-tex-water-\($0)") }

    private func animateWater(_ on: Bool) {
        waterTimer?.invalidate()
        waterTimer = nil
        guard on, !Self.waterFrames.isEmpty else { return }
        waterTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.styleReady, let style = self.map?.style else { return }
                self.waterFrame = (self.waterFrame + 1) % Self.waterFrames.count
                style.setImage(Self.waterFrames[self.waterFrame], forName: "ez-pat-water-px")
            }
        }
    }

    /// GM-072: Symbole und Muster für jede Karte (auch Stil-Seite und Erkunden – dort fehlten sie, Karte ohne Texturen)
    static func registerImages(_ style: MLNStyle) {
        for (name, image) in RouteOverlay.poiImages() { style.setImage(image, forName: name) } // GM-026
        for (name, image) in StylePatterns.all() { style.setImage(image, forName: name) } // GM-050: Muster Pixel Quest / Toy Town
    }

    func styleLoaded(_ style: MLNStyle) {
        styleReady = true
        animateWater(mapStyle == .pixelQuest)
        RouteOverlay.registerImages(style)
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
        // GM-057: Neon City flach und breit wie der Waypoint-Pfad der Vorlage (kein dunkler Rand)
        edge.lineColor = NSExpression(forConstantValue: mapStyle == .neonCity ? theme.route : theme.routeEdge)
        edge.lineWidth = NSExpression(forConstantValue: mapStyle == .neonCity ? 11 : 9)
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

        // GM-050: eigenes Ziel-Symbol je Stil statt gelbem Punkt
        style.setImage(RouteOverlay.destinationImage(for: mapStyle), forName: "ez-dest-icon")
        let dot = MLNSymbolStyleLayer(identifier: "ez-dest-dot", source: dest)
        dot.iconImageName = NSExpression(forConstantValue: "ez-dest-icon")
        dot.iconAnchor = NSExpression(forConstantValue: RouteOverlay.destinationStandsUp(mapStyle) ? "bottom" : "center")
        dot.iconAllowsOverlap = NSExpression(forConstantValue: true)
        dot.iconIgnoresPlacement = NSExpression(forConstantValue: true)
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
        return 400 + (k - 30) * 6 // GM-063: in der Stadt etwas höher (Clip: nur 1–2 Blöcke sichtbar) – 30 km/h → 400 m, 50 → 520 m
    }

    /// Kamera hinter dem Auto: nah, geneigt, Fahrtrichtung oben
    static func follow(_ map: MLNMapView, at c: Coordinate, heading: Double, pitch: CGFloat, altitude: Double) {
        map.userTrackingMode = .none
        let center = CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
        let cam = MLNMapCamera(lookingAtCenter: center, altitude: altitude, pitch: pitch, heading: heading)
        map.setCamera(cam, withDuration: 0.5, animationTimingFunction: CAMediaTimingFunction(name: .linear))
    }

    /// GM-050: Pin und Fahnen stehen auf dem Ziel (Anker unten), Raute und X liegen mittig darauf
    /// GM-070: Pixel Quest in 3D (schräge Kamera, Blocktürme), alle anderen flach von oben
    static func pitch(for style: MapStyle) -> CGFloat { style == .pixelQuest ? 50 : 0 }

    static func destinationStandsUp(_ style: MapStyle) -> Bool { [.classic, .pixelQuest, .toyTown, .frontier].contains(style) }

    /// GM-050: Ziel-Symbol je Stil (eigene Formen): Klassik rote Stecknadel, Neon City leuchtende lila Raute,
    /// Wild West rotes Tinten-X im Kreis, Pixel Quest Pixel-Fahne, Toy Town karierte Spielzeug-Fahne. Mirror: tools/prototype/js/poi.js
    static func destinationImage(for style: MapStyle) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48)).image { ctx in
            let g = ctx.cgContext
            g.setLineJoin(.round)
            g.setLineCap(.round)
            switch style {
            case .classic:
                let pin = UIBezierPath()
                pin.move(to: CGPoint(x: 24, y: 46))
                pin.addCurve(to: CGPoint(x: 11, y: 18), controlPoint1: CGPoint(x: 18, y: 36), controlPoint2: CGPoint(x: 11, y: 28))
                pin.addArc(withCenter: CGPoint(x: 24, y: 18), radius: 13, startAngle: .pi, endAngle: 0, clockwise: true)
                pin.addCurve(to: CGPoint(x: 24, y: 46), controlPoint1: CGPoint(x: 37, y: 28), controlPoint2: CGPoint(x: 30, y: 36))
                g.setShadow(offset: CGSize(width: 0, height: 2), blur: 3, color: UIColor.black.withAlphaComponent(0.4).cgColor)
                StyleTheme.hex(0xe8453c).setFill(); pin.fill()
                g.setShadow(offset: .zero, blur: 0, color: nil)
                UIColor.white.setStroke(); pin.lineWidth = 2.5; pin.stroke()
                UIColor.white.setFill(); UIBezierPath(ovalIn: CGRect(x: 19, y: 13, width: 10, height: 10)).fill()
            case .neonCity:
                // GM-057: flacher lila Vierstern ohne Leuchten (Zielbild Neon City)
                let d = UIBezierPath()
                d.move(to: CGPoint(x: 24, y: 7))
                d.addCurve(to: CGPoint(x: 41, y: 24), controlPoint1: CGPoint(x: 28, y: 18), controlPoint2: CGPoint(x: 30, y: 20))
                d.addCurve(to: CGPoint(x: 24, y: 41), controlPoint1: CGPoint(x: 30, y: 28), controlPoint2: CGPoint(x: 28, y: 30))
                d.addCurve(to: CGPoint(x: 7, y: 24), controlPoint1: CGPoint(x: 20, y: 30), controlPoint2: CGPoint(x: 18, y: 28))
                d.addCurve(to: CGPoint(x: 24, y: 7), controlPoint1: CGPoint(x: 18, y: 20), controlPoint2: CGPoint(x: 20, y: 18))
                d.close()
                NeonColors.route.setFill(); d.fill()
                StyleTheme.hex(0x5a1d8c).setStroke(); d.lineWidth = 1.5; d.stroke()
            case .wildWest:
                if let x = UIImage(named: "west-x") { // GM-064: Codex
                    x.draw(in: CGRect(x: 4, y: 4, width: 40, height: 40))
                    return
                }
                // GM-057: nur rotes X wie auf der Papierkarte
                let x = UIBezierPath()
                x.move(to: CGPoint(x: 14, y: 14)); x.addLine(to: CGPoint(x: 34, y: 34))
                x.move(to: CGPoint(x: 34.5, y: 13.5)); x.addLine(to: CGPoint(x: 13.5, y: 34.5))
                StyleTheme.hex(0xc0261f).setStroke(); x.lineWidth = 6; x.stroke()
            case .pixelQuest:
                if let flag = UIImage(named: "px-flag") { // GM-057: rote Fahne des Nutzers
                    g.interpolationQuality = .none
                    flag.draw(in: CGRect(x: 4, y: 4, width: 40, height: 40))
                    return
                }
                func px(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: Int) { StyleTheme.hex(c).setFill(); g.fill(CGRect(x: 6 + x * 3, y: y * 3, width: w * 3, height: h * 3)) }
                px(2, 1, 2, 15, 0x1b1206); px(3, 1, 1, 14, 0x8a5a2b)           // Stange mit Rand
                px(4, 1, 9, 7, 0x1b1206); px(4, 2, 8, 5, 0xe8453c); px(5, 3, 3, 2, 0xffcc33)   // Fahne
                px(0, 15, 7, 1, 0x1b1206)                                       // Fuß
            case .frontier:
                if let f = UIImage(named: "fv2-destination") { // GM-068: Fahne, Fuß unten
                    f.draw(in: CGRect(x: 2, y: 2, width: 44, height: 44))
                    return
                }
                let x = UIBezierPath(ovalIn: CGRect(x: 14, y: 14, width: 20, height: 20))
                StyleTheme.hex(0xe0a047).setFill(); x.fill()
                StyleTheme.hex(0x303121).setStroke(); x.lineWidth = 3; x.stroke()
            case .toyTown:
                if let f = UIImage(named: "toy-flag") { // GM-065: Codex
                    f.draw(in: CGRect(x: 4, y: 4, width: 40, height: 40))
                    return
                }
                let pole = UIBezierPath(roundedRect: CGRect(x: 12, y: 8, width: 4, height: 38), cornerRadius: 2)
                StyleTheme.hex(0x2f3640).setFill(); pole.fill()
                let flag = CGRect(x: 16, y: 8, width: 24, height: 16)
                StyleTheme.hex(0xff7a00).setFill(); UIBezierPath(roundedRect: flag, cornerRadius: 3).fill()
                UIColor.white.setFill()
                for r in 0..<2 { for c in 0..<3 where (r + c) % 2 == 0 { g.fill(CGRect(x: 16 + c * 8, y: 8 + r * 8, width: 8, height: 8)) } }
                StyleTheme.hex(0x2f3640).setStroke(); let o = UIBezierPath(roundedRect: flag, cornerRadius: 3); o.lineWidth = 2.5; o.stroke()
                UIBezierPath(ovalIn: CGRect(x: 10, y: 3, width: 8, height: 8)).fill()
            }
        }
    }

    /// GM-057: Kartensymbol-Arten (Name `ez-poi-<art><stil>`, passend zu build_style.py POI) mit SF Symbol und Neon-Farbe.
    /// check_style.py liest diese Liste und poiSuffixes – beide hier als einfache Literale lassen.
    static let poiKinds: [String: (String, UIColor)] = [
        "shop": ("basket.fill", .white), "cross": ("cross.fill", StyleTheme.hex(0xff5fa2)), "fuel": ("fuelpump.fill", .white),
        "parking": ("parkingsign", .white), "food": ("fork.knife", .white), "fastfood": ("takeoutbag.and.cup.and.straw.fill", .white),
        "coffee": ("cup.and.saucer.fill", StyleTheme.hex(0x4fd4e8)), "charge": ("bolt.car.fill", StyleTheme.hex(0x5fd068)),
        "shirt": ("tshirt.fill", .white), "cash": ("banknote.fill", StyleTheme.hex(0xf2c94c)), "cinema": ("film.fill", .white),
        "barber": ("scissors", .white), "hotel": ("bed.double.fill", .white), "school": ("book.fill", .white),
        "church": ("bell.fill", .white), "playground": ("figure.play", .white)
    ]
    static let poiSuffixes = ["", "-neon", "-west", "-px", "-toy", "-fv2"]
    /// GM-068: Frontier-Zeichen (Assets Frontier/fv2-poi-<datei>) je Art
    static let frontierPoi = ["shop": "shop", "cross": "hospital", "fuel": "fuel", "parking": "parking", "food": "food", "fastfood": "food",
                              "coffee": "coffee", "charge": "charge", "shirt": "clothing", "cash": "bank", "cinema": "cinema", "barber": "barber",
                              "hotel": "hotel", "school": "school", "church": "church", "playground": "playground"]

    /// GM-026/057: Kartensymbole je Stil – Klassik/Neon weiße (Neon teils farbige) Silhouette mit schwarzem Rand,
    /// Wild West schwarzer Knopf, Pixel Quest Item-Grafiken des Nutzers (Assets PixelQuest/px-<art>), Toy Town bunte Knöpfe
    static func poiImages() -> [String: UIImage] {
        var out: [String: UIImage] = [:]
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .heavy)
        func outlined(_ sym: String, _ color: UIColor) -> UIImage? {
            guard let base = UIImage(systemName: sym, withConfiguration: cfg) else { return nil }
            let size = CGSize(width: base.size.width + 10, height: base.size.height + 10)
            return UIGraphicsImageRenderer(size: size).image { _ in
                let black = base.withTintColor(.black, renderingMode: .alwaysOriginal)
                let fill = base.withTintColor(color, renderingMode: .alwaysOriginal)
                for dx in stride(from: -3.0, through: 3.0, by: 1.5) {
                    for dy in stride(from: -3.0, through: 3.0, by: 1.5) where dx * dx + dy * dy <= 9 {
                        black.draw(at: CGPoint(x: 5 + dx, y: 5 + dy))
                    }
                }
                fill.draw(at: CGPoint(x: 5, y: 5))
            }
        }
        func westBadge(_ sym: String) -> UIImage? {
            guard let glyph = UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)) else { return nil }
            return UIGraphicsImageRenderer(size: CGSize(width: 36, height: 36)).image { _ in
                let ring = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 32, height: 32))
                StyleTheme.hex(0x2b231b).setFill()
                ring.fill()
                StyleTheme.hex(0xe9d5b6).setStroke()
                ring.lineWidth = 1.5
                ring.stroke()
                let g = glyph.withTintColor(UIColor(white: 0.97, alpha: 1), renderingMode: .alwaysOriginal)
                g.draw(at: CGPoint(x: 18 - g.size.width / 2, y: 18 - g.size.height / 2))
            }
        }
        for (kind, (sym, neon)) in poiKinds {
            out["ez-poi-" + kind] = outlined(sym, UIColor(white: 0.96, alpha: 1))
            out["ez-poi-" + kind + "-neon"] = outlined(sym, neon)
            out["ez-poi-" + kind + "-west"] = UIImage(named: "west-poi-" + kind) ?? westBadge(sym) // GM-062: Codex-Knöpfe, wo vorhanden
            out["ez-poi-" + kind + "-px"] = UIImage(named: "px-" + kind).map(StylePatterns.pixelIcon) ?? StylePatterns.pixelSign(kind)
            out["ez-poi-" + kind + "-toy"] = UIImage(named: "toy-poi-" + kind) ?? StylePatterns.toyBadge(kind, symbol: sym) // GM-065: Codex
            out["ez-poi-" + kind + "-fv2"] = frontierPoi[kind].flatMap { UIImage(named: "fv2-poi-" + $0) } ?? outlined(sym, StyleTheme.hex(0xf4e7c2))
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
        // GM-051: Standort-Ansicht neu anlegen lassen – make() hat sie vor dem Delegate erzeugt (lila Standard-Punkt
        // statt PlayerLocationView, auf allen Screenshots zu sehen)
        if map.showsUserLocation { map.showsUserLocation = false; map.showsUserLocation = true }
        let overlay = RouteOverlay(map: map)
        overlay.theme = StyleTheme.of(style)
        overlay.mapStyle = style
        context.coordinator.overlay = overlay
        context.coordinator.style = style
        if locationAllowed { map.setUserTrackingMode(.follow, animated: false, completionHandler: nil) }
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let c = context.coordinator
        if c.style != style {
            c.style = style
            c.overlay?.switchStyle(style)
            c.crosshair?.isHidden = true
            if !navigating { // GM-070: Neigung je Stil auch ohne Navigation
                let cam = map.camera
                cam.pitch = RouteOverlay.pitch(for: style)
                map.setCamera(cam, animated: true)
            }
        }
        c.camera?.setStyle(style) // GM-057: Fahr-Pfeil je Stil
        SkyOverlay.update(on: map, style: style) // GM-072
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
                cam.pitch = RouteOverlay.pitch(for: style) // GM-070: vorher immer 0
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
            cam.setStyle(style)
        }
        if c.allowed != locationAllowed {
            c.allowed = locationAllowed
            if locationAllowed && !navigating { map.showsUserLocation = true; map.userTrackingMode = .follow }
        }
        if navigating { c.crosshair?.isHidden = true } // GM-058
        if navigating && visible { c.camera?.start() } else if c.camera?.isRunning == true { c.camera?.stop() }
        if map.isHidden == visible {
            map.isHidden = !visible
            map.preferredFramesPerSecond = visible ? .default : .lowPower
        }
        if c.recenter != recenterRequest {
            c.recenter = recenterRequest
            if !navigating { if locationAllowed { map.userTrackingMode = .follow } } else { c.camera?.attach() } // GM-045: Mitte → Pfeil wieder fest
            c.crosshair?.isHidden = true
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
        var crosshair: CrosshairView?

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
            MainActor.assumeIsolated {
                if camera?.isRunning == true { camera?.detach() }
                // GM-049/050: Fadenkreuz (Neon City weiß, Wild West rot), solange man sich umschaut
                if !navigating, let color = CrosshairView.color(for: style) { // GM-058: in der Navigation kein Fadenkreuz
                    if crosshair == nil {
                        let v = CrosshairView(frame: mapView.bounds)
                        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        mapView.addSubview(v)
                        crosshair = v
                    }
                    crosshair?.color = color
                    crosshair?.fade = style != .wildWest
                    crosshair?.isHidden = false
                }
            }
        }

        func mapView(_ mapView: MLNMapView, didChange mode: MLNUserTrackingMode, animated: Bool) {
            guard mode != .none else { return }
            MainActor.assumeIsolated { crosshair?.isHidden = true }
        }
    }
}

/// GM-049/050: Fadenkreuz beim Umschauen wie auf der Pausenkarte (Nutzer-Bild): vier kurze Arme mit Lücke in der Mitte,
/// nach außen ausgeblendet – nicht über den ganzen Bildschirm. Neon City weiß, Wild West dunkelrot.
final class CrosshairView: UIView {
    var color: UIColor = .white { didSet { setNeedsDisplay() } }
    /// GM-057: Neon City blendet aus, Wild West durchgehende Striche
    var fade = true { didSet { setNeedsDisplay() } }

    static func color(for style: MapStyle) -> UIColor? {
        switch style {
        case .neonCity: return UIColor(white: 1, alpha: 0.9)
        case .wildWest: return UIColor(red: 0x9b / 255.0, green: 0x16 / 255.0, blue: 0x12 / 255.0, alpha: 0.9)
        case .frontier: return UIColor(red: 0xf4 / 255.0, green: 0xe7 / 255.0, blue: 0xc2 / 255.0, alpha: 0.9) // GM-068: offenes cremefarbenes Kreuz
        default: return nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("nicht benutzt") }

    override func draw(_ rect: CGRect) {
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let gap: CGFloat = fade ? 9 : 12, arm: CGFloat = fade ? min(110, bounds.width * 0.26) : 60, steps = 14
        for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
            for i in 0..<steps {
                let a0 = gap + arm * CGFloat(i) / CGFloat(steps), a1 = gap + arm * CGFloat(i + 1) / CGFloat(steps)
                let p = UIBezierPath()
                p.move(to: CGPoint(x: c.x + dx * a0, y: c.y + dy * a0))
                p.addLine(to: CGPoint(x: c.x + dx * a1, y: c.y + dy * a1))
                p.lineWidth = fade ? 1.6 : 2
                color.withAlphaComponent(fade ? color.cgColor.alpha * (1 - CGFloat(i) / CGFloat(steps)) : color.cgColor.alpha).setStroke()
                p.stroke()
            }
        }
    }
}

/// GM-072: Himmel des Nutzers (px-sky) oben über der schrägen Pixel-Quest-Karte, weich in die Ferne übergeblendet
/// wie die Sichtweite im Blockspiel. Nicht bedienbar, liegt unter den Knöpfen.
final class SkyOverlay: UIImageView {
    private let fade = CAGradientLayer()

    static func update(on map: MLNMapView, style: MapStyle) {
        let existing = map.subviews.compactMap { $0 as? SkyOverlay }.first
        guard style == .pixelQuest, let img = UIImage(named: "px-sky") else { existing?.removeFromSuperview(); return }
        let v = existing ?? SkyOverlay(image: img)
        if existing == nil {
            v.contentMode = .scaleAspectFill
            v.clipsToBounds = true
            v.isUserInteractionEnabled = false
            v.layer.magnificationFilter = .nearest
            v.fade.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
            v.fade.locations = [0, 0.55, 1]
            v.layer.mask = v.fade
            map.insertSubview(v, at: map.subviews.count > 0 ? 1 : 0)
        }
        let h = map.bounds.height * 0.24
        v.frame = CGRect(x: 0, y: 0, width: map.bounds.width, height: h)
        v.fade.frame = v.bounds
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
    private var shownStyle: MapStyle?
    private var shownGreen = false

    override func update() {
        if arrow.superview == nil {
            frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            arrow.frame = bounds
            addSubview(arrow)
        }
        // GM-057: Marker je Stil (Neon heller Pfeil, Pixel Quest Marker des Nutzers, Toy Town Auto, Klassik blau …)
        let style = MainActor.assumeIsolated { AppModel.shared.activeStyle }
        let green = MainActor.assumeIsolated { AppModel.shared.settings.pixelMarkerGreen }
        if style != shownStyle || green != shownGreen {
            shownStyle = style
            shownGreen = green
            arrow.image = style == .neonCity ? PlayerLocationView.image : PlayerMarker.images(for: style).plain
            let size: CGFloat = style == .neonCity ? 30 : 46 // GM-065: vorher 34 – Marker kaum sichtbar
            frame.size = CGSize(width: size, height: size)
            arrow.frame = bounds
            arrow.contentMode = .scaleAspectFit
            arrow.layer.magnificationFilter = style == .pixelQuest ? .nearest : .linear
        }
        if let l = userLocation?.location, l.course >= 0, l.speed > 1 {
            lastHeading = l.course
        } else if let h = userLocation?.heading?.trueHeading, h >= 0 {
            lastHeading = h
        }
        let rot: Double = style == .pixelQuest ? 0 : (lastHeading - (mapView?.direction ?? 0)) * .pi / 180 // GM-072: Pixel-Marker steht aufrecht
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
        // GM-051: erst Fläche mit Schatten, dann der dunkle Rand obendrauf – vorher verdeckte die Fläche den Rand (auf hellen Karten unsichtbar)
        ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: UIColor.black.withAlphaComponent(0.6).cgColor)
        UIColor(white: 0.95, alpha: 1).setFill()
        p.fill()
        ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        UIColor(white: 0.1, alpha: 1).setStroke()
        p.lineWidth = 2
        p.stroke()
    }
}

/// GM-050: Muster und Symbole, die Pixel Quest und Toy Town eigenständig machen (wie der Prototyp js/map.js drawPixel/drawToy).
/// Namen passen zu tools/maplibre/build_style.py (pat, building_pattern, poi_suffix). Mirror: tools/prototype/js/poi.js – change both.
enum StylePatterns {
    /// gleichmäßiger Zufall 0…1 je Zelle (wie hash() im Prototyp), damit die Muster immer gleich aussehen
    static func hash(_ x: Int, _ y: Int, _ seed: Int = 0) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263 &+ seed &* 2147483647)
        h = (h ^ (h >> 13)) &* 1274126177
        return Double((h ^ (h >> 16)) & 0xffff) / 65535
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UIColor { UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1) }

    /// GM-072: Bild hart (ohne Glätten) vergrößern
    static func scaled(_ img: UIImage, _ f: CGFloat) -> UIImage {
        let size = CGSize(width: img.size.width * f, height: img.size.height * f)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = img.scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// GM-072: Bild n × n mal nebeneinander (gleiche Pixelgröße)
    static func tiled(_ img: UIImage, _ n: Int) -> UIImage {
        let size = CGSize(width: img.size.width * CGFloat(n), height: img.size.height * CGFloat(n))
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = img.scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            for y in 0..<n { for x in 0..<n { img.draw(in: CGRect(x: CGFloat(x) * img.size.width, y: CGFloat(y) * img.size.height, width: img.size.width, height: img.size.height)) } }
        }
    }

    /// Kachel aus Kunstpixeln (je 2 pt), harte Kanten
    static func pixelTile(_ cells: Int, _ color: (Int, Int) -> UIColor) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: cells * 2, height: cells * 2), format: f).image { ctx in
            for y in 0..<cells { for x in 0..<cells { color(x, y).setFill(); ctx.fill(CGRect(x: x * 2, y: y * 2, width: 2, height: 2)) } }
        }
    }

    static func toyTree(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        ctx.setFillColor(UIColor(red: 30 / 255, green: 70 / 255, blue: 20 / 255, alpha: 0.35).cgColor)
        ctx.fillEllipse(in: CGRect(x: x + r * 0.35 - r, y: y + r * 0.45 - r * 0.75, width: r * 2, height: r * 1.5))
        ctx.setFillColor(rgb(63, 155, 45).cgColor)
        ctx.setStrokeColor(rgb(42, 107, 31).cgColor)
        ctx.setLineWidth(1)
        let c = CGRect(x: x - r, y: y - r * 0.4 - r, width: r * 2, height: r * 2)
        ctx.fillEllipse(in: c); ctx.strokeEllipse(in: c)
        ctx.setFillColor(rgb(108, 192, 74).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - r * 0.3 - r * 0.42, y: y - r * 0.75 - r * 0.42, width: r * 0.84, height: r * 0.84))
    }

    static func all() -> [String: UIImage] {
        var out: [String: UIImage] = [:]
        // Pixel Quest – Blockwelt (16 × 16 Kunstpixel je Block); GM-057: Gras, Bruchstein, Wasser, Schiene = Grafiken des Nutzers
        out["ez-pat-grass-px-own"] = pixelTile(16) { x, y in
            let h = hash(x, y, 1)
            return h < 0.18 ? rgb(79, 138, 46) : h < 0.42 ? rgb(106, 173, 63) : h > 0.93 ? rgb(121, 189, 74) : rgb(93, 155, 55)
        }
        out["ez-pat-leaves-px"] = pixelTile(16) { x, y in
            let h = hash(x, y, 3)
            return h < 0.25 ? rgb(30, 74, 22) : h < 0.55 ? rgb(47, 107, 34) : h > 0.9 ? rgb(72, 140, 50) : rgb(38, 92, 28)
        }
        out["ez-pat-water-px-own"] = pixelTile(16) { x, y in
            let h = hash(x, y, 4)
            return (y % 5 == 1 && (x + y) % 7 < 3) ? rgb(110, 160, 245) : h < 0.3 ? rgb(56, 104, 214) : rgb(63, 118, 228)
        }
        out["ez-pat-farm-px"] = pixelTile(16) { x, y in
            y % 4 == 3 ? rgb(110, 72, 40) : hash(x, y, 5) < 0.3 ? rgb(214, 190, 80) : rgb(181, 154, 69)
        }
        out["ez-pat-stone-px"] = pixelTile(16) { x, y in
            let h = hash(x, y, 6)
            return h < 0.2 ? rgb(110, 110, 110) : h > 0.85 ? rgb(160, 160, 160) : rgb(138, 138, 138)
        }
        out["ez-pat-road-px-own"] = pixelTile(8) { x, y in
            let h = hash(x, y, 7)
            return h < 0.25 ? rgb(118, 118, 118) : h > 0.85 ? rgb(170, 170, 170) : rgb(143, 143, 143)
        }
        out["ez-pat-oak-px"] = pixelTile(16) { x, y in      // Holzbretter; GM-060: Blockkante rechts/unten
            if x == 15 || y == 15 { return rgb(70, 50, 26) }
            if y % 4 == 3 { return rgb(84, 62, 34) }
            if (x + (y / 4) * 5) % 8 == 0 { return rgb(98, 72, 40) }
            return hash(x, y, 8) < 0.25 ? rgb(150, 116, 66) : rgb(139, 106, 62)
        }
        out["ez-pat-spruce-px"] = pixelTile(16) { x, y in   // dunkles Holz
            if x == 15 || y == 15 { return rgb(40, 27, 14) }
            if y % 4 == 3 { return rgb(52, 36, 20) }
            return hash(x, y, 9) < 0.25 ? rgb(104, 76, 46) : rgb(92, 66, 38)
        }
        out["ez-pat-cobble-px"] = pixelTile(16) { x, y in   // Bruchstein
            let edge = (x + (y / 4) % 2 * 2) % 4 == 0 || y % 4 == 0
            return edge ? rgb(80, 80, 80) : hash(x, y, 10) < 0.3 ? rgb(150, 150, 150) : rgb(124, 124, 124)
        }
        out["ez-pat-brick-px"] = pixelTile(16) { x, y in    // Ziegel
            let mortar = y % 4 == 3 || (x + (y / 4) % 2 * 4) % 8 == 7
            return mortar ? rgb(196, 180, 170) : hash(x, y, 11) < 0.3 ? rgb(160, 70, 52) : rgb(146, 60, 44)
        }
        out["ez-pat-grass-px"] = UIImage(named: "px-tex-grass") ?? out["ez-pat-grass-px-own"]
        out["ez-pat-road-px"] = UIImage(named: "px-tex-cobble") ?? out["ez-pat-road-px-own"]
        out["ez-pat-water-px"] = UIImage(named: "px-tex-water") ?? out["ez-pat-water-px-own"]
        out["ez-pat-rail-px"] = UIImage(named: "px-tex-rail") ?? out["ez-pat-road-px-own"]
        if let wheat = UIImage(named: "px-tex-wheat") { out["ez-pat-farm-px"] = wheat } // GM-058: Weizenfeld
        // GM-059: Wild West – feine Papierfasern und Wald als Tinten-Baumtupfen (bis Codex-Grafiken da sind)
        out["ez-pat-paper-west"] = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { ctx in
            StyleTheme.hex(0xe4c9a8).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
            for i in 0..<70 {
                let x = hash(i, 1, 40) * 128, y = hash(i, 2, 40) * 128, l = 3 + hash(i, 3, 40) * 7
                UIColor(red: 0.55, green: 0.42, blue: 0.3, alpha: 0.08 + hash(i, 4, 40) * 0.08).setStroke()
                let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + l, y: y + l * 0.3)); p.lineWidth = 0.6; p.stroke()
            }
        }
        // GM-063: kleine, unregelmäßige Tinten-Baumtupfen (vorher große Dreiecke im Raster)
        out["ez-pat-forest-west"] = UIGraphicsImageRenderer(size: CGSize(width: 72, height: 72)).image { ctx in
            StyleTheme.hex(0xdcc29e).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 72, height: 72))
            for k in 0..<7 {
                let x = 6 + hash(k, 1, 77) * 60, y = 8 + hash(k, 2, 77) * 58, r = 2.2 + hash(k, 3, 77) * 1.6
                let t = UIBezierPath(arcCenter: CGPoint(x: x, y: y), radius: r, startAngle: .pi, endAngle: 0, clockwise: true)
                t.addLine(to: CGPoint(x: x - r, y: y))
                StyleTheme.hex(0xbfa57c).setFill(); t.fill()
                StyleTheme.hex(0x5a4733).setStroke(); t.lineWidth = 0.7; t.stroke()
            }
        }
        // GM-064: Codex-Grafiken (Assets/Generated/WildWest) haben Vorrang vor den gezeichneten Mustern
        if let p = UIImage(named: "west-tex-paper") { out["ez-pat-paper-west"] = p }
        if let f = UIImage(named: "west-tex-forest") { out["ez-pat-forest-west"] = f }
        out["ez-pat-water-west"] = UIImage(named: "west-tex-water") ?? pixelTile(2) { _, _ in rgb(170, 163, 146) }
        // GM-065: Toy Town – Codex-Kacheln und Haus-Symbole ("toy-house-1" … in Assets ToyTown)
        for name in ["toy-house-1", "toy-house-2", "toy-house-3", "toy-house-4", "toy-house-5", "toy-house-6", "toy-shop", "toy-school", "toy-police", "toy-apartment",
                     "px-sky", // GM-072
                     "fv2-paper-grain", "fv2-forest-canopy", "fv2-grass-mottle", "fv2-rock-grain", "fv2-water-grain", // GM-068: Frontier-Körnung
                     "fv2-forest-paint", "fv2-meadow-paint", // GM-070: gemalte Kacheln
                     "toy-tex-weave", "toy-tree"] { // GM-071: Teppich-Flor; GM-073: Baum am Waldrand
            if let img = UIImage(named: name) { out[name] = img }
        }
        for k in 1...16 { if let img = UIImage(named: "px-house-\(k)") { out["px-house-\(k)"] = img } } // GM-072: 16 Villager-Varianten
        // GM-072: Straße aus 4 × 4 Bruchstein-Blöcken (line-pattern zieht das Bild auf Straßenbreite – vorher graue Streifen)
        if let c = out["ez-pat-road-px"] { out["ez-pat-road-px"] = tiled(c, 4) }
        // GM-072: Blöcke wachsen beim Heranzoomen (build_style zoom_patterns: 2×/4×/8× ab Zoom 16/17/18)
        for n in ["ez-pat-grass-px", "ez-pat-leaves-px", "ez-pat-farm-px", "ez-pat-stone-px"] {
            guard let img = out[n] else { continue }
            for f in [2, 4, 8] { out[n + "-\(f)"] = scaled(img, CGFloat(f)) }
        }
        // Toy Town (gezeichnet; Codex-Kacheln weiter unten haben Vorrang)
        out["ez-pat-lawn-toy"] = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
            rgb(141, 198, 63).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            rgb(163, 214, 90).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 6, y: 10, width: 22, height: 13))
            ctx.cgContext.fillEllipse(in: CGRect(x: 38, y: 40, width: 18, height: 11))
        }
        out["ez-pat-trees-toy"] = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            rgb(98, 178, 53).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            toyTree(ctx.cgContext, 9, 11, 6); toyTree(ctx.cgContext, 25, 27, 5.5)
        }
        out["ez-pat-park-toy"] = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48)).image { ctx in
            rgb(124, 193, 66).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 48, height: 48))
            toyTree(ctx.cgContext, 16, 20, 6)
        }
        if let g = UIImage(named: "toy-tex-grass") { out["ez-pat-lawn-toy"] = g }
        if let f = UIImage(named: "toy-tex-forest") { out["ez-pat-trees-toy"] = f }
        if let p = UIImage(named: "toy-tex-park") { out["ez-pat-park-toy"] = p }
        out["ez-pat-water-toy"] = UIImage(named: "toy-tex-water") ?? pixelTile(2) { _, _ in rgb(74, 168, 232) }
        return out
    }

    /// Pixel-Zeichen 7 × 7 für die Pixel-Quest-Schilder (# = weiß)
    static let pixelGlyphs: [String: [String]] = [
        "parking": ["#####..", "#....#.", "#....#.", "#####..", "#......", "#......", "#......"],
        "shop": ["#......", ".######", ".#....#", ".#....#", ".######", "..#..#.", "......."],
        "food": ["#.#.#.#", "#.#.#.#", "#####.#", "..#..##", "..#...#", "..#...#", "..#...#"],
        "cross": ["..###..", "..###..", "#######", "#######", "#######", "..###..", "..###.."],
        "fuel": ["####...", "#..#.#.", "#..#..#", "####..#", "####..#", "####.#.", "####..."],
        "charge": ["...##..", "..##...", ".##....", "######.", "...##..", "..##...", ".##...."],
    ]
    static let pixelColors: [String: UIColor] = ["parking": rgb(42, 91, 215), "shop": rgb(214, 140, 40), "food": rgb(200, 70, 50),
                                                 "cross": rgb(220, 40, 40), "fuel": rgb(90, 90, 96), "charge": rgb(50, 160, 70)]

    /// Pixel-Schild: farbiges Quadrat, weißer Rahmen, schwarze Kante, Pixel-Zeichen (wie das „P“ im Prototyp)
    static func pixelSign(_ kind: String) -> UIImage {
        if kind == "cross" {
            return pixelIcon(pixelSprite(["......kk........", ".....kbbk.......", "......kk........", ".....kwwk.......", ".....kwwk.......",
                                          "....kwwwwk......", "...kwrrrrwk.....", "..kwrrRrrrrk....", "..krrRRrrrrk....", "..krrrrrrrrk....",
                                          "..krrrrrrrrk....", "...krrrrrrk.....", "....kkkkkk......"].map { "  " + $0 },
                                         ["k": rgb(27, 27, 27), "b": rgb(138, 90, 43), "w": rgb(207, 232, 255), "r": rgb(212, 42, 58), "R": rgb(255, 138, 154)]))
        }
        if kind == "parking" {
            return pixelIcon(pixelSprite(["", ".kkkkkkkkkkkkk..", ".kwwwwwwwwwwwk..", ".kwwkkkkkwwwwk..", ".kwwkwwwwkwwwk..", ".kwwkwwwwkwwwk..",
                                          ".kwwkkkkkwwwwk..", ".kwwkwwwwwwwwk..", ".kwwkwwwwwwwwk..", ".kwwwwwwwwwwwk..", ".kkkkkkkkkkkkk..",
                                          "......kbk.......", "......kbk.......", "......kbk.......", ".....kkkkk......"],
                                         ["k": rgb(42, 28, 14), "w": rgb(184, 148, 92), "b": rgb(108, 84, 48)]))
        }
        let rows = pixelGlyphs[kind] ?? []
        let bg = pixelColors[kind] ?? .gray
        return pixelTile(13) { x, y in
            if x == 0 || y == 0 || x == 12 || y == 12 { return .black }
            if x == 1 || y == 1 || x == 11 || y == 11 { return .white }
            let gx = x - 3, gy = y - 3
            if gx >= 0, gy >= 0, gy < rows.count, gx < 7, Array(rows[gy])[gx] == "#" { return .white }
            return bg
        }
    }

    static let toyColors: [String: UIColor] = ["food": rgb(76, 175, 80), "parking": rgb(31, 111, 224), "shop": rgb(245, 184, 0),
                                               "cross": rgb(232, 69, 60), "fuel": rgb(255, 122, 0), "charge": rgb(43, 181, 160),
                                               "fastfood": rgb(229, 115, 32), "coffee": rgb(141, 92, 62), "shirt": rgb(156, 89, 209),
                                               "cash": rgb(46, 160, 67), "cinema": rgb(60, 60, 70), "barber": rgb(0, 150, 199),
                                               "hotel": rgb(63, 81, 181), "school": rgb(255, 160, 0), "church": rgb(121, 85, 72),
                                               "playground": rgb(233, 30, 99)]

    /// GM-057: Item-Grafik (Pixel Quest) mit hartem Schatten, 28 pt
    static func pixelIcon(_ item: UIImage) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            ctx.cgContext.setShadow(offset: CGSize(width: 1.5, height: 1.5), blur: 0, color: UIColor.black.withAlphaComponent(0.6).cgColor)
            item.draw(in: CGRect(x: 2, y: 2, width: 28, height: 28))
        }
    }

    /// GM-057: Heiltrank (Krankenhaus) und Holzschild mit P (Parken), selbst gepixelt – keine Nutzer-Grafik vorhanden
    static func pixelSprite(_ rows: [String], _ pal: [Character: UIColor]) -> UIImage {
        pixelTile(16) { x, y in
            guard y < rows.count, x < rows[y].count else { return .clear }
            return pal[Array(rows[y])[x]] ?? .clear
        }
    }

    /// Toy-Town-Knopf: farbiger Kreis, weißer Rand, weißes Zeichen
    static func toyBadge(_ kind: String, symbol: String) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { ctx in
            let c = CGRect(x: 3, y: 3, width: 34, height: 34)
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 2, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            (toyColors[kind] ?? .gray).setFill(); ctx.cgContext.fillEllipse(in: c)
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.white.setStroke(); ctx.cgContext.setLineWidth(2.5); ctx.cgContext.strokeEllipse(in: c)
            if let g = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .heavy))?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                g.draw(at: CGPoint(x: 20 - g.size.width / 2, y: 20 - g.size.height / 2))
            }
        }
    }
}
