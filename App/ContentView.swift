import SwiftUI
import UIKit
import EzMapsCore

/// iPhone: eine Karte, darüber je nach Schritt Suche, Routen-Vorschau, Navigation oder Ankunft (wie im Prototyp).
/// GM-043: alles im Glas-Look (GM-032/036), Stil wählbar, Onboarding, Shop, Entdecken, Fahrten, Parkplatz.
struct ContentView: View {
    @State private var model = AppModel.shared
    @State private var showSettings = false
    @State private var showExplore = false
    @Environment(\.scenePhase) private var scenePhase
    private var onboarding: Bool { !model.settings.onboarded && ScreenshotMode.state == nil }

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
                speedKmh: model.navSpeedKmh,
                padding: UIEdgeInsets(top: 130, left: 60, bottom: 380, right: 60),
                visible: scenePhase == .active,
                style: onboarding ? .neonCity : model.activeStyle, // GM-045: Willkommen zeigt den Neon-Look
                trail: model.trail,
                locationAllowed: model.location.isAllowed
            )
            .ignoresSafeArea()

            StatusBarScrim()

            switch model.screen {
            case .map: if !onboarding { MapHome(model: model, showSettings: $showSettings, showExplore: $showExplore) } // GM-045: nicht unter dem Onboarding
            case .search: SearchScreen(model: model)
            case .preview: RoutePreview(model: model)
            case .navigating: NavigationHUD(model: model)
            case .arrived: ArrivalSheet(model: model)
            }

            if onboarding {
                OnboardingView(model: model).transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let m = model.message {
                Text(m)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glass(20)
                    .padding(.top, model.screen == .navigating ? 200 : 60) // GM-049: unter der Abbiegekarte statt darüber
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsScreen(model: model) }
        .sheet(item: Binding(get: { model.shopRequest }, set: { model.shopRequest = $0 })) { style in
            ShopScreen(model: model, focus: style == .classic ? nil : style)
        }
        .sheet(item: Binding(get: { model.trialEnded }, set: { model.trialEnded = $0 })) { style in
            TrialEndedSheet(model: model, style: style).presentationDetents([.medium])
        }
        .sheet(isPresented: Binding(get: { model.showParkedCar && model.screen == .map }, set: { model.showParkedCar = $0 })) {
            ParkedCarSheet(model: model).presentationDetents([.height(300)])
        }
        .fullScreenCover(isPresented: $showExplore) { ExploreScreen(model: model) }
        // GM-031: Store-Screenshot „einstellungen“ – mehrmals versuchen, bis das Blatt offen ist (Task in onAppear ging verloren)
        .task {
            guard ScreenshotMode.state == "einstellungen" else { return }
            for _ in 0..<6 where !showSettings {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                showSettings = true
            }
        }
        .preferredColorScheme(.dark)
        .tint(GlassTokens.accent)
        .onChange(of: scenePhase) {
            model.appActive = scenePhase == .active
            if scenePhase != .active { model.saveTrialNow() }
        }
        .onAppear {
            model.appActive = scenePhase == .active
            model.onAppear()
            ScreenshotMode.run(model) // GM-021: nur mit Startargument -EZShot (Store-Screenshots)
        }
    }
}

// MARK: Ältere Bausteine (noch von CarPlay/Einstellungen benutzt)

enum EZShape {
    static let box = RoundedRectangle(cornerRadius: 16, style: .continuous)
    static let small = RoundedRectangle(cornerRadius: 10, style: .continuous)
}

// MARK: Startbildschirm Karte (GM-032 Block 2: schwebendes Glas-Blatt unten, Knöpfe rechts)

