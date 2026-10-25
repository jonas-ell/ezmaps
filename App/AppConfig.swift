import Foundation
import EzMapsCore

/// Server-Adressen und Kennung der App. Kommen aus der Info.plist (project.yml), damit wir vor dem Start
/// auf eigene Server umstellen können, ohne Code zu ändern (docs/KARTENDATEN.md, docs/VEROEFFENTLICHUNG.md).
enum AppConfig {
    static var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }

    static var valhallaURL: URL { url("EZValhallaURL", fallback: "https://valhalla1.openstreetmap.de") }
    static var photonURL: URL { url("EZPhotonURL", fallback: "https://photon.komoot.io") }
    /// Seite mit Datenschutzerklärung und Impressum (GitHub Pages aus docs/legal/)
    static var legalURL: URL { url("EZLegalURL", fallback: "https://jonas-ell.github.io/ezmaps/legal/") }

    /// Erkennbare Kennung für die öffentlichen OSM-Dienste (deren Nutzungsregeln verlangen das)
    static var userAgent: String { "EzMaps/\(version) (iOS; https://github.com/jonas-ell/ezmaps)" }

    static var http: URLSessionHTTPClient { URLSessionHTTPClient(userAgent: userAgent) }

    private static func url(_ key: String, fallback: String) -> URL {
        if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String, !s.isEmpty, let u = URL(string: s) { return u }
        return URL(string: fallback)!
    }
}
