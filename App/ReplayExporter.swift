import AVFoundation
import AVKit
import CoreLocation
import SwiftUI
import UIKit
import MapLibre
import EzMapsCore

/// GM-043: Fahrt-Replay als MP4 (GM-041/042, Vorlage docs/previews/replay-gm041.mp4).
/// Kamera aus `ReplayPlanner` (Core, getestet), Bilder mit `MLNMapSnapshotter` im gewählten Stil, darüber Strecke,
/// Titel, Ergebnis, „EzMaps“ und „© OpenStreetMap-Mitwirkende“. GM-044: Querformat wie CarPlay, 1920 × 1080, 10 s,
/// Tafeln links (wie die Abbiegekarte in CarPlay), Karte und Auto rechts davon.
@MainActor
enum ReplayExporter {
    static let size = CGSize(width: 960, height: 540)
    static let fps = 15

    static func export(trip: Journal.Trip, style: MapStyle, progress: @escaping (Double) -> Void) async throws -> URL {
        let track = trip.track
        var planner = ReplayPlanner()
        planner.fps = fps
        planner.width = Double(size.width) * 0.58 // Überblick nur in der Kartenfläche rechts der Tafeln
        planner.height = Double(size.height)
        let frames = planner.frames(for: track)
        guard !frames.isEmpty, let styleURL = MapStyleResource.url(for: style) else { throw ReplayError.noTrack }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EzMaps-Replay-\(Int(trip.date.timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let px = CGSize(width: size.width * 2, height: size.height * 2)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(px.width),
            AVVideoHeightKey: Int(px.height),
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(px.width),
            kCVPixelBufferHeightKey as String: Int(px.height),
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? ReplayError.writer }
        writer.startSession(atSourceTime: .zero)

        let theme = StyleTheme.of(style)
        var cum: [Double] = [0]
        for (a, b) in zip(track, track.dropFirst()) { cum.append(cum[cum.count - 1] + a.distance(to: b)) }
        let total = max(cum[cum.count - 1], 1)

        for (i, f) in frames.enumerated() {
            let snap = try await snapshot(styleURL: styleURL, frame: f)
            let t = Double(i) / Double(frames.count - 1)
            let image = compose(snapshot: snap, frame: f, t: t, track: track, cum: cum, total: total, trip: trip, theme: theme)
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            guard let buffer = pixelBuffer(from: image, size: px, pool: adaptor.pixelBufferPool) else { throw ReplayError.writer }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
            progress(t)
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? ReplayError.writer }
        return url
    }

    enum ReplayError: Error { case noTrack, writer, snapshot }

    private static func snapshot(styleURL: URL, frame f: ReplayFrame) async throws -> MLNMapSnapshot {
        // GM-044: Auto soll bei 62 % der Breite stehen (rechts der Tafeln) – Bildmitte dafür nach links versetzen
        let shifted = offsetCenter(f, dxPoints: -size.width * 0.12)
        let center = CLLocationCoordinate2D(latitude: shifted.latitude, longitude: shifted.longitude)
        let altitude = MLNAltitudeForZoomLevel(f.zoom, CGFloat(f.pitch), center.latitude, size)
        let camera = MLNMapCamera(lookingAtCenter: center, altitude: altitude, pitch: CGFloat(f.pitch), heading: f.heading)
        let options = MLNMapSnapshotOptions(styleURL: styleURL, camera: camera, size: size)
        options.zoomLevel = f.zoom
        options.scale = 2
        let snapshotter = MLNMapSnapshotter(options: options)
        return try await withCheckedThrowingContinuation { cont in
            snapshotter.start { [snapshotter] snap, error in
                _ = snapshotter // bis zum Ende festhalten, sonst bricht MapLibre ab
                if let snap { cont.resume(returning: snap) } else { cont.resume(throwing: error ?? ReplayError.snapshot) }
            }
        }
    }

    /// Mittelpunkt um dx Bildpunkte quer zur Blickrichtung verschieben (Meter pro Punkt aus der Zoomstufe)
    private static func offsetCenter(_ f: ReplayFrame, dxPoints: CGFloat) -> Coordinate {
        let mpp: Double = 78_271.517 * cos(f.center.latitude * .pi / 180) / pow(2, f.zoom)
        let meters: Double = Double(dxPoints) * mpp
        let h: Double = (f.heading + 90) * .pi / 180 // nach rechts im Bild = Blickrichtung + 90°
        let dLat: Double = meters * cos(h) / 110_540
        let dLon: Double = meters * sin(h) / (111_320 * cos(f.center.latitude * .pi / 180))
        return Coordinate(latitude: f.center.latitude + dLat, longitude: f.center.longitude + dLon)
    }

    private static func compose(snapshot: MLNMapSnapshot, frame f: ReplayFrame, t: Double, track: [Coordinate], cum: [Double],
                                total: Double, trip: Journal.Trip, theme: StyleTheme) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            snapshot.image.draw(in: CGRect(origin: .zero, size: size))
            // Strecke bis zum aktuellen Punkt: Leuchten + Linie in Stilfarbe
            let upto = f.progress * total
            let path = UIBezierPath()
            var current: CGPoint?
            for (i, c) in track.enumerated() {
                let p = snapshot.point(for: CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude))
                if i == 0 { path.move(to: p) }
                else if cum[i] <= upto { path.addLine(to: p) }
                else {
                    let a = track[i - 1], seg = max(cum[i] - cum[i - 1], 0.001), k = (upto - cum[i - 1]) / seg
                    let mid = CLLocationCoordinate2D(latitude: a.latitude + (c.latitude - a.latitude) * k, longitude: a.longitude + (c.longitude - a.longitude) * k)
                    let q = snapshot.point(for: mid)
                    path.addLine(to: q)
                    current = q
                    break
                }
            }
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            g.saveGState()
            g.setShadow(offset: .zero, blur: 14, color: theme.route.withAlphaComponent(0.9).cgColor)
            theme.route.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 12
            path.stroke()
            g.restoreGState()
            theme.route.setStroke()
            path.lineWidth = 6
            path.stroke()
            // Pfeil am aktuellen Punkt
            if let p = current, f.progress < 1 {
                let arrow = RouteOverlay.arrowImage()
                g.saveGState()
                g.translateBy(x: p.x, y: p.y)
                arrow.draw(in: CGRect(x: -16, y: -16, width: 32, height: 32))
                g.restoreGState()
            } else if let last = track.last {
                let p = snapshot.point(for: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
                let dot = UIBezierPath(ovalIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16))
                NeonColors.destination.setFill(); dot.fill()
                UIColor.black.setStroke(); dot.lineWidth = 2; dot.stroke()
            }
            // Texte
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.85)
            shadow.shadowBlurRadius = 8
            func text(_ s: String, _ font: UIFont, _ color: UIColor, at point: CGPoint, center: Bool, alpha: CGFloat) {
                guard alpha > 0.01 else { return }
                let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color.withAlphaComponent(alpha), .shadow: shadow]
                let w = (s as NSString).size(withAttributes: attr).width
                (s as NSString).draw(at: CGPoint(x: center ? point.x - w / 2 : point.x, y: point.y), withAttributes: attr)
            }
            text("EzMaps", .systemFont(ofSize: 20, weight: .black), .white, at: CGPoint(x: size.width - 100, y: 12), center: false, alpha: 0.9)
            func panel(_ rect: CGRect, _ color: UIColor, alpha: CGFloat) {
                guard alpha > 0.01 else { return }
                let p = UIBezierPath(roundedRect: rect, cornerRadius: 22)
                color.withAlphaComponent(color.cgColor.alpha * alpha).setFill(); p.fill()
                UIColor.white.withAlphaComponent(0.25 * alpha).setStroke(); p.lineWidth = 0.5; p.stroke()
            }
            // Titel-Tafel (wie die Abbiegekarte in CarPlay)
            let titleA = CGFloat(t < 0.12 ? 1 : max(0, 1 - (t - 0.12) / 0.06))
            panel(CGRect(x: 18, y: 18, width: 300, height: 104), UIColor(red: 124 / 255.0, green: 40 / 255.0, blue: 200 / 255.0, alpha: 0.8), alpha: titleA)
            text(L("Fahrt zum").uppercased(), .systemFont(ofSize: 12, weight: .bold), UIColor(red: 0.91, green: 0.82, blue: 1, alpha: 1),
                 at: CGPoint(x: 36, y: 32), center: false, alpha: titleA)
            text(trip.destination, .systemFont(ofSize: 30, weight: .black), .white, at: CGPoint(x: 36, y: 48), center: false, alpha: titleA)
            text(Formatting.distance(trip.meters) + " · " + Formatting.minutes(trip.seconds), .systemFont(ofSize: 14, weight: .semibold), .white,
                 at: CGPoint(x: 36, y: 90), center: false, alpha: titleA * 0.9)
            // Ergebnis-Tafel links unten
            let endA = CGFloat(min(1, max(0, (t - 0.8) / 0.1)))
            if trip.newPercent > 0 {
                panel(CGRect(x: 18, y: size.height - 150, width: 300, height: 132), UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 32 / 255.0, alpha: 0.78), alpha: endA)
                text("+\(trip.newPercent) %", .systemFont(ofSize: 54, weight: .black), UIColor(red: 0.95, green: 0.89, blue: 1, alpha: 1),
                     at: CGPoint(x: 36, y: size.height - 140), center: false, alpha: endA)
                text(L("neue Straßen"), .systemFont(ofSize: 17, weight: .heavy), .white, at: CGPoint(x: 36, y: size.height - 74), center: false, alpha: endA)
            }
            text(L("© OpenMapTiles · © OpenStreetMap-Mitwirkende"), .systemFont(ofSize: 9, weight: .medium), .white,
                 at: CGPoint(x: size.width - 240, y: size.height - 20), center: false, alpha: 0.8)
        }
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        if let pool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) }
        if buffer == nil {
            let attrs: [String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
            CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        }
        guard let buf = buffer, let cg = image.cgImage else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }
        let info: UInt32 = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else { return nil }
        ctx.draw(cg, in: CGRect(origin: .zero, size: size))
        return buf
    }
}

