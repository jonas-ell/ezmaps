import CarPlay
import UIKit
import MapLibre

/// CarPlay-Szene für Navi-Apps: eigenes Kartenfenster (carWindow) mit der Neon-Karte, darüber CPMapTemplate.
/// Größe kommt immer aus dem Fenster (Autos haben unterschiedliche Bildschirme, LESSONS_SWIFT 6).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window
        window.rootViewController = CarMapViewController()

        let mapTemplate = CPMapTemplate()
        interfaceController.setRootTemplate(mapTemplate, animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        self.carWindow = nil
    }
}

/// Kartenfenster im Auto: flach von oben wie ein Spiel-Radar (Prototyp GM-008), OSM-Hinweis unten rechts.
final class CarMapViewController: UIViewController {
    private var mapView: MLNMapView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0x1c / 255.0, green: 0x1c / 255.0, blue: 0x1d / 255.0, alpha: 1)
        let map = NeonMap.make(frame: view.bounds, zoom: 15)
        map.isPitchEnabled = false
        view.addSubview(map)
        mapView = map

        let label = UILabel()
        label.text = L("© OpenStreetMap-Mitwirkende")
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
        ])
    }
}
