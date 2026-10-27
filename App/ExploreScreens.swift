import CoreLocation
import SwiftUI
import UIKit
import MapLibre
import EzMapsCore

/// GM-043: „Entdecken“ (GM-041 Meine Stadt): Karte mit Nebel, gefahrene Straßen leuchten, Anteil des sichtbaren Gebiets,
/// Stufe, Abzeichen, Wochenmission, Meine Fahrten.
struct ExploreScreen: View {
    let model: AppModel
    @State private var areaShare: Double?
    @State private var showTrips = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ExploreMapView(style: model.activeStyle, cells: model.exploredCellKeys) { roadCells in
                areaShare = roadCells.count < 40 ? nil : model.share(of: roadCells)
            }
            .ignoresSafeArea()
            StatusBarScrim()
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    areaCard
                    GlassRoundButton(systemImage: "xmark", label: L("Schließen")) { dismiss() }
                }
                Spacer()
                HStack { Spacer(); OSMAttribution() }
                bottomSheet
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showTrips) { TripsScreen(model: model) }
    }

    private var areaCard: some View {
        let share = areaShare ?? 0
        let lv = ExploreLevel.forShare(share)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Kicker(text: L("Dieses Gebiet"))
                    Text(areaShare == nil ? "–" : "\(Int((share * 100).rounded())) %").font(.system(size: 38, weight: .black)).tracking(-1.2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: L("Stufe %d"), lv.number)).font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(LinearGradient(colors: [GlassTokens.accent, GlassTokens.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(L(lv.title)).font(.system(size: 17, weight: .heavy))
                }
            }
            GlassProgress(value: share / (lv.next ?? 1))
            Text(areaShare == nil ? L("Näher heranzoomen, um den Anteil zu sehen") :
                    (lv.next.map { String(format: L("noch %d %% bis Stufe %d"), max(1, Int((($0 - share) * 100).rounded())), lv.number + 1) } ?? L("höchste Stufe")))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(GlassTokens.secondary)
        }
        .padding(14)
        .glass(GlassTokens.card)
    }

    private var bottomSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetGrabber()
            HStack(spacing: 8) {
                StatTile(value: String(format: "%.0f km", model.exploredKm), label: L("Straßen entdeckt"), hot: true)
                StatTile(value: "\(model.journal.trips.count)", label: L("Fahrten"))
                StatTile(value: "\(model.journal.badges.count) / \(Badge.allCases.count)", label: L("Abzeichen"))
            }
            MissionCard(mission: model.journal.mission)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Badge.allCases, id: \.self) { b in BadgeChip(badge: b, earned: model.journal.badges.contains(b)) }
                }
            }
            Button { showTrips = true } label: { Label(L("Meine Fahrten"), systemImage: "list.bullet") }
                .buttonStyle(GlassButtonStyle(height: 48, radius: 16))
        }
        .padding(16)
        .glass()
    }
}