/// Replay erstellen, ansehen, teilen
struct ReplaySheet: View {
    let model: AppModel
    let trip: Journal.Trip
    @State private var progress: Double = 0
    @State private var url: URL?
    @State private var player: AVPlayer?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                GlassRoundButton(systemImage: "xmark", label: L("Schließen"), size: 36) { dismiss() }
                Spacer()
                Text(L("Replay")).font(.headline)
                Spacer()
                SwiftUI.Color.clear.frame(width: 36, height: 36)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SwiftUI.Color.black)
                if let player {
                    VideoPlayer(player: player).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else if failed {
                    Text(L("Video konnte nicht erstellt werden")).foregroundStyle(GlassTokens.secondary)
                } else {
                    VStack(spacing: 12) {
                        ProgressView(value: progress).tint(GlassTokens.accent).frame(width: 180)
                        Text(L("Video wird erstellt …")).font(.footnote).foregroundStyle(GlassTokens.secondary)
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit) // GM-044: Querformat wie CarPlay
            if let url {
                ShareLink(item: url) { Label(L("Teilen"), systemImage: "square.and.arrow.up") }
                    .buttonStyle(PrimaryGlassButtonStyle(height: 52))
            }
            Text(L("Video bleibt auf dem iPhone, bis du es teilst.")).font(.system(size: 11)).foregroundStyle(GlassTokens.secondary)
        }
        .padding(18)
        .background(SwiftUI.Color(red: 11 / 255.0, green: 11 / 255.0, blue: 13 / 255.0).ignoresSafeArea())
        .task {
            do {
                let u = try await ReplayExporter.export(trip: trip, style: model.activeStyle) { p in progress = p }
                url = u
                let p = AVPlayer(url: u)
                player = p
                p.play()
            } catch {
                failed = true
            }
        }
        .onDisappear { player?.pause() }
    }
}
