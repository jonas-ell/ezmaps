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

/// Gemeinsamer Aufbau für iPhone und CarPlay
enum NeonMap {
    static func make(frame: CGRect = .zero, zoom: Double = 13) -> MLNMapView {
        let map = MLNMapView(frame: frame, styleURL: MapStyleResource.url(for: .neonCity))
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.setCenter(MapStyleResource.idstein, zoomLevel: zoom, animated: false)
        map.showsUserLocation = true
        map.logoView.isHidden = true
        // Den OSM-Hinweis zeigen wir immer selbst als Text (ODbL), das (i)-Symbol bleibt für Details
        map.attributionButtonPosition = .topRight
        return map
    }
}

struct NeonMapView: UIViewRepresentable {
    func makeUIView(context: Context) -> MLNMapView { NeonMap.make() }
    func updateUIView(_ uiView: MLNMapView, context: Context) {}
}

/// Hinweis „© OpenStreetMap-Mitwirkende“ – auf jedem Kartenbildschirm sichtbar (rechtlich Pflicht)
struct OSMAttribution: View {
    var body: some View {
        Text(L("© OpenStreetMap-Mitwirkende"))
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel(L("© OpenStreetMap-Mitwirkende"))
    }
}