/// Karte für „Entdecken“: dunkler Schleier, aufgedeckte Zellen als Leuchtpunkte (wachsen beim Zoomen zu Linien zusammen).
/// Meldet nach jeder Kamerabewegung die Straßenzellen im Bild (für den Anteil „Dieses Gebiet“).
struct ExploreMapView: UIViewRepresentable {
    let style: MapStyle
    let cells: Set<UInt64>
    let onArea: (Set<UInt64>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onArea: onArea) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = NeonMap.make(zoom: 13.5, style: style)
        if let c = AppModel.shared.currentCoordinate {
            map.setCenter(CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude), zoomLevel: 13.5, animated: false)
        }
        map.showsUserLocation = true
        map.isPitchEnabled = false
        map.delegate = context.coordinator
        context.coordinator.cells = cells
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.onArea = onArea
        if context.coordinator.cells.count != cells.count {
            context.coordinator.cells = cells
            context.coordinator.showCells(on: map)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var onArea: (Set<UInt64>) -> Void
        var cells: Set<UInt64> = []
        private var debounce: DispatchWorkItem?

        init(onArea: @escaping (Set<UInt64>) -> Void) { self.onArea = onArea }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Nebel: eine Fläche über allem (unter unseren Leuchtpunkten)
            var ring: [CLLocationCoordinate2D] = [
                CLLocationCoordinate2D(latitude: 85, longitude: -180), CLLocationCoordinate2D(latitude: 85, longitude: 180),
                CLLocationCoordinate2D(latitude: -85, longitude: 180), CLLocationCoordinate2D(latitude: -85, longitude: -180),
            ]
            let world = MLNPolygonFeature(coordinates: &ring, count: UInt(ring.count))
            let fogSource = MLNShapeSource(identifier: "ez-fog", shape: world, options: nil)
            style.addSource(fogSource)
            let fog = MLNFillStyleLayer(identifier: "ez-fog-fill", source: fogSource)
            fog.fillColor = NSExpression(forConstantValue: UIColor(red: 10 / 255.0, green: 10 / 255.0, blue: 14 / 255.0, alpha: 1))
            fog.fillOpacity = NSExpression(forConstantValue: 0.55)
            style.addLayer(fog)

            let src = MLNShapeSource(identifier: "ez-cells", shape: MLNShapeCollectionFeature(shapes: []), options: nil)
            style.addSource(src)
            let radius = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'exponential', 2, %@)",
                                      [10: 1.5, 13: 3, 16: 14, 18: 40])
            let glow = MLNCircleStyleLayer(identifier: "ez-cells-glow", source: src)
            glow.circleColor = NSExpression(forConstantValue: UIColor(red: 0.77, green: 0.47, blue: 1, alpha: 1))
            glow.circleOpacity = NSExpression(forConstantValue: 0.35)
            glow.circleRadius = radius
            glow.circleBlur = NSExpression(forConstantValue: 0.8)
            style.addLayer(glow)
            let core = MLNCircleStyleLayer(identifier: "ez-cells-core", source: src)
            core.circleColor = NSExpression(forConstantValue: UIColor(red: 0.9, green: 0.78, blue: 1, alpha: 1))
            core.circleOpacity = NSExpression(forConstantValue: 0.8)
            core.circleRadius = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'exponential', 2, %@)",
                                             [10: 0.6, 13: 1.2, 16: 5, 18: 14])
            style.addLayer(core)
            showCells(on: mapView)
        }

        func showCells(on map: MLNMapView) {
            guard let src = map.style?.source(withIdentifier: "ez-cells") as? MLNShapeSource else { return }
            var points: [MLNShape & MLNFeature] = []
            points.reserveCapacity(cells.count)
            for k in cells {
                let c = ExploreCell.center(k)
                let p = MLNPointFeature()
                p.coordinate = CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
                points.append(p)
            }
            src.shape = MLNShapeCollectionFeature(shapes: points)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            debounce?.cancel()
            let work = DispatchWorkItem { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.onArea(Self.roadCells(in: mapView))
            }
            debounce = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }

        /// Zellen aller Straßen im Bild (Ebenen aus build_style.py: road-motorway … road-service)
        static func roadCells(in map: MLNMapView) -> Set<UInt64> {
            guard map.zoomLevel >= 12 else { return [] }
            let ids: Set<String> = ["road-primary", "road-secondary", "road-tertiary", "road-minor", "road-trunk"]
            let features = map.visibleFeatures(in: map.bounds, styleLayerIdentifiers: ids)
            var out: Set<UInt64> = []
            for f in features {
                if let line = f as? MLNPolylineFeature {
                    out.formUnion(ExploreCell.cells(along: coords(of: line)))
                } else if let multi = f as? MLNMultiPolylineFeature {
                    for line in multi.polylines { out.formUnion(ExploreCell.cells(along: coords(of: line))) }
                }
            }
            return out
        }

        static func coords(of line: MLNPolyline) -> [Coordinate] {
            let n = Int(line.pointCount)
            guard n > 0 else { return [] }
            var buf = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: n)
            line.getCoordinates(&buf, range: NSRange(location: 0, length: n))
            return buf.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }
    }
}

