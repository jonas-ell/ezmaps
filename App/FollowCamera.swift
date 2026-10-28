import CoreLocation
import UIKit
import MapLibre
import EzMapsCore

/// GM-025: Kamera, die dem Auto 60-mal pro Sekunde weich nachgleitet.
/// Vorher sprang der Pfeil bei jeder neuen Position (Demo 2×/s, GPS 1×/s) – jetzt steht ein fester Pfeil
/// in der Bildmitte und die Karte bewegt sich darunter (wie in Navi-Apps und Spielen).
/// Ziel kommt über `target` (Position, Fahrtrichtung in Grad, km/h); nil = Kamera ruht.
@MainActor
final class FollowCamera: NSObject {
    struct Target {
        var coordinate: Coordinate
        var heading: Double
        var kmh: Double
    }

    private weak var map: MLNMapView?
    // GM-026: Pfeil von Codex (Assets/Generated/Player/NeonV2), mit lila Leuchten während der Navigation
    private var plainArrow = UIImage(named: "PlayerNeon") ?? RouteOverlay.arrowImage()
    private var glowArrow = UIImage(named: "PlayerNeonGlow") ?? RouteOverlay.arrowImage()
    private var markerStyle: MapStyle?

    /// GM-057: Standort-Marker je Stil (Zielbilder): Neon Codex-Pfeil, Pixel Quest Marker des Nutzers, Toy Town Spielzeugauto …
    func setStyle(_ style: MapStyle) {
        let key = style
        guard markerStyle != key || style == .pixelQuest else { return }
        markerStyle = key
        let m = PlayerMarker.images(for: style)
        plainArrow = m.plain
        glowArrow = m.glow
        arrow.image = plainArrow
        lastSet = nil
    }
    private lazy var arrow = UIImageView(image: plainArrow)
    var glow: (() -> Bool)?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var lat = 0.0, lon = 0.0, heading = 0.0, altitude = 600.0
    private var hasState = false

    var target: (() -> Target?)?
    var pitch: CGFloat
    /// Höhe = Tempo-Höhe × Faktor (Zoom-Knöpfe ändern den Faktor)
    var altitudeFactor: Double = 1
    /// Anteil der Höhe, auf der der Pfeil sitzt (0,5 = Mitte)
    var arrowY: CGFloat = 0.5
    /// Hinweis-Knopf (i) nach dem Anhalten wieder zeigen? (CarPlay: nein, dort steht der Hinweis als Text)
    var restoreAttribution = false
    var restoreUserLocation = true
    /// GM-028: höchste Bildrate (CarPlay 30 – Autoradios zeigen meist nicht mehr, halbiert die Arbeit)
    var maxFPS: Float = 60
    private var lastSet: (Double, Double, Double, Double, CGPoint)?
    /// GM-045: Nutzer schaut sich um (Wischen, CarPlay-Verschieben) – Karte bleibt, wo sie ist, Pfeil sitzt auf der Fahrposition
    private(set) var detached = false

    nonisolated static var locationAllowed: Bool {
        let s = CLLocationManager().authorizationStatus
        return s == .authorizedWhenInUse || s == .authorizedAlways
    }

    init(map: MLNMapView, pitch: CGFloat) {
        self.map = map
        self.pitch = pitch
        super.init()
        arrow.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        arrow.isHidden = true
        arrow.isUserInteractionEnabled = false
        map.addSubview(arrow)
    }

