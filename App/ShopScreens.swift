import CoreLocation
import SwiftUI
import UIKit
import MapLibre
import EzMapsCore

/// GM-043: Shop „EzMaps Plus“ (GM-038), Stil-Seite mit Einzelkauf (GM-039), „Test vorbei“ (GM-041). Kein Gratis-Zeitraum (GM-042).
/// Apple 3.1.2: Preis, Laufzeit und Verlängerung direkt über dem Knopf, Bedingungen, Datenschutz, Wiederherstellen.
struct ShopScreen: View {
    let model: AppModel
    /// Stil, über den der Shop geöffnet wurde (öffnet direkt dessen Stil-Seite)
    var focus: MapStyle?
    @State private var plan = ProductID.yearly
    @State private var detail: MapStyle?
    @Environment(\.dismiss) private var dismiss

    private var store: PurchaseManager { model.purchases }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("EzMaps").font(.system(size: 28, weight: .heavy))
                        Text("Plus").font(.system(size: 28, weight: .heavy)).foregroundStyle(GlassTokens.accentLight)
                    }
                    Text(L("Alle Stile, auf dem iPhone und in CarPlay. Jeder neue Stil inklusive."))
                        .font(.subheadline).foregroundStyle(GlassTokens.secondary)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(MapStyle.allCases.filter { !$0.isFree }, id: \.self) { s in
                            Button { detail = s } label: { StyleTile(style: s, unlocked: model.isUnlocked(s), active: model.activeStyle == s) }
                                .buttonStyle(.plain)
                        }
                    }

                    if store.access.hasPlus {
                        Label(L("Plus ist aktiv"), systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(GlassTokens.ok)
                    } else {
                        PlanRow(title: L("Für immer"), sub: L("einmal zahlen"), price: store.price(ProductID.lifetime) ?? "–", per: nil,
                                tag: nil, selected: plan == ProductID.lifetime) { plan = ProductID.lifetime }
                            .padding(.top, 6)
                        PlanRow(title: L("Jährlich"), sub: String(format: L("%@ im Jahr"), store.price(ProductID.yearly) ?? "–"),
                                price: store.yearlyPerMonth ?? "–", per: L("pro Monat"),
                                tag: store.savingsPercent > 0 ? String(format: L("Beliebt · spare %d %%"), store.savingsPercent) : L("Beliebt"),
                                selected: plan == ProductID.yearly) { plan = ProductID.yearly }
                            .padding(.top, 8)
                        PlanRow(title: L("Monatlich"), sub: L("jederzeit kündbar"), price: store.price(ProductID.monthly) ?? "–", per: L("pro Monat"),
                                tag: nil, selected: plan == ProductID.monthly) { plan = ProductID.monthly }

                        Button(ctaTitle) {
                            Task {
                                if await store.purchase(plan) {
                                    model.purchaseCompleted(for: focus)
                                    dismiss()
                                }
                            }
                        }
                        .buttonStyle(PrimaryGlassButtonStyle(height: 56))
                        .disabled(store.isBusy || !store.canBuy(plan))
                        .padding(.top, 4)

                        Text(fineText).font(.system(size: 11)).foregroundStyle(GlassTokens.secondary).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    if let e = store.errorText { Text(e).font(.footnote).foregroundStyle(GlassTokens.danger) }
                    if store.testMode { TestModeNote() }

                    VStack(spacing: 10) {
                        Button(L("Nur einen Stil kaufen ›")) { detail = focus ?? .neonCity }
                        Button(L("Käufe wiederherstellen")) { Task { await store.restore() } }
                        HStack(spacing: 14) {
                            Link(L("Bedingungen"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Link(L("Datenschutz"), destination: AppConfig.legalURL)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GlassTokens.accentLight)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .background(SwiftUI.Color(red: 11 / 255.0, green: 11 / 255.0, blue: 13 / 255.0).ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { GlassRoundButton(systemImage: "xmark", label: L("Schließen"), size: 34) { dismiss() } } }
            .navigationDestination(item: $detail) { s in StyleDetailView(model: model, style: s, onDone: { dismiss() }) }
            .onAppear { if let f = focus { detail = f } }
        }
    }

    private var ctaTitle: String {
        switch plan {
        case ProductID.yearly: return L("Jährlich starten")
        case ProductID.monthly: return L("Monatlich starten")
        default: return L("Für immer freischalten")
        }
    }

    private var fineText: String {
        switch plan {
        case ProductID.yearly:
            return String(format: L("%@ pro Jahr, verlängert sich automatisch. Kündigen jederzeit in den iPhone-Einstellungen, spätestens 24 h vor Ablauf. Klassik und Navigation bleiben gratis."), store.price(ProductID.yearly) ?? "–")
        case ProductID.monthly:
            return String(format: L("%@ pro Monat, verlängert sich automatisch. Kündigen jederzeit in den iPhone-Einstellungen, spätestens 24 h vor Ablauf. Klassik und Navigation bleiben gratis."), store.price(ProductID.monthly) ?? "–")
        default:
            return L("Einmal zahlen, kein Abo. Gilt für iPhone und CarPlay, auch für künftige Stile.")
        }
    }
}

/// Stil-Kachel: echte Kartenfarben als Vorschau, Name in der Stil-Schrift
struct StyleTile: View {
    let style: MapStyle
    var unlocked: Bool
    var active: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            StyleSwatch(style: style)
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            StyleName(style: style, size: 15).padding(10)
        }
        .frame(height: 138)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if unlocked {
                Image(systemName: active ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    .padding(6).background(GlassTokens.ok, in: Circle()).padding(8)
            }
        }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(active ? GlassTokens.accent : .white.opacity(0.16), lineWidth: active ? 2 : 0.5) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L(style.titleKey))
    }
}