/// GM-033: Meine Fahrten – lokaler Verlauf. Von hier: Replay, nochmal fahren, löschen.
struct TripsScreen: View {
    let model: AppModel
    @State private var replay: Journal.Trip?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let sum = model.journal.monthSummary()
                Section {
                    HStack(spacing: 8) {
                        StatTile(value: Formatting.distance(sum.meters), label: L("diesen Monat"))
                        StatTile(value: "\(sum.trips)", label: L("Fahrten"))
                        StatTile(value: Formatting.minutes(sum.seconds), label: L("unterwegs"))
                    }
                    .listRowBackground(SwiftUI.Color.clear)
                }
                Section {
                    ForEach(model.journal.trips) { t in
                        HStack(spacing: 12) {
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .foregroundStyle(GlassTokens.accentLight).frame(width: 40, height: 40).neutralGlass(12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.destination).font(.body.weight(.semibold)).lineLimit(1)
                                Text(t.date.formatted(date: .abbreviated, time: .shortened) + " · " + Formatting.distance(t.meters) + " · " + Formatting.minutes(t.seconds))
                                    .font(.footnote).foregroundStyle(GlassTokens.secondary).lineLimit(1)
                                if t.newPercent > 0 {
                                    Text(String(format: L("+%d %% neue Straßen"), t.newPercent)).font(.caption.weight(.bold)).foregroundStyle(GlassTokens.accentLight)
                                }
                            }
                            Spacer()
                            Button { replay = t } label: { Image(systemName: "play.circle.fill").font(.title2) }
                                .buttonStyle(.plain).foregroundStyle(GlassTokens.accent)
                                .accessibilityLabel(L("Replay"))
                        }
                        .listRowBackground(SwiftUI.Color.white.opacity(0.05))
                        .swipeActions {
                            Button(role: .destructive) { model.updateJournal { $0.deleteTrip(t.id) } } label: { Label(L("Löschen"), systemImage: "trash") }
                        }
                    }
                } footer: {
                    Text(L("Fahrten bleiben nur auf diesem iPhone. Speichern in den Einstellungen abschaltbar."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(SwiftUI.Color(red: 11 / 255.0, green: 11 / 255.0, blue: 13 / 255.0).ignoresSafeArea())
            .navigationTitle(L("Meine Fahrten"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } } }
            .overlay { if model.journal.trips.isEmpty { ContentUnavailableView(L("Noch keine Fahrten"), systemImage: "car", description: Text(L("Nach jeder Fahrt erscheint sie hier."))) } }
            .sheet(item: $replay) { t in ReplaySheet(model: model, trip: t) }
        }
    }
}

/// GM-029/033: „Wo hab ich geparkt?“ – erscheint nach dem Trennen von CarPlay
struct ParkedCarSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "car.top.radiowaves.rear.right.fill").font(.system(size: 26)).foregroundStyle(.white)
                    .frame(width: 52, height: 52).neutralGlass(16, selected: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Dein Auto")).font(.system(size: 22, weight: .heavy))
                    if let p = model.journal.parked {
                        Text(String(format: L("seit %@"), Formatting.clock(p.date)) + distanceText(p.coordinate))
                            .font(.subheadline).foregroundStyle(GlassTokens.secondary)
                    }
                }
                Spacer()
                GlassRoundButton(systemImage: "xmark", label: L("Schließen"), size: 36) { dismiss() }
            }
            HStack(spacing: 8) {
                Button { model.walkToCar() } label: { Label(L("Zu Fuß hin"), systemImage: "figure.walk") }
                    .buttonStyle(PrimaryGlassButtonStyle(height: 52))
                if let p = model.journal.parked {
                    ShareLink(item: URL(string: "https://maps.apple.com/?ll=\(p.coordinate.latitude),\(p.coordinate.longitude)&q=Auto")!) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 52, height: 52).neutralGlass(18)
                    }
                    .accessibilityLabel(L("Teilen"))
                }
            }
            Button(L("Vergessen")) { model.updateJournal { $0.parked = nil }; dismiss() }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(GlassTokens.accentLight).frame(maxWidth: .infinity)
        }
        .padding(20)
        .presentationBackground(.ultraThinMaterial)
    }

    private func distanceText(_ c: Coordinate) -> String {
        guard let here = model.currentCoordinate else { return "" }
        return " · " + Formatting.distance(here.distance(to: c))
    }
}
