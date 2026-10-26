import SwiftUI
import UIKit
import EzMapsCore

/// iPhone: eine Karte, darüber je nach Schritt Suche, Routen-Vorschau, Navigation oder Ankunft (wie im Prototyp).
struct ContentView: View {
    @State private var model = AppModel.shared
    @State private var showSettings = false

    var body: some View {
        ZStack {
            NeonMapView(
                routes: model.routes,
                selected: model.selectedRoute,
                destination: model.destination?.coordinate,
                revision: model.routeRevision,
                navigating: model.screen == .navigating,
                recenterRequest: model.recenterRequest,
                follow: model.navCoordinate,
                heading: model.navHeading,
                padding: UIEdgeInsets(top: 120, left: 40, bottom: 360, right: 40)
            )
            .ignoresSafeArea()

            switch model.screen {
            case .map: MapHome(model: model, showSettings: $showSettings)
            case .search: SearchScreen(model: model)
            case .preview: RoutePreview(model: model)
            case .navigating: NavigationHUD(model: model)
            case .arrived: ArrivalSheet(model: model)
            }
        }
        .overlay(alignment: .bottom) {
            if let m = model.message {
                Text(m)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.85), in: Capsule())
                    .padding(.bottom, 120)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsScreen(model: model) }
        .preferredColorScheme(.dark)
        .tint(Color(uiColor: NeonColors.route))
        .onAppear {
            model.onAppear()
            ScreenshotMode.run(model) // GM-021: nur mit Startargument -EZShot (Store-Screenshots)
            if ScreenshotMode.state == "einstellungen" { showSettings = true }
        }
    }
}

// MARK: Bausteine im Neon-Look (schwarze Kästen, eckig – wie Prototyp)

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .background(Color.black.opacity(0.85))
    }
}

struct SquareButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.85))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
    }
}

// MARK: Startbildschirm Karte

struct MapHome: View {
    let model: AppModel
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button { model.openSearch() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    Text(L("Wohin?")).font(.title3.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.black.opacity(0.85))
                .overlay(alignment: .leading) { Rectangle().fill(Color(uiColor: NeonColors.route)).frame(width: 5) }
            }
            .accessibilityLabel(L("Ziel suchen"))
            HStack(alignment: .top) {
                Spacer()
                VStack(spacing: 8) {
                    SquareButton(systemImage: "location.north.line", label: L("Auf meinen Standort zentrieren")) { model.recenter() }
                    SquareButton(systemImage: "gearshape", label: L("Einstellungen")) { showSettings = true }
                }
            }
            Spacer()
            if model.location.isDenied {
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Ortungsdienste sind aus")).font(.headline)
                        Text(L("Ohne Standort kann EzMaps nicht navigieren. Du kannst es in den Einstellungen erlauben."))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button(L("Einstellungen öffnen")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
            }
            HStack { Spacer(); OSMAttribution() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: Suche

struct SearchScreen: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L("Ort, Adresse oder Geschäft"), text: $model.query)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .onChange(of: model.query) { model.queryChanged() }
                        .onSubmit { if let first = model.results.first { model.choose(first) } }
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(Color(white: 0.12))
                Button(L("Abbrechen")) { model.closeSearch() }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            List {
                if model.query.trimmingCharacters(in: .whitespaces).count < 2 {
                    if !model.recents.isEmpty {
                        Section(L("Zuletzt")) { ForEach(model.recents, id: \.self) { PlaceRow(place: $0, model: model) } }
                    }
                } else {
                    if model.isSearching && model.results.isEmpty {
                        HStack { ProgressView(); Text(L("Suche …")).foregroundStyle(.secondary) }
                    }
                    ForEach(model.results, id: \.self) { PlaceRow(place: $0, model: model) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            HStack { Spacer(); OSMAttribution() }.padding(8)
        }
        .background(Color.black.opacity(0.92))
        .onAppear { focused = true }
    }
}

struct PlaceRow: View {
    let place: PhotonClient.Place
    let model: AppModel
    var body: some View {
        Button { model.choose(place) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.body.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 0) {
                    Text(place.subtitle).lineLimit(1)
                    if let here = model.currentCoordinate {
                        Text(" · " + Formatting.distance(here.distance(to: place.coordinate)))
                    }
                }
                .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: Routen-Vorschau

struct RoutePreview: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { model.cancelPreview() } label: { Image(systemName: "chevron.left").font(.title3.weight(.semibold)) }
                    .accessibilityLabel(L("Zurück"))
                Text(model.destination?.name ?? "").font(.headline).lineLimit(1)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.black.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
            HStack { Spacer(); OSMAttribution() }.padding(.horizontal, 16).padding(.bottom, 6)
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.destination?.name ?? "").font(.title2.weight(.bold)).lineLimit(2).minimumScaleFactor(0.7)
                    Text(model.destination?.subtitle ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if model.isRouting {
                        HStack { ProgressView(); Text(L("Route wird berechnet …")).foregroundStyle(.secondary) }
                    }
                    ForEach(Array(model.routes.enumerated()), id: \.offset) { i, r in
                        RouteOptionRow(index: i, route: r, selected: i == model.selectedRoute) { model.selectedRoute = i }
                    }
                    Button { model.startNavigation() } label: {
                        Text(L("Los")).font(.title3.weight(.heavy)).frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color(uiColor: NeonColors.route)).foregroundStyle(.white)
                    }
                    .disabled(model.routes.isEmpty)
                }
            }
        }
    }
}

