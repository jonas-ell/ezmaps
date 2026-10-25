import CoreLocation
import Observation

/// Standort für Karte und Navigation. Während der Navigation läuft der Standort auch im Hintergrund weiter
/// (UIBackgroundModes „location“, blaue Anzeige in der Statusleiste). Nur „Beim Verwenden der App“ wird erfragt.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var location: CLLocation?
    @ObservationIgnored var onUpdate: ((CLLocation) -> Void)?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var backgroundSession: CLBackgroundActivitySession?

    override init() {
        super.init()
        authorization = manager.authorizationStatus // erst nach super.init (self vorher nicht nutzbar)
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
    }

    var isAllowed: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func requestPermission() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if isAllowed { manager.startUpdatingLocation() }
    }

    /// Navigation an/aus: genauer, im Hintergrund weiter, nicht automatisch pausieren
    func setNavigating(_ on: Bool) {
        manager.desiredAccuracy = on ? kCLLocationAccuracyBestForNavigation : kCLLocationAccuracyBest
        manager.pausesLocationUpdatesAutomatically = !on
        if on {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            if backgroundSession == nil { backgroundSession = CLBackgroundActivitySession() }
        } else {
            backgroundSession?.invalidate()
            backgroundSession = nil
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
        }
        if isAllowed { manager.startUpdatingLocation() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.location = last
            self.onUpdate?(last)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAllowed { self.manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Kurze Aussetzer (Tunnel) sind normal – die Navigation rechnet mit der letzten Position weiter
    }
}
