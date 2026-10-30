import SceneKit
import SwiftUI
import UIKit

/// GM-086: Pixel Quest ganz herausgezoomt – die Welt als Grasblock-Würfel im Sternenhimmel (Vorher/Nachher freigegeben).
/// Oben die Weltkarte im Pixel-Stil, an den Seiten Erde mit Graskante. Dreht sich langsam, mit dem Finger drehbar;
/// Tippen oder Auseinanderziehen zoomt zurück in die Karte. Texturen: Assets PixelQuest/px-cube-top, -side, -bottom
/// (Platzhalter, bis bessere Grafiken kommen – Prompt in docs/ASSETS_CODEX.md).
struct WorldCubeView: View {
    var onEnter: () -> Void

    var body: some View {
        ZStack {
            StarField()
            CubeScene(onEnter: onEnter)
            VStack(spacing: 10) {
                Spacer()
                Text(L("Weltkarte"))
                    .font(.custom("PressStart2P-Regular", size: 18)).foregroundStyle(.white)
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                Text(L("Heranzoomen zum Betreten"))
                    .font(.custom("PressStart2P-Regular", size: 9)).foregroundStyle(.white.opacity(0.75))
                    .shadow(color: .black, radius: 0, x: 1, y: 1)
            }
            .padding(.bottom, 300)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// Feste Sterne (gleiches Muster bei jedem Öffnen)
private struct StarField: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SwiftUI.Color(red: 18 / 255, green: 22 / 255, blue: 38 / 255)))
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
            }
            for _ in 0..<160 {
                let s: CGFloat = next() < 0.8 ? 1.5 : 3
                ctx.fill(Path(CGRect(x: next() * size.width, y: next() * size.height, width: s, height: s)),
                         with: .color(SwiftUI.Color(red: 0.8, green: 0.84, blue: 1).opacity(0.5 + Double(next()) * 0.5)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CubeScene: UIViewRepresentable {
    var onEnter: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onEnter: onEnter) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        let scene = SCNScene()
        view.scene = scene

        let box = SCNBox(width: 2, height: 2, length: 2, chamferRadius: 0)
        func mat(_ name: String, _ shade: CGFloat) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = UIImage(named: name) ?? UIColor(red: 0.5 * shade, green: 0.36 * shade, blue: 0.25 * shade, alpha: 1)
            m.diffuse.magnificationFilter = .nearest
            m.diffuse.minificationFilter = .nearest
            m.lightingModel = .constant
            m.multiply.contents = UIColor(white: shade, alpha: 1) // feste Schattierung je Seite (Blockspiel-Licht)
            return m
        }
        // Reihenfolge SCNBox: vorne, rechts, hinten, links, oben, unten
        box.materials = [mat("px-cube-side", 0.78), mat("px-cube-side", 0.6), mat("px-cube-side", 0.78),
                         mat("px-cube-side", 0.6), mat("px-cube-top", 1), mat("px-cube-bottom", 0.45)]
        let node = SCNNode(geometry: box)
        node.eulerAngles = SCNVector3(0, Float.pi / 4, 0)
        let tilt = SCNNode()
        tilt.eulerAngles = SCNVector3(0.55, 0, 0) // von schräg oben
        tilt.addChildNode(node)
        scene.rootNode.addChildNode(tilt)
        node.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 40)), forKey: "spin")

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.usesOrthographicProjection = true
        cam.camera?.orthographicScale = 2.6
        cam.position = SCNVector3(0, 0.35, 8)
        scene.rootNode.addChildNode(cam)
        view.pointOfView = cam

        context.coordinator.cube = node
        view.addGestureRecognizer(UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:))))
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap)))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:))))
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) { context.coordinator.onEnter = onEnter }

    final class Coordinator: NSObject {
        var onEnter: () -> Void
        weak var cube: SCNNode?
        private var startY: Float = 0
        init(onEnter: @escaping () -> Void) { self.onEnter = onEnter }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard let cube else { return }
            switch g.state {
            case .began:
                cube.removeAction(forKey: "spin")
                startY = cube.eulerAngles.y
            case .changed:
                cube.eulerAngles.y = startY + Float(g.translation(in: g.view).x) * 0.01
            case .ended, .cancelled:
                cube.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 40)), forKey: "spin")
            default: break
            }
        }

        @objc func tap() { onEnter() }

        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            if g.state == .changed, g.scale > 1.25 { g.isEnabled = false; g.isEnabled = true; onEnter() }
        }
    }
}