struct RouteOptionRow: View {
    let index: Int
    let route: Route
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(index == 0 ? L("Schnellste") : String(format: L("Alternative %d"), index)).font(.headline)
                    Text(Formatting.distance(route.length)).font(.subheadline).opacity(0.7)
                }
                Spacer()
                Text(Formatting.minutes(route.duration)).font(.title3.weight(.bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? Color.black : Color.white)
            .background(selected ? Color.white : Color(white: 0.12))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Navigation

struct NavigationHUD: View {
    let model: AppModel

    var body: some View {
        let s = model.nav
        VStack(spacing: 10) {
            // Abbiegehinweis oben
            HStack(spacing: 14) {
                Image(systemName: Self.symbol(for: s?.maneuver?.kind))
                    .font(.system(size: 40, weight: .bold))
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.map { Formatting.distance($0.distanceToManeuver) } ?? "–")
                        .font(.system(size: 38, weight: .heavy)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(Self.street(s)).font(.headline).textCase(.uppercase).lineLimit(1).minimumScaleFactor(0.7)
                    Text(s?.maneuver?.text ?? L("Route wird gestartet …")).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(Color.black.opacity(0.88))
            .overlay(alignment: .leading) { Rectangle().fill(Color(uiColor: NeonColors.route)).frame(width: 5) }
            .accessibilityElement(children: .combine)

            HStack(alignment: .top) {
                if let then = s?.thenManeuver, then.kind != .destination {
                    Text(L("danach") + " " + NavigationSession.lowerFirst(then.text) + (then.street.isEmpty ? "" : " · " + then.street))
                        .font(.footnote.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6).background(Color.black.opacity(0.8))
                }
                Spacer()
                if model.settings.showSpeedLimit, let limit = s?.speedLimit { SpeedLimitSign(limit: limit) }
            }
            Spacer()
            HStack(alignment: .bottom) {
                if model.isSpeaking && model.settings.duckMusic {
                    Label(L("Musik leiser"), systemImage: "speaker.wave.1").font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Color.black.opacity(0.8))
                }
                Spacer()
                SquareButton(systemImage: "location.north.line", label: L("Auf meinen Standort zentrieren")) { model.recenter() }
            }
            HStack { Spacer(); OSMAttribution() }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.map { Formatting.clock(Date().addingTimeInterval($0.remainingTime)) } ?? "–")
                        .font(.system(size: 30, weight: .heavy))
                    Text(s.map { Formatting.minutes($0.remainingTime) + " · " + Formatting.distance($0.remainingDistance) } ?? "")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.endNavigation() } label: {
                    Text(L("Ende")).font(.headline).padding(.horizontal, 26).frame(height: 48)
                        .background(Color(red: 1, green: 0.23, blue: 0.3)).foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.88))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    static func street(_ s: NavigationSession.State?) -> String {
        guard let m = s?.maneuver else { return "" }
        return m.kind == .destination ? (AppModel.shared.destination?.name ?? "") : m.street
    }

    static func symbol(for kind: ManeuverKind?) -> String {
        switch kind {
        case .some(.left), .some(.sharpLeft): return "arrow.turn.up.left"
        case .some(.right), .some(.sharpRight): return "arrow.turn.up.right"
        case .some(.slightLeft): return "arrow.up.left"
        case .some(.slightRight): return "arrow.up.right"
        case .some(.uturnLeft), .some(.uturnRight): return "arrow.uturn.down"
        case .some(.destination): return "flag.checkered"
        case .none: return "arrow.up"
        }
    }
}

/// Tempolimit-Schild (roter Ring); „∞“ = Autobahn ohne Limit
struct SpeedLimitSign: View {
    let limit: Int
    var body: some View {
        Text(limit < 0 ? "∞" : String(limit))
            .font(.system(size: 26, weight: .heavy))
            .minimumScaleFactor(0.5)
            .foregroundStyle(.black)
            .frame(width: 64, height: 64)
            .background(Circle().fill(.white))
            .overlay(Circle().stroke(Color.red, lineWidth: 7))
            .accessibilityLabel(limit < 0 ? L("Kein Tempolimit") : String(format: L("Tempolimit %d"), limit))
    }
}

// MARK: Ankunft

struct ArrivalSheet: View {
    let model: AppModel
    var body: some View {
        VStack {
            Spacer()
            HStack { Spacer(); OSMAttribution() }.padding(.horizontal, 16).padding(.bottom, 6)
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Angekommen")).font(.caption.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(model.destination?.name ?? "").font(.title.weight(.bold)).lineLimit(2).minimumScaleFactor(0.7)
                    Button { model.endNavigation() } label: {
                        Text(L("Fertig")).font(.title3.weight(.heavy)).frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color(uiColor: NeonColors.route)).foregroundStyle(.white)
                    }
                }
            }
        }
    }
}
