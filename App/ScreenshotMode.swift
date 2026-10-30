import Foundation
import EzMapsCore

/// Nur für App-Store-Screenshots im Simulator (tools/mac_screens.sh): Start mit `-EZShot <zustand>` stellt die App
/// in einen festen Zustand. Ohne dieses Startargument hat der Code keine Wirkung.
/// Zustände: karte, suche, vorschau, navigation, einstellungen, stil
@MainActor
enum ScreenshotMode {
    static var state: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-EZShot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// GM-047: fester Kartenstil für Store-Bilder (`-EZStyle neon-city`) – der Look, mit dem die App wirbt
    static var style: MapStyle? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-EZStyle"), i + 1 < args.count else { return nil }
        return MapStyle(rawValue: args[i + 1])
    }

    /// GM-093: Start-Zoom für Prüfbilder (`-EZZoom 16.5`)
    nonisolated static var zoom: Double? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-EZZoom"), i + 1 < args.count else { return nil }
        return Double(args[i + 1])
    }

    /// Ziel für die Bilder: weit genug weg für eine Route mit Alternativen (Idstein → Frankfurt)
    static let target = PhotonClient.Place(
        name: "Römerberg", subtitle: "Platz · Frankfurt am Main",
        coordinate: Coordinate(latitude: 50.1104, longitude: 8.6822), kind: "square"
    )

    static func run(_ model: AppModel) {
        guard let s = state else { return }
        Task { @MainActor in
            // auf den Standort warten (simctl location set …), höchstens 10 s
            var waited = 0
            while model.currentCoordinate == nil && waited < 40 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                waited += 1
            }
            switch s {
            case "suche":
                model.openSearch()
                model.query = "Römerberg Frankfurt"
                model.queryChanged()
            case "vorschau":
                model.choose(target)
            case "stil":
                // GM-050: Stil-Seite Neon City (Kauf) – Prüf-Screenshot für App Store Connect
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                model.shopRequest = .neonCity
            case "navigation":
                model.updateSettings { $0.demoDrive = true }
                model.demoStartOffset = 5_200 // mitten auf der Strecke (Landstraße bei Niedernhausen)
                model.choose(target)
                var w = 0
                while model.routes.isEmpty && w < 80 {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    w += 1
                }
                model.startNavigation()
            case "ankunft":
                // GM-030: kurz vor dem Ziel starten, damit nach wenigen Sekunden „Ziel erreicht“ kommt
                model.updateSettings { $0.demoDrive = true }
                model.demoStartOffset = .greatestFiniteMagnitude
                model.choose(target)
                var w = 0
                while model.routes.isEmpty && w < 80 {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    w += 1
                }
                model.startNavigation()
            default:
                break
            }
        }
    }
}