/// Kleine Vorschau aus den Stilfarben (schnell, ohne Karte): Boden, Häuserblöcke, Straße, Route
struct StyleSwatch: View {
    let style: MapStyle
    var body: some View {
        // GM-045: Stil-Bild von Codex (Assets/Generated/StyleTiles), gezeichnete Fläche nur als Ersatz
        if UIImage(named: "style-" + style.rawValue) != nil {
            SwiftUI.Color.clear.overlay(Image("style-" + style.rawValue).resizable().scaledToFill()).clipped()
        } else {
            drawn
        }
    }

    private var drawn: some View {
        let t = StyleTheme.of(style)
        return Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SwiftUI.Color(uiColor: t.background)))
            let block = SwiftUI.Color(uiColor: t.background).opacity(0.2)
            for i in 0..<9 {
                let x = CGFloat(i % 3) * size.width / 3 + 8, y = CGFloat(i / 3) * size.height / 3 + 8
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: size.width / 3 - 16, height: size.height / 3 - 16), cornerRadius: 4),
                         with: .color(t.isLight ? SwiftUI.Color.black.opacity(0.12) : block))
            }
            var road = Path()
            road.move(to: CGPoint(x: 0, y: size.height * 0.66))
            road.addLine(to: CGPoint(x: size.width, y: size.height * 0.62))
            road.move(to: CGPoint(x: size.width * 0.34, y: 0))
            road.addLine(to: CGPoint(x: size.width * 0.38, y: size.height))
            ctx.stroke(road, with: .color(t.isLight ? .white : SwiftUI.Color(white: 0.9)), lineWidth: 7)
            var route = Path()
            route.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.66))
            route.addLine(to: CGPoint(x: size.width * 0.36, y: size.height * 0.64))
            route.addLine(to: CGPoint(x: size.width * 0.37, y: size.height * 0.2))
            route.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.25))
            ctx.stroke(route, with: .color(SwiftUI.Color(uiColor: t.routeEdge)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            ctx.stroke(route, with: .color(SwiftUI.Color(uiColor: t.route)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Echte MapLibre-Karte im Stil (Stil-Seite), nicht bedienbar. GM-050: flach von oben wie in CarPlay, mit Pfeil
struct StylePreviewMap: UIViewRepresentable {
    let style: MapStyle
    func makeCoordinator() -> Coordinator { Coordinator() }
    /// GM-072: Symbole und Muster anmelden (vorher grüne Kästen ohne Texturen auf der Stil-Seite)
    final class Coordinator: NSObject, MLNMapViewDelegate {
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            MainActor.assumeIsolated { RouteOverlay.registerImages(style) }
        }
    }
    func makeUIView(context: Context) -> MLNMapView {
        let center = AppModel.shared.currentCoordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } ?? MapStyleResource.idstein
        let map = NeonMap.make(zoom: 16.2, style: style)
        map.setCenter(center, zoomLevel: 16.2, animated: false)
        map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        map.compassView.isHidden = true
        map.delegate = context.coordinator
        let cam = map.camera
        cam.pitch = RouteOverlay.pitch(for: style) // GM-072: Pixel Quest schräg wie in der App
        map.setCamera(cam, animated: false)
        return map
    }
    func updateUIView(_ map: MLNMapView, context: Context) {}
}

/// GM-050: Stil-Seite neu (Nutzer: „Plus holen sieht sehr trocken aus“) – großes Vorschaubild wie im Auto,
/// was man bekommt, zwei wählbare Angebote (Plus hervorgehoben, Einzelkauf), ein Knopf passend zur Wahl, Test als eigener Knopf.
/// Apple 3.1.2: Preis, Laufzeit und Verlängerung stehen direkt unter dem Knopf.
struct StyleDetailView: View {
    let model: AppModel
    let style: MapStyle
    var onDone: () -> Void
    @State private var choosePlus = true

    private var store: PurchaseManager { model.purchases }
    private var singleID: String? { ProductID.single(style) }
    private var accent: SwiftUI.Color { SwiftUI.Color(uiColor: StyleTheme.of(style).route) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                features
                if model.isUnlocked(style) {
                    Button(model.activeStyle == style ? L("Aktiv") : L("Diesen Stil benutzen")) {
                        model.selectStyle(style)
                        onDone()
                    }
                    .buttonStyle(PrimaryGlassButtonStyle(height: 56))
                    .disabled(model.activeStyle == style)
                } else {
                    offers
                    Button(action: buy) {
                        HStack(spacing: 6) {
                            if store.isBusy { ProgressView().tint(.white) }
                            if choosePlus { Text(L("Plus holen")) } else { Text(L("Kaufen")); StyleName(style: style, size: 17) }
                        }
                    }
                    .buttonStyle(PrimaryGlassButtonStyle(height: 58))
                    .disabled(store.isBusy || !store.canBuy(choosePlus ? ProductID.yearly : (singleID ?? "")))
                    Text(fineText).font(.system(size: 11)).foregroundStyle(GlassTokens.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    if model.trial.canStart(style.trialKey) {
                        Button {
                            model.selectStyle(style)
                            onDone()
                        } label: {
                            Label(String(format: L("%@ 10 Minuten kostenlos testen"), L(style.titleKey)), systemImage: "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .overlay(Capsule().strokeBorder(accent.opacity(0.8), lineWidth: 1.5))
                        }
                        .foregroundStyle(.white)
                    }
                    if store.testMode { TestModeNote() }
                    if let e = store.errorText { Text(e).font(.footnote).foregroundStyle(GlassTokens.danger).frame(maxWidth: .infinity) }
                }
            }
            .padding(18)
        }
        .background(SwiftUI.Color(red: 11 / 255.0, green: 11 / 255.0, blue: 13 / 255.0).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Großes Vorschaubild: echte Karte im Stil, Pfeil, Name in der Stil-Schrift
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            StylePreviewMap(style: style)
            Image(uiImage: style == .neonCity ? (UIImage(named: "PlayerNeonGlow") ?? RouteOverlay.arrowImage()) : PlayerMarker.images(for: style).plain) // GM-072: Marker des Stils
                .resizable().interpolation(style == .pixelQuest ? .none : .high).frame(width: 54, height: 54)
                .frame(maxWidth: .infinity, maxHeight: .infinity).offset(y: 30)
            LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Label(L("Auch in CarPlay"), systemImage: "car.fill")
                    .font(.system(size: 12, weight: .heavy)).textCase(.uppercase)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                Spacer()
                StyleName(style: style, size: 40)
                Text(L(style.subtitleKey)).font(.system(size: 15, weight: .semibold)).opacity(0.9)
            }
            .padding(16)
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(accent.opacity(0.55), lineWidth: 1.5))
        .shadow(color: accent.opacity(0.35), radius: 18, y: 8)
    }

    /// Was man bekommt
    private var features: some View {
        HStack(spacing: 8) {
            feature("map.fill", L("Eigene Karte"))
            feature("mappin.and.ellipse", L("Eigenes Ziel"))
            feature("car.fill", "CarPlay")
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(accent).frame(height: 22) // GM-051: gleich hoch
            Text(text).font(.system(size: 11.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).frame(height: 64)
        .background(SwiftUI.Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Zwei Angebote nebeneinander
    private var offers: some View {
        HStack(spacing: 10) {
            OfferCard(selected: choosePlus, accent: GlassTokens.accent, badge: L("Bester Deal"),
                      title: Text("Plus"), sub: L("alle 6 Stile + jeder neue"),
                      price: store.yearlyPerMonth ?? "–", per: L("pro Monat"),
                      note: String(format: L("%@ im Jahr"), store.price(ProductID.yearly) ?? "–")) { choosePlus = true }
            if let id = singleID {
                OfferCard(selected: !choosePlus, accent: accent, badge: nil,
                          title: Text(L("Nur dieser Stil")), sub: L("gehört dir für immer"),
                          price: store.price(id) ?? "–", per: L("einmalig"), note: L("kein Abo")) { choosePlus = false }
            }
        }
    }

    private var fineText: String {
        if choosePlus {
            return String(format: L("%@ pro Jahr, verlängert sich automatisch. Kündigen jederzeit in den iPhone-Einstellungen, spätestens 24 h vor Ablauf. Klassik und Navigation bleiben gratis."), store.price(ProductID.yearly) ?? "–")
        }
        return L("Einzelkauf gehört dir für immer, nur dieser Stil. Wer später Plus nimmt, behält den Stil.")
    }

    private func buy() {
        let id = choosePlus ? ProductID.yearly : (singleID ?? ProductID.yearly)
        Task { if await store.purchase(id) { model.purchaseCompleted(for: style); onDone() } }
    }
}

/// GM-050: wählbares Angebot (Stil-Seite)
struct OfferCard: View {
    let selected: Bool
    let accent: SwiftUI.Color
    let badge: String?
    let title: Text
    let sub: String
    let price: String
    let per: String
    let note: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    title.font(.system(size: 17, weight: .heavy))
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? accent : .white.opacity(0.35))
                }
                Text(sub).font(.system(size: 11.5)).foregroundStyle(GlassTokens.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Text(price).font(.system(size: 24, weight: .heavy)).minimumScaleFactor(0.7).lineLimit(1)
                Text(per).font(.system(size: 11, weight: .semibold)).foregroundStyle(GlassTokens.secondary)
                Text(note).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? AnyShapeStyle(LinearGradient(colors: [accent.opacity(0.45), accent.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                   : AnyShapeStyle(SwiftUI.Color.white.opacity(0.06)))
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selected ? accent : .white.opacity(0.12), lineWidth: selected ? 2.5 : 1))
            .overlay(alignment: .topLeading) {
                if let b = badge {
                    Text(b).font(.system(size: 10, weight: .heavy)).textCase(.uppercase)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(GlassTokens.gold, in: Capsule()).foregroundStyle(.black)
                        .offset(x: 12, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Plan-Zeile (Für immer / Jährlich / Monatlich)
struct PlanRow: View {
    let title: String
    let sub: String
    let price: String
    let per: String?
    let tag: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .heavy))
                    Text(sub).font(.system(size: 12, weight: .medium)).foregroundStyle(selected ? SwiftUI.Color(red: 0.85, green: 0.76, blue: 0.94) : GlassTokens.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price).font(.system(size: 16, weight: .heavy))
                    if let per { Text(per).font(.system(size: 12)).foregroundStyle(GlassTokens.secondary) }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .neutralGlass(16, selected: selected)
            .overlay(alignment: .topLeading) {
                if let tag {
                    Text(tag).font(.system(size: 10.5, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(GlassTokens.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .offset(x: 12, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// GM-041: Test vorbei – zurück in Klassik, Angebot ohne Druck
struct TrialEndedSheet: View {
    let model: AppModel
    let style: MapStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                StyleSwatch(style: style).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Kicker(text: L("Test vorbei"))
                    HStack(spacing: 6) { StyleName(style: style, size: 19); Text(L("behalten?")).font(.system(size: 19, weight: .heavy)) }
                    Text(L("Du bist jetzt wieder in Klassik.")).font(.subheadline).foregroundStyle(GlassTokens.secondary)
                }
            }
            Button(L("Plus holen")) { dismiss(); open(.classic) }
                .buttonStyle(PrimaryGlassButtonStyle(height: 54))
            if let id = ProductID.single(style) {
                Button(L("Nur diesen Stil") + " · " + (model.purchases.price(id) ?? "–")) { dismiss(); open(style) }
                    .buttonStyle(GlassButtonStyle(height: 48, radius: 16))
            }
            Button(L("Später")) { dismiss() }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(GlassTokens.accentLight).frame(maxWidth: .infinity)
        }
        .padding(20)
        .presentationBackground(.ultraThinMaterial)
    }

    /// Shop erst öffnen, wenn dieses Blatt zu ist (zwei Blätter gleichzeitig zeigt SwiftUI nicht)
    private func open(_ s: MapStyle) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { model.shopRequest = s }
    }
}

/// GM-050: Hinweis im Test-Modus – Käufe sind nur simuliert
struct TestModeNote: View {
    var body: some View {
        Label(L("Testkauf: kein echtes Geld, nur auf diesem Gerät"), systemImage: "testtube.2")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(GlassTokens.gold)
            .frame(maxWidth: .infinity)
    }
}