    var isRunning: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        hasState = false
        detached = false
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: min(15, maxFPS), maximum: maxFPS, preferred: maxFPS)
        lastSet = nil
        l.add(to: .main, forMode: .common)
        link = l
        map?.userTrackingMode = .none
        map?.showsUserLocation = false
        map?.automaticallyAdjustsContentInset = false
        map?.compassView.isHidden = true // GM-025: Kompass stört in der Fahrt
        map?.attributionButton.isHidden = true // Hinweis steht als Text darunter (GM-026)
    }

    func stop() {
        link?.invalidate()
        link = nil
        arrow.isHidden = true
        detached = false
        arrow.transform = .identity
        map?.showsUserLocation = restoreUserLocation && Self.locationAllowed
        map?.contentInset = .zero
        map?.compassView.isHidden = false
        map?.attributionButton.isHidden = !restoreAttribution
    }

    func detach() { detached = true }

    /// Zurück zum Auto: Kamera folgt wieder, Pfeil fest in der Mitte
    func attach() {
        detached = false
        lastSet = nil
        arrow.transform = .identity
    }

    func zoom(by step: Double) {
        altitudeFactor = min(4, max(0.35, altitudeFactor * (step > 0 ? 0.7 : 1.4)))
    }

    @objc private func tick(_ l: CADisplayLink) {
        guard let map = map, let t = target?() else { arrow.isHidden = true; return }
        let now = l.timestamp
        let dt: Double = last == 0 ? 1 / 60 : min(0.1, now - last)
        last = now
        let goalAlt: Double = RouteOverlay.altitude(forKmh: t.kmh) * altitudeFactor
        if !hasState {
            lat = t.coordinate.latitude; lon = t.coordinate.longitude; heading = t.heading; altitude = goalAlt
            hasState = true
        } else {
            // weich nachführen: Position schnell, Richtung etwas langsamer (kein Zittern in Kurven)
            // GM-050: Ziel wird in jedem Bild weitergerechnet (AppModel.cameraTarget) → enger folgen, kein Kurvenschneiden
            let kPos: Double = 1 - exp(-dt * 12)
            let kRot: Double = 1 - exp(-dt * 7)
            let kAlt: Double = 1 - exp(-dt * 1.5)
            lat += (t.coordinate.latitude - lat) * kPos
            lon += (t.coordinate.longitude - lon) * kPos
            var dh: Double = (t.heading - heading).truncatingRemainder(dividingBy: 360)
            if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
            heading = (heading + dh * kRot + 360).truncatingRemainder(dividingBy: 360)
            altitude += (goalAlt - altitude) * kAlt
        }
        if detached {
            // Pfeil auf die Fahrposition setzen, gedreht relativ zur Karte; außerhalb des Bildes ausblenden
            let p = map.convert(CLLocationCoordinate2D(latitude: lat, longitude: lon), toPointTo: map)
            arrow.center = p
            arrow.transform = CGAffineTransform(rotationAngle: CGFloat((heading - map.direction) * .pi / 180))
            arrow.isHidden = !map.bounds.insetBy(dx: -30, dy: -30).contains(p)
            return
        }
        // Mittelpunkt der Kamera = Pfeil-Position: Mitte der freien Fläche (Safe Area – in CarPlay ohne die
        // Abbiegekarte/Leisten von iOS), senkrecht bei arrowY. Inset nur ändern, wenn nötig.
        let safe = map.safeAreaInsets
        let free = map.bounds.inset(by: safe)
        let ay: CGFloat = free.minY + free.height * arrowY
        let ax: CGFloat = free.midX
        let inset = UIEdgeInsets(top: max(0, 2 * ay - map.bounds.height), left: max(0, 2 * ax - map.bounds.width),
                                 bottom: max(0, map.bounds.height - 2 * ay), right: max(0, map.bounds.width - 2 * ax))
        if map.contentInset != inset { map.contentInset = inset }
        // GM-028: im Stand nichts neu setzen – spart Rechenzeit (Kamera und Pfeil sind schon richtig)
        if let p = lastSet, abs(p.0 - lat) < 1e-7, abs(p.1 - lon) < 1e-7, abs(p.2 - heading) < 0.05, abs(p.3 - altitude) < 0.5, p.4 == CGPoint(x: ax, y: ay) {
            return
        }
        lastSet = (lat, lon, heading, altitude, CGPoint(x: ax, y: ay))
        let cam = MLNMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                               altitude: altitude, pitch: pitch, heading: heading)
        map.setCamera(cam, animated: false)
        arrow.center = CGPoint(x: ax, y: ay)
        let img = glow?() == true ? glowArrow : plainArrow
        if arrow.image !== img { arrow.image = img }
        arrow.isHidden = false
        if arrow.superview === map { map.bringSubviewToFront(arrow) }
        if map.showsUserLocation { map.showsUserLocation = false } // GM-027: kein zweiter (grauer) GPS-Punkt neben dem Pfeil
    }
}

