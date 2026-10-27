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
                        .disabled(store.isBusy || store.products[plan] == nil)
                        .padding(.top, 4)

                        Text(fineText).font(.system(size: 11)).foregroundStyle(GlassTokens.secondary).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    if let e = store.errorText { Text(e).font(.footnote).foregroundStyle(GlassTokens.danger) }

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

/// Echte MapLibre-Karte im Stil (Stil-Seite), nicht bedienbar
struct StylePreviewMap: UIViewRepresentable {
    let style: MapStyle
    func makeUIView(context: Context) -> MLNMapView {
        let center = AppModel.shared.currentCoordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } ?? MapStyleResource.idstein
        let map = NeonMap.make(zoom: 15.2, style: style)
        map.setCenter(center, zoomLevel: 15.2, animated: false)
        map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        let cam = map.camera
        cam.pitch = 45
        map.setCamera(cam, animated: false)
        return map
    }
    func updateUIView(_ map: MLNMapView, context: Context) {}
}

/// GM-039: Stil-Seite – Plus oben (besser), Einzelkauf darunter (teuer). Oder „10 Minuten testen“, solange noch Zeit da ist.
struct StyleDetailView: View {
    let model: AppModel
    let style: MapStyle
    var onDone: () -> Void

    private var store: PurchaseManager { model.purchases }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomLeading) {
                    StylePreviewMap(style: style)
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        StyleName(style: style, size: 34)
                        Text(L(style.subtitleKey) + " · " + L("auch in CarPlay")).font(.system(size: 14, weight: .semibold)).opacity(0.85)
                    }
                    .padding(16)
                }
                .frame(height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if model.isUnlocked(style) {
                    Button(model.activeStyle == style ? L("Aktiv") : L("Diesen Stil benutzen")) {
                        model.selectStyle(style)
                        onDone()
                    }
                    .buttonStyle(PrimaryGlassButtonStyle(height: 56))
                    .disabled(model.activeStyle == style)
                } else {
                    PlanRow(title: L("Mit Plus"), sub: L("alle Stile + jeder neue Stil"), price: store.yearlyPerMonth ?? "–", per: L("pro Monat"),
                            tag: L("Besser · alle Stile"), selected: true) {}
                        .padding(.top, 8)
                    Button(L("Plus holen")) {
                        Task {
                            if await store.purchase(ProductID.yearly) { model.purchaseCompleted(for: style); onDone() }
                        }
                    }
                    .buttonStyle(PrimaryGlassButtonStyle(height: 56))
                    .disabled(store.isBusy)
                    if let id = ProductID.single(style) {
                        Button {
                            Task {
                                if await store.purchase(id) { model.purchaseCompleted(for: style); onDone() }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(L("Nur"))
                                StyleName(style: style, size: 15)
                                Text("· " + (store.price(id) ?? "–") + " " + L("einmalig"))
                            }
                        }
                        .buttonStyle(GlassButtonStyle(height: 52, radius: 18))
                        .disabled(store.isBusy)
                    }
                    if model.trial.canStart(style.trialKey) {
                        Button(String(format: L("%@ 10 Minuten testen"), L(style.titleKey))) {
                            model.selectStyle(style)
                            onDone()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GlassTokens.accentLight)
                        .frame(maxWidth: .infinity)
                    }
                    Text(L("Einzelkauf gehört dir für immer, nur dieser Stil. Wer später Plus nimmt, behält den Stil."))
                        .font(.system(size: 11)).foregroundStyle(GlassTokens.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
            }
            .padding(18)
        }
        .background(SwiftUI.Color(red: 11 / 255.0, green: 11 / 255.0, blue: 13 / 255.0).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
