import AVFoundation
import SwiftUI
import StoreKit
import EzMapsCore

/// Einstellungen, Datenschutz, Impressum, Lizenzen. Alles scrollbar (kleine Bildschirme, LESSONS_SWIFT 2).
/// GM-043: Stil oben, Stimme und Sprechtempo, Zuhause/Arbeit/Favoriten, Entdecken, Käufe, Quellen.
struct SettingsScreen: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var manageSubs = false

    private func binding(_ key: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { model.settings[keyPath: key] }, set: { v in model.updateSettings { $0[keyPath: key] = v } })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { StylePickerList(model: model) } label: {
                        HStack(spacing: 12) {
                            StyleSwatch(style: model.activeStyle).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                StyleName(style: model.activeStyle, size: 18)
                                Text(L("Stil ändern")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section(L("Navigation")) {
                    Toggle(L("Sprachansagen"), isOn: binding(\.voice))
                    Picker(L("Stimme"), selection: Binding(get: { model.settings.voiceIdentifier ?? "" },
                                                         set: { v in model.updateSettings { $0.voiceIdentifier = v.isEmpty ? nil : v } })) {
                        Text(L("Automatisch (beste)")).tag("")
                        ForEach(SpeechService.germanVoices, id: \.identifier) { v in
                            Text(v.name + Self.quality(v)).tag(v.identifier)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(L("Sprechtempo"))
                        Slider(value: Binding(get: { model.settings.speechRate }, set: { v in model.updateSettings { $0.speechRate = v } }), in: 0.8...1.2, step: 0.05) {
                            Text(L("Sprechtempo"))
                        } minimumValueLabel: { Image(systemName: "tortoise") } maximumValueLabel: { Image(systemName: "hare") }
                    }
                    Toggle(isOn: binding(\.duckMusic)) {
                        VStack(alignment: .leading) {
                            Text(L("Musik bei Ansagen leiser"))
                            Text(L("statt sie zu unterbrechen")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(L("Tempolimit anzeigen"), isOn: binding(\.showSpeedLimit))
                }
                Section(L("Route")) {
                    Toggle(L("Autobahn meiden"), isOn: binding(\.avoidHighway))
                    Toggle(L("Maut meiden"), isOn: binding(\.avoidToll))
                }
                Section(L("Orte")) {
                    NavigationLink { PlacePicker(model: model, title: L("Zuhause")) { p in model.updateJournal { $0.home = p } } } label: {
                        LabeledContent(L("Zuhause"), value: model.journal.home?.name ?? L("Nicht festgelegt"))
                    }
                    NavigationLink { PlacePicker(model: model, title: L("Arbeit")) { p in model.updateJournal { $0.work = p } } } label: {
                        LabeledContent(L("Arbeit"), value: model.journal.work?.name ?? L("Nicht festgelegt"))
                    }
                    if !model.journal.favorites.isEmpty {
                        NavigationLink { FavoritesList(model: model) } label: {
                            LabeledContent(L("Favoriten"), value: "\(model.journal.favorites.count)")
                        }
                    }
                }
                Section {
                    NavigationLink(L("Meine Fahrten")) { TripsScreen(model: model) }
                    Toggle(L("Fahrten speichern"), isOn: Binding(get: { model.journal.keepTrips }, set: { v in model.updateJournal { $0.keepTrips = v } }))
                    Button(L("Entdeckte Karte zurücksetzen"), role: .destructive) { confirmReset = true }
                } header: { Text(L("Entdecken")) } footer: {
                    Text(L("Aufgedeckte Straßen und Fahrten bleiben nur auf diesem iPhone."))
                }
                Section(L("Käufe")) {
                    LabeledContent(L("EzMaps Plus"), value: model.purchases.access.hasPlus ? L("aktiv") : L("nicht aktiv"))
                    Button(L("Käufe wiederherstellen")) { Task { await model.purchases.restore() } }
                    if model.purchases.testMode {
                        Button(L("Testkäufe zurücksetzen"), role: .destructive) { model.purchases.resetTestPurchases() }
                    }
                    Button(L("Abo verwalten")) { manageSubs = true }
                }
                Section {
                    Toggle(L("Demo-Fahrt"), isOn: binding(\.demoDrive))
                } footer: {
                    Text(L("Fährt die Route nach „Los“ automatisch ab. Zum Ausprobieren ohne Auto, nicht während der echten Fahrt benutzen."))
                }
                Section(L("Datenschutz")) {
                    Text(L("EzMaps hat kein Konto. Fahrten und aufgedeckte Straßen bleiben auf dem iPhone. Für Suche und Route werden Start, Ziel bzw. Suchbegriff an Kartendienste auf Basis von OpenStreetMap geschickt. Die Testzeit der Stile liegt im Schlüsselbund und in deiner iCloud."))
                        .font(.footnote)
                    Link(L("Datenschutzerklärung und Impressum"), destination: AppConfig.legalURL)
                }
                Section(L("Über")) {
                    LabeledContent(L("Kartendaten"), value: L("© OpenStreetMap-Mitwirkende (ODbL)"))
                    Link(L("OpenStreetMap-Lizenz"), destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    LabeledContent(L("Karte"), value: "OpenFreeMap · MapLibre")
                    LabeledContent(L("Routing und Suche"), value: "Valhalla · Photon")
                    LabeledContent(L("Verkehrsdaten"), value: L("Autobahn GmbH des Bundes"))
                    LabeledContent(L("Schriften"), value: "Rye · Press Start 2P · Fredoka · Anton (OFL)")
                    LabeledContent(L("Version"), value: AppConfig.version)
                }
                Section {
                    Text(L("Achte immer auf den Verkehr. Bediene die App nicht während der Fahrt. Verkehrszeichen gehen vor."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } } }
            .confirmationDialog(L("Entdeckte Karte zurücksetzen?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L("Zurücksetzen"), role: .destructive) { model.resetExploration() }
            } message: {
                Text(L("Alle aufgedeckten Straßen und Abzeichen werden gelöscht. Käufe und Testzeit bleiben."))
            }
            .manageSubscriptionsSheet(isPresented: $manageSubs)
        }
    }

    static func quality(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .premium: return " · " + L("Premium")
        case .enhanced: return " · " + L("Erweitert")
        default: return ""
        }
    }
}

/// Stil wählen (in den Einstellungen): freigeschaltet → benutzen, sonst Stil-Seite (Plus, Einzelkauf, Test)
struct StylePickerList: View {
    let model: AppModel

    var body: some View {
        List {
            ForEach(MapStyle.allCases, id: \.self) { s in
                NavigationLink {
                    StyleDetailView(model: model, style: s, onDone: {})
                } label: {
                    HStack(spacing: 12) {
                        StyleSwatch(style: s).frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            StyleName(style: s, size: 16)
                            Text(L(s.subtitleKey)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.activeStyle == s {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(GlassTokens.ok)
                        } else if !model.isUnlocked(s) {
                            Text(L("Plus")).font(.caption.weight(.heavy)).padding(.horizontal, 7).padding(.vertical, 3)
                                .background(GlassTokens.gold, in: RoundedRectangle(cornerRadius: 7, style: .continuous)).foregroundStyle(.black)
                        }
                    }
                }
            }
        }
        .navigationTitle(L("Stile"))
    }
}

/// Ort suchen und übernehmen (Zuhause/Arbeit)
struct PlacePicker: View {
    let model: AppModel
    let title: String
    let pick: (PhotonClient.Place) -> Void
    @State private var query = ""
    @State private var results: [PhotonClient.Place] = []
    @State private var task: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(results, id: \.self) { p in
                Button {
                    pick(p)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).foregroundStyle(.primary)
                        Text(p.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(L("Adresse suchen")))
        .onChange(of: query) {
            task?.cancel()
            let q = query
            task = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                let found = await model.searchPlaces(q)
                guard !Task.isCancelled else { return }
                results = found
            }
        }
        .navigationTitle(title)
    }
}

struct FavoritesList: View {
    let model: AppModel
    var body: some View {
        List {
            ForEach(model.journal.favorites, id: \.self) { p in
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name)
                    Text(p.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .onDelete { idx in model.updateJournal { j in j.favorites.remove(atOffsets: idx) } }
        }
        .navigationTitle(L("Favoriten"))
        .toolbar { EditButton() }
    }
}
