import Foundation
import EzMapsCore

/// Nur für App-Store-Screenshots im Simulator (tools/mac_screens.sh): Start mit `-EZShot <zustand>` stellt die App
/// in einen festen Zustand. Ohne dieses Startargument hat der Code keine Wirkung.
/// Zustände: karte, suche, vorschau, navigation, einstellungen
@MainActor
enum ScreenshotMode {
    static var state: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-EZShot"), i + 1 < args.count else { return nil }
        return args[i + 1]
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
            case "navigation":
                model.updateSettings { $0.demoDrive = true }
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