struct MapHome: View {
    let model: AppModel
    @Binding var showSettings: Bool
    @Binding var showExplore: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                if let r = model.trialRemaining { TrialBadge(model: model, remaining: r) }
                Spacer()
                VStack(spacing: 10) {
                    GlassRoundButton(systemImage: "location.north.line", label: L("Auf meinen Standort zentrieren")) { model.recenter() }
                        .padding(.top, 54) // GM-050: Platz für den Kompass oben rechts (überlappte vorher)
                    GlassRoundButton(systemImage: "paintpalette", label: L("Stile")) { model.shopRequest = .classic }
                    GlassRoundButton(systemImage: "map", label: L("Entdecken")) { showExplore = true }
                    GlassRoundButton(systemImage: "gearshape", label: L("Einstellungen")) { showSettings = true }
                }
            }
            Spacer()
            if model.location.isDenied { LocationDeniedCard() }
            HStack { Spacer(); OSMAttribution() }
            VStack(alignment: .leading, spacing: 10) {
                SheetGrabber()
                if !model.journal.mission.done { MissionCard(mission: model.journal.mission) }
                Button { model.openSearch() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(GlassTokens.secondary)
                        Text(L("Wohin?")).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(SwiftUI.Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Ziel suchen"))
                QuickChips(model: model)
            }
            .padding(14)
            .glass()
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

/// Schnellziele als Chips: Zuhause, Arbeit, Favoriten, Dein Auto
struct QuickChips: View {
    let model: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let home = model.journal.home {
                    Button { model.choose(home) } label: { GlassChip(text: L("Zuhause"), systemImage: "house") }.buttonStyle(.plain)
                }
                if let work = model.journal.work {
                    Button { model.choose(work) } label: { GlassChip(text: L("Arbeit"), systemImage: "briefcase") }.buttonStyle(.plain)
                }
                ForEach(model.journal.favorites.prefix(6), id: \.self) { fav in
                    Button { model.choose(fav) } label: { GlassChip(text: fav.name, systemImage: "star.fill", iconColor: GlassTokens.gold) }.buttonStyle(.plain)
                }
                if model.journal.parked != nil {
                    Button { model.showParkedCar = true } label: { GlassChip(text: L("Dein Auto"), systemImage: "car.fill") }.buttonStyle(.plain)
                }
                if model.journal.home == nil && model.journal.work == nil && model.journal.favorites.isEmpty {
                    Text(L("Tipp: Ziele mit dem Stern merken")).font(.footnote).foregroundStyle(GlassTokens.secondary)
                }
            }
        }
    }
}

/// Wochenmission (GM-041) im Startblatt
struct MissionCard: View {
    let mission: WeeklyMission
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(LinearGradient(colors: [GlassTokens.accent, GlassTokens.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(L("Diese Woche")).font(.system(size: 14, weight: .heavy))
                Text(L(mission.title)).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
                GlassProgress(value: mission.progress, height: 6)
            }
            Text(mission.progressText).font(.system(size: 14, weight: .heavy)).lineLimit(1).fixedSize()
        }
        .padding(12)
        .neutralGlass(18, selected: true)
        .accessibilityElement(children: .combine)
    }
}