/// GM-057: Standort-Marker je Stil (Zielbilder des Nutzers). Fahr-Pfeil (FollowCamera) und Stand-Marker (PlayerLocationView).
@MainActor
enum PlayerMarker {
    static func images(for style: MapStyle) -> (plain: UIImage, glow: UIImage) {
        switch style {
        case .neonCity:
            return (UIImage(named: "PlayerNeon") ?? RouteOverlay.arrowImage(), UIImage(named: "PlayerNeonGlow") ?? RouteOverlay.arrowImage())
        case .pixelQuest:
            let green = AppModel.shared.settings.pixelMarkerGreen
            let img = pixel(UIImage(named: green ? "px-player-green" : "px-player"))
            return (img, img)
        case .toyTown:
            let car = UIImage(named: "toy-car-red") ?? toyCar() // GM-066: Spielzeugauto von Codex
            return (car, car)
        case .wildWest:
            let a = UIImage(named: "west-player-arrow") ?? arrow(fill: StyleTheme.hex(0xf6ead6), rim: StyleTheme.hex(0x2b231b), size: 60) // GM-066: Codex
            return (a, a)
        case .classic:
            let a = classic()
            return (a, a)
        }
    }

    /// Marker der Nutzer-Grafik scharf (ohne Glätten) auf 60 pt
    static func pixel(_ img: UIImage?) -> UIImage {
        guard let img else { return RouteOverlay.arrowImage() }
        return UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            img.draw(in: CGRect(x: 12, y: 6, width: 36, height: 48))
        }
    }

    static func arrow(fill: UIColor, rim: UIColor, size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let k = size / 30
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 15 * k, y: 3 * k)); p.addLine(to: CGPoint(x: 25 * k, y: 26 * k))
            p.addLine(to: CGPoint(x: 15 * k, y: 20.5 * k)); p.addLine(to: CGPoint(x: 5 * k, y: 26 * k)); p.close()
            p.lineJoinStyle = .round
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1.5 * k), blur: 3 * k, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            fill.setFill(); p.fill()
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            rim.setStroke(); p.lineWidth = 2 * k; p.stroke()
        }
    }

    static func classic() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44)).image { ctx in
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            UIColor.white.setFill(); ctx.cgContext.fillEllipse(in: CGRect(x: 4, y: 4, width: 36, height: 36))
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 22, y: 11)); p.addLine(to: CGPoint(x: 31, y: 31)); p.addLine(to: CGPoint(x: 22, y: 26)); p.addLine(to: CGPoint(x: 13, y: 31)); p.close()
            StyleTheme.hex(0x1a73e8).setFill(); p.fill()
        }
    }

    /// Rotes Spielzeugauto von oben (Toy Town, Zielbild)
    static func toyCar() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 44, height: 60)).image { ctx in
            let g = ctx.cgContext
            let ink = StyleTheme.hex(0x2f3640)
            ink.setFill()
            for (x, y) in [(5.0, 12.0), (35.0, 12.0), (5.0, 36.0), (35.0, 36.0)] { UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 5, height: 11), cornerRadius: 1.5).fill() }
            g.setShadow(offset: CGSize(width: 0, height: 2), blur: 3, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            let body = UIBezierPath(roundedRect: CGRect(x: 9, y: 4, width: 26, height: 52), cornerRadius: 10)
            StyleTheme.hex(0xe23b2e).setFill(); body.fill()
            g.setShadow(offset: .zero, blur: 0, color: nil)
            ink.setStroke(); body.lineWidth = 2.5; body.stroke()
            StyleTheme.hex(0xa8dcff).setFill()
            for r in [CGRect(x: 13, y: 14, width: 18, height: 10), CGRect(x: 13, y: 38, width: 18, height: 8)] {
                let w = UIBezierPath(roundedRect: r, cornerRadius: 3); w.fill(); w.lineWidth = 1.5; w.stroke()
            }
        }
    }
}
