import Foundation

/// Fahrt-Replay (GM-041): plant die Kamera für ein kurzes Video (Standard 10 s, 30 Bilder/s, GM-044: Querformat 16:9 wie der CarPlay-Bildschirm).
/// Ablauf: Kamera fliegt der Strecke nach (die Linie wächst mit, neue Straßen leuchten), am Ende zoomt sie
/// heraus, bis die ganze Strecke zu sehen ist. Die App zeichnet jedes Bild mit MapLibre und schreibt es mit
/// AVAssetWriter in eine Datei. Mirror in tools/prototype/js/replay.js – change both.
public struct ReplayFrame: Equatable, Sendable {
    public var center: Coordinate
    /// Grad, 0 = Norden
    public var heading: Double
    public var zoom: Double
    /// Kamera-Neigung in Grad
    public var pitch: Double
    /// Anteil der Strecke, der schon gezeichnet ist (0…1)
    public var progress: Double
}

public struct ReplayPlanner: Sendable {
    public var duration: TimeInterval = 10
    public var fps: Int = 30
    /// Bildgröße in Punkten (für das Einpassen am Ende)
    public var width: Double = 1920
    public var height: Double = 1080
    /// Anteil der Zeit für die Verfolgung, danach Herauszoomen
    public var followShare: Double = 0.72
    public var followZoom: Double = 16.2

    public init() {}

    public func frames(for track: [Coordinate]) -> [ReplayFrame] {
        guard track.count >= 2 else { return [] }
        var cum: [Double] = [0]
        for (a, b) in zip(track, track.dropFirst()) { cum.append(cum.last! + a.distance(to: b)) }
        let total = max(cum.last!, 1)
        let fit = fitZoom(track)
        let mid = boundsCenter(track)
        let count = max(2, Int(duration * Double(fps)))
        var out: [ReplayFrame] = []
        var lastHeading = bearing(track[0], point(at: min(total, 60), track, cum))
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            if t <= followShare {
                let p = ease(t / followShare)
                let d = p * total
                let here = point(at: d, track, cum)
                let ahead = point(at: min(total, d + 80), track, cum)
                let target = d + 1 < total ? bearing(here, ahead) : lastHeading
                lastHeading = smooth(lastHeading, target, 0.12)
                out.append(ReplayFrame(center: here, heading: lastHeading, zoom: followZoom, pitch: 55, progress: p))
            } else {
                let q = ease((t - followShare) / (1 - followShare))
                let end = track.last!
                let c = Coordinate(latitude: end.latitude + (mid.latitude - end.latitude) * q, longitude: end.longitude + (mid.longitude - end.longitude) * q)
                out.append(ReplayFrame(center: c, heading: lastHeading * (1 - q), zoom: followZoom + (fit - followZoom) * q, pitch: 55 * (1 - q), progress: 1))
            }
        }
        return out
    }

    /// Zoomstufe, bei der die ganze Strecke mit Rand ins Bild passt
    public func fitZoom(_ track: [Coordinate]) -> Double {
        let lats = track.map(\.latitude), lons = track.map(\.longitude)
        let c = boundsCenter(track)
        let h = Coordinate(latitude: lats.min()!, longitude: c.longitude).distance(to: Coordinate(latitude: lats.max()!, longitude: c.longitude))
        let w = Coordinate(latitude: c.latitude, longitude: lons.min()!).distance(to: Coordinate(latitude: c.latitude, longitude: lons.max()!))
        // Meter pro Punkt bei Zoom z (512er-Kacheln wie MapLibre): 78271.517 · cos(lat) / 2^z
        let need = max(w / (width * 0.8), h / (height * 0.7), 0.5)
        return min(followZoom, log2(78_271.517 * cos(c.latitude * .pi / 180) / need))
    }

    func boundsCenter(_ t: [Coordinate]) -> Coordinate {
        let lats = t.map(\.latitude), lons = t.map(\.longitude)
        return Coordinate(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
    }

    func point(at d: Double, _ t: [Coordinate], _ cum: [Double]) -> Coordinate {
        var i = 1
        while i < cum.count - 1 && cum[i] < d { i += 1 }
        let seg = max(cum[i] - cum[i - 1], 1e-9), f = min(1, max(0, (d - cum[i - 1]) / seg))
        let a = t[i - 1], b = t[i]
        return Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * f, longitude: a.longitude + (b.longitude - a.longitude) * f)
    }

    func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let p = Double.pi / 180, dLon = (b.longitude - a.longitude) * p
        let y = sin(dLon) * cos(b.latitude * p)
        let x = cos(a.latitude * p) * sin(b.latitude * p) - sin(a.latitude * p) * cos(b.latitude * p) * cos(dLon)
        return (atan2(y, x) / p + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Weich drehen, auf dem kurzen Weg (350° → 10° dreht 20°, nicht 340°)
    func smooth(_ from: Double, _ to: Double, _ k: Double) -> Double {
        var d = (to - from).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        return (from + d * k + 360).truncatingRemainder(dividingBy: 360)
    }

    func ease(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
}
