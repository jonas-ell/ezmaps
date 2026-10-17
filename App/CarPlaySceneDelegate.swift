import CarPlay
import UIKit

/// CarPlay-Szene für Navi-Apps: eigenes Kartenfenster (carWindow) plus CPMapTemplate darüber.
/// Noch leer – die Karte kommt in einem späteren Schritt.
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

        let mapViewController = UIViewController()
        mapViewController.view.backgroundColor = .black
        window.rootViewController = mapViewController

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