/// Stil-Test läuft: Name, Restzeit, „Plus holen“
struct TrialBadge: View {
    let model: AppModel
    let remaining: TimeInterval
    var body: some View {
        let s = Int(remaining.rounded(.up))
        HStack(spacing: 10) {
            Text(String(format: "%d:%02d", s / 60, s % 60))
                .font(.system(size: 13, weight: .heavy).monospacedDigit())
                .frame(width: 44, height: 40)
                .background(LinearGradient(colors: [GlassTokens.accent, GlassTokens.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                StyleName(style: model.settings.style, size: 14)
                Text(L("Test läuft")).font(.caption2).foregroundStyle(GlassTokens.secondary)
            }
            Button(L("Plus holen")) { model.shopRequest = model.settings.style }
                .font(.system(size: 13, weight: .heavy))
                .padding(.horizontal, 10).frame(height: 32)
                .background(GlassTokens.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
        }
        .padding(8)
        .glass(18)
        .frame(maxWidth: 290, alignment: .leading)
    }
}

struct LocationDeniedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "location.slash").foregroundStyle(GlassTokens.warn)
                    .frame(width: 44, height: 44)
                    .background(GlassTokens.warn.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Standort ist aus")).font(.system(size: 17, weight: .heavy))
                    Text(L("Ohne Standort keine Navigation.")).font(.subheadline).foregroundStyle(GlassTokens.secondary)
                }
            }
            Button(L("In Einstellungen erlauben")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(PrimaryGlassButtonStyle(height: 48))
        }
        .padding(14)
        .glass()
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
                    Image(systemName: "magnifyingglass").foregroundStyle(GlassTokens.secondary)
                    TextField(L("Ort, Adresse oder Geschäft"), text: $model.query)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .onChange(of: model.query) { model.queryChanged() }
                        .onSubmit { if let first = model.results.first { model.choose(first) } }
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .neutralGlass(14, selected: true)
                Button(L("Abbrechen")) { model.closeSearch() }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            List {
                if model.query.trimmingCharacters(in: .whitespaces).count < 2 {
                    let mine: [(String, String, PhotonClient.Place)] =
                        [model.journal.home.map { (L("Zuhause"), "house", $0) }, model.journal.work.map { (L("Arbeit"), "briefcase", $0) }].compactMap { $0 }
                    if !mine.isEmpty {
                        Section(L("Meine Orte")) {
                            ForEach(Array(mine.enumerated()), id: \.offset) { _, item in PlaceRow(place: item.2, model: model, title: item.0, icon: item.1) }
                        }
                    }
                    if !model.journal.favorites.isEmpty {
                        Section(L("Favoriten")) { ForEach(model.journal.favorites, id: \.self) { PlaceRow(place: $0, model: model, icon: "star.fill") } }
                    }
                    if !model.recents.isEmpty {
                        Section(L("Zuletzt")) { ForEach(model.recents, id: \.self) { PlaceRow(place: $0, model: model, icon: "clock") } }
                    }
                } else {
                    if model.isSearching && model.results.isEmpty {
                        HStack { ProgressView(); Text(L("Suche …")).foregroundStyle(.secondary) }.listRowBackground(SwiftUI.Color.clear)
                    }
                    ForEach(model.results, id: \.self) { PlaceRow(place: $0, model: model, icon: "mappin") }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            HStack { Spacer(); OSMAttribution() }.padding(8)
        }
        .background(.ultraThinMaterial)
        .background(SwiftUI.Color.black.opacity(0.55))
        .onAppear { focused = true }
    }
}

struct PlaceRow: View {
    let place: PhotonClient.Place
    let model: AppModel
    var title: String?
    var icon: String = "mappin"

    var body: some View {
        Button { model.choose(place) } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(icon == "star.fill" ? GlassTokens.gold : GlassTokens.accentLight)
                    .frame(width: 36, height: 36)
                    .neutralGlass(12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? place.name).font(.body.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(title == nil ? place.subtitle : place.name).font(.subheadline).foregroundStyle(GlassTokens.secondary).lineLimit(1)
                }
                Spacer()
                if let here = model.currentCoordinate {
                    Text(Formatting.distance(here.distance(to: place.coordinate))).font(.subheadline).foregroundStyle(GlassTokens.secondary)
                }
            }
        }
        .listRowBackground(SwiftUI.Color.clear)
    }
}

// MARK: Routen-Vorschau (GM-032 Block 3: Blatt mit Griff, Routen als Glaskarten, Stern für Favoriten)

