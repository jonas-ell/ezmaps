import SwiftUI

/// Einstellungen, Datenschutz, Impressum, Lizenzen. Alles scrollbar (kleine Bildschirme, LESSONS_SWIFT 2).
struct SettingsScreen: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    private func binding(_ key: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { model.settings[keyPath: key] }, set: { v in model.updateSettings { $0[keyPath: key] = v } })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Navigation")) {
                    Toggle(L("Sprachansagen"), isOn: binding(\.voice))
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
                Section {
                    Toggle(L("Demo-Fahrt"), isOn: binding(\.demoDrive))
                } footer: {
                    Text(L("Fährt die Route nach „Los“ automatisch ab. Zum Ausprobieren ohne Auto, nicht während der echten Fahrt benutzen."))
                }
                Section(L("Datenschutz")) {
                    Text(L("EzMaps speichert keine Fahrten auf Servern und hat kein Konto. Für Suche und Route werden Start, Ziel bzw. Suchbegriff an Kartendienste auf Basis von OpenStreetMap geschickt."))
                        .font(.footnote)
                    Link(L("Datenschutzerklärung und Impressum"), destination: AppConfig.legalURL)
                }
                Section(L("Über")) {
                    LabeledContent(L("Kartendaten"), value: L("© OpenStreetMap-Mitwirkende (ODbL)"))
                    Link(L("OpenStreetMap-Lizenz"), destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    LabeledContent(L("Karte"), value: "OpenFreeMap · MapLibre")
                    LabeledContent(L("Routing und Suche"), value: "Valhalla · Photon")
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
        }
    }
}
