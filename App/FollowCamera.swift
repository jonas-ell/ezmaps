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
    private let arrow = UIImageView(image: RouteOverlay.arrowImage())
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

    init(map: MLNMapView, pitch: CGFloat) {
        self.map = map
        self.pitch = pitch
        super.init()
        arrow.frame = CGRect(x: 0, y: 0, width: 52, height: 52)
        arrow.isHidden = true
        arrow.isUserInteractionEnabled = false
        map.addSubview(arrow)
    }

    var isRunning: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        hasState = false
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        map?.userTrackingMode = .none
        map?.showsUserLocation = false
        map?.automaticallyAdjustsContentInset = false
    }

    func stop() {
        link?.invalidate()
        link = nil
        arrow.isHidden = true
        map?.showsUserLocation = true
        map?.contentInset = .zero
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
            let kPos: Double = 1 - exp(-dt * 6)
            let kRot: Double = 1 - exp(-dt * 4)
            let kAlt: Double = 1 - exp(-dt * 1.5)
            lat += (t.coordinate.latitude - lat) * kPos
            lon += (t.coordinate.longitude - lon) * kPos
            var dh: Double = (t.heading - heading).truncatingRemainder(dividingBy: 360)
            if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
            heading = (heading + dh * kRot + 360).truncatingRemainder(dividingBy: 360)
            altitude += (goalAlt - altitude) * kAlt
        }
        // Mittelpunkt der Kamera = Pfeil-Position (Inset verschiebt ihn bei Bedarf nach unten)
        let h = map.bounds.height
        let shift: CGFloat = (arrowY - 0.5) * h * 2
        let inset = UIEdgeInsets(top: max(0, shift), left: 0, bottom: max(0, -shift), right: 0)
        if map.contentInset != inset { map.contentInset = inset }
        let cam = MLNMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                               altitude: altitude, pitch: pitch, heading: heading)
        map.setCamera(cam, animated: false)
        arrow.center = CGPoint(x: map.bounds.midX, y: h * arrowY)
        arrow.isHidden = false
        if arrow.superview === map { map.bringSubviewToFront(arrow) }
    }
}