struct RoutePreview: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                GlassRoundButton(systemImage: "chevron.left", label: L("Zurück")) { model.cancelPreview() }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
            HStack { Spacer(); OSMAttribution() }.padding(.horizontal, 16).padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 10) {
                SheetGrabber()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.destination?.name ?? "").font(.system(size: 26, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.7)
                        Text(model.destination?.subtitle ?? "").font(.subheadline).foregroundStyle(GlassTokens.secondary).lineLimit(1)
                    }
                    Spacer()
                    if let d = model.destination {
                        let fav = model.journal.isFavorite(d)
                        GlassRoundButton(systemImage: fav ? "star.fill" : "star", label: fav ? L("Favorit entfernen") : L("Als Favorit merken"),
                                         size: 38, tint: GlassTokens.gold) { model.toggleFavorite(d) }
                        Menu {
                            Button(L("Als Zuhause speichern"), systemImage: "house") { model.updateJournal { $0.home = d } }
                            Button(L("Als Arbeit speichern"), systemImage: "briefcase") { model.updateJournal { $0.work = d } }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 38, height: 38).neutralGlass(19)
                        }
                        .accessibilityLabel(L("Mehr"))
                    }
                }
                if model.isRouting {
                    HStack { ProgressView(); Text(L("Route wird berechnet …")).foregroundStyle(GlassTokens.secondary) }
                }
                ForEach(Array(model.routes.enumerated()), id: \.offset) { i, r in
                    RouteOptionRow(index: i, route: r, selected: i == model.selectedRoute, newShare: model.newShare(of: r)) { model.selectedRoute = i }
                }
                Button(L("Los")) { model.startNavigation() }
                    .buttonStyle(PrimaryGlassButtonStyle(height: 56))
                    .disabled(model.routes.isEmpty)
            }
            .padding(16)
            .glass()
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
}

struct RouteOptionRow: View {
    let index: Int
    let route: Route
    let selected: Bool
    var newShare: Double = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatting.minutes(route.duration)).font(.system(size: 17, weight: .heavy))
                    HStack(spacing: 0) {
                        Text((index == 0 ? L("Schnellste") : String(format: L("Alternative %d"), index)) + " · " + Formatting.distance(route.length)
                             + " · " + String(format: L("an %@"), Formatting.clock(Date().addingTimeInterval(route.duration))))
                    }
                    .font(.system(size: 12.5, weight: .medium)).foregroundStyle(GlassTokens.secondary).lineLimit(1)
                    if newShare >= 0.05 {
                        Text(String(format: L("+%d %% neue Straßen"), Int((newShare * 100).rounded())))
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(GlassTokens.accentLight)
                    }
                }
                Spacer()
                if index == 0 {
                    Text(L("Empfohlen")).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 9).padding(.vertical, 4).neutralGlass(10)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .neutralGlass(16, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Navigation (GM-032 Block 4: Abbiegekarte als Glas, unten kompakte Zeile, Ende als runder Knopf)

struct NavigationHUD: View {
    let model: AppModel

    var body: some View {
        let s = model.nav
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: Self.symbol(for: s?.maneuver?.kind))
                    .font(.system(size: 40, weight: .bold))
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.map { Formatting.distance($0.distanceToManeuver) } ?? "…")
                        .font(.system(size: 38, weight: .heavy)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(Self.street(s)).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glass(GlassTokens.sheet, tint: SwiftUI.Color(red: 124 / 255.0, green: 40 / 255.0, blue: 200 / 255.0))
            .accessibilityElement(children: .combine)

            if let n = model.roadNotice { RoadNoticeBanner(ahead: n) }

            HStack(alignment: .top) {
                if let then = s?.thenManeuver, then.kind != .destination {
                    Text(L("danach") + " " + NavigationSession.lowerFirst(then.text) + (then.street.isEmpty ? "" : " · " + then.street))
                        .font(.footnote.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 7).neutralGlass(12)
                }
                Spacer()
                if model.settings.showSpeedLimit, let limit = s?.speedLimit { SpeedLimitSign(limit: limit) }
            }
            Spacer()
            HStack(alignment: .bottom) {
                if model.isSpeaking && model.settings.duckMusic {
                    Label(L("Musik leiser"), systemImage: "speaker.wave.1").font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 5).neutralGlass(10)
                }
                Spacer()
                VStack(spacing: 10) {
                    // GM-050: Ansagen während der Fahrt aus/an
                    GlassRoundButton(systemImage: model.settings.voice ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                     label: model.settings.voice ? L("Ansagen aus") : L("Ansagen an")) { model.toggleVoice() }
                    GlassRoundButton(systemImage: "location.north.line", label: L("Auf meinen Standort zentrieren")) { model.recenter() }
                }
            }
            HStack { Spacer(); OSMAttribution() }
            HStack(spacing: 12) {
                if let r = model.trialRemaining {
                    let sec = Int(r.rounded(.up))
                    Text(String(format: "%d:%02d", sec / 60, sec % 60)).font(.system(size: 13, weight: .heavy).monospacedDigit())
                        .frame(width: 48, height: 48).neutralGlass(24, selected: true)
                        .accessibilityLabel(L("Test läuft"))
                } else {
                    SwiftUI.Color.clear.frame(width: 48, height: 48)
                }
                VStack(spacing: 2) {
                    Text(s.map { Formatting.clock(Date().addingTimeInterval($0.remainingTime)) } ?? "…")
                        .font(.system(size: 26, weight: .heavy))
                    Text(s.map { Formatting.minutes($0.remainingTime) + " · " + Formatting.distance($0.remainingDistance) } ?? "")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(GlassTokens.secondary)
                }
                .frame(maxWidth: .infinity)
                Button { model.endNavigation() } label: {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(GlassTokens.danger, in: Circle())
                }
                .accessibilityLabel(L("Navigation beenden"))
            }
            .padding(12)
            .glass()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    static func street(_ s: NavigationSession.State?) -> String {
        guard let m = s?.maneuver else { return L("Route wird gestartet …") }
        return m.kind == .destination ? (AppModel.shared.destination?.name ?? "") : (m.street.isEmpty ? m.text : m.street)
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

/// GM-043: Baustelle/Sperrung voraus (Autobahn GmbH) – oranges bzw. rotes Glas unter dem Abbiegehinweis
struct RoadNoticeBanner: View {
    let ahead: RoadNoticeFilter.Ahead
    var body: some View {
        let closed = ahead.notice.label == "Sperrung"
        HStack(spacing: 12) {
            Image(systemName: closed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .heavy))
                .frame(width: 36, height: 36)
                .background(SwiftUI.Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(L(ahead.notice.label) + " " + String(format: L("in %@"), Formatting.distance(ahead.distance)))
                    .font(.system(size: 15, weight: .heavy))
                Text(ahead.notice.summary).font(.system(size: 12.5, weight: .medium)).lineLimit(1).opacity(0.85)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(closed ? SwiftUI.Color.white : SwiftUI.Color(red: 0.1, green: 0.06, blue: 0))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glass(18, tint: closed ? GlassTokens.danger : GlassTokens.warn)
        .accessibilityElement(children: .combine)
    }
}

/// Tempolimit-Schild (Zeichen 274, roter Ring). Ohne Limit (Autobahn): Zeichen 282 „Ende aller Streckenverbote“
/// – weiß mit schwarzen Schrägstreifen (GM-022: vorher „∞“, das gibt es als Verkehrszeichen nicht)
struct SpeedLimitSign: View {
    let limit: Int
    var body: some View {
        Group {
            if limit < 0 {
                Circle().fill(.white)
                    .overlay(EndOfLimitsStripes().stroke(SwiftUI.Color.black, lineWidth: 2.2).clipShape(Circle()).padding(4))
                    .overlay(Circle().stroke(SwiftUI.Color(white: 0.75), lineWidth: 2))
            } else {
                Text(String(limit))
                    .font(.system(size: 26, weight: .heavy))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.black)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(SwiftUI.Color.red, lineWidth: 7))
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityLabel(limit < 0 ? L("Kein Tempolimit") : String(format: L("Tempolimit %d"), limit))
    }
}

/// Fünf parallele Schrägstreifen von unten links nach oben rechts (Zeichen 282)
struct EndOfLimitsStripes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in -2...2 {
            let o: CGFloat = CGFloat(i) * rect.width * 0.085
            p.move(to: CGPoint(x: rect.minX + o, y: rect.maxY + o))
            p.addLine(to: CGPoint(x: rect.maxX + o, y: rect.minY + o))
        }
        return p
    }
}

// MARK: Ankunft (GM-041: Belohnung nur im Stand)

struct ArrivalSheet: View {
    let model: AppModel
    @State private var showReplay = false

    var body: some View {
        VStack {
            Spacer()
            HStack { Spacer(); OSMAttribution() }.padding(.horizontal, 16).padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 12) {
                SheetGrabber()
                Kicker(text: L("Angekommen") + " · " + Formatting.clock(Date()))
                Text(model.destination?.name ?? "").font(.system(size: 28, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.7)
                if let reveal = model.lastReveal, reveal.totalCells > 1 {
                    HStack(spacing: 8) {
                        StatTile(value: "+\(reveal.newPercent) %", label: L("neue Straßen"), hot: true)
                        StatTile(value: Formatting.distance(model.journal.trips.first?.meters ?? Double(reveal.totalCells) * ExploreCell.approxMeters), label: L("gefahren"))
                        StatTile(value: String(format: "%.0f km", model.exploredKm), label: L("entdeckt"))
                    }
                }
                if model.missionJustDone {
                    Label(L("Wochenmission geschafft"), systemImage: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .heavy)).foregroundStyle(GlassTokens.gold)
                }
                if !model.newBadges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.newBadges, id: \.self) { b in BadgeChip(badge: b, earned: true) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    if model.journal.trips.first?.track.count ?? 0 > 1 {
                        Button { showReplay = true } label: { Label(L("Replay"), systemImage: "play.fill") }
                            .buttonStyle(PrimaryGlassButtonStyle(height: 52))
                    }
                    Button(L("Fertig")) { model.endNavigation() }
                        .buttonStyle(GlassButtonStyle(height: 52, radius: 18))
                        .frame(maxWidth: model.journal.trips.first == nil ? .infinity : 110)
                }
            }
            .padding(16)
            .glass()
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showReplay) {
            if let trip = model.journal.trips.first { ReplaySheet(model: model, trip: trip) }
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var hot = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 19, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(hot ? SwiftUI.Color(red: 0.91, green: 0.82, blue: 1) : .white)
                .shadow(color: hot ? GlassTokens.accentLight.opacity(0.9) : .clear, radius: 6)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(GlassTokens.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .neutralGlass(14, selected: hot)
        .accessibilityElement(children: .combine)
    }
}

/// Abzeichen (eigene Namen, keine Spielinhalte)
struct BadgeChip: View {
    let badge: Badge
    var earned: Bool

    var symbol: String {
        switch badge {
        case .firstDrive: return "flag.fill"
        case .km10, .km100, .km1000: return "road.lanes"
        case .nightOwl: return "moon.stars.fill"
        case .earlyBird: return "sunrise.fill"
        case .districtComplete: return "seal.fill"
        case .explorer25, .explorer50, .explorer100: return "safari.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(earned ? SwiftUI.Color(red: 0.1, green: 0.06, blue: 0) : GlassTokens.secondary)
                .frame(width: 32, height: 32)
                .background(earned ? AnyShapeStyle(RadialGradient(colors: [SwiftUI.Color(red: 1, green: 0.95, blue: 0.69), GlassTokens.gold], center: .topLeading, startRadius: 2, endRadius: 30))
                                   : AnyShapeStyle(SwiftUI.Color.white.opacity(0.08)), in: Circle())
            Text(L(badge.title)).font(.system(size: 13, weight: .bold)).foregroundStyle(earned ? .white : GlassTokens.secondary).lineLimit(1)
        }
        .padding(.trailing, 12)
        .padding(4)
        .neutralGlass(20)
    }
}
