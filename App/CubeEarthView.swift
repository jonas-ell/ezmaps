import SceneKit
import UIKit
import CoreLocation
import EzMapsCore

/// GM-074: Pixel Quest – ganz rausgezoomt wird die Erde ein großer Block-Würfel (Nutzer-Wunsch).
/// Netz kommt aus Core (`CubeEarth`, getestet), Design aus tools/prototype/wuerfel.html.
/// Ziehen dreht (Norden bleibt oben), Tippen fliegt zur Stelle, Aufziehen (Pinch) zurück zur Karte an der Mitte.
final class CubeEarthView: UIView {
    static let n = 48
    /// Gewählte Stelle → Karte dorthin
    var onPick: (@MainActor (CLLocationCoordinate2D) -> Void)?

    private let stars = UIImageView()
    private let scn = SCNView()
    private let earth = SCNNode()
    private let world = SCNNode()
    private let clouds = SCNNode()
    private let camera = SCNNode()
    private var pitch = 0.0, yaw = 0.0, spin = 0.0
    private var idleSince = CACurrentMediaTime()
    private var last = CACurrentMediaTime()
    private var link: CADisplayLink?

    /// Netz einmal bauen (~60 000 Vierecke), danach wiederverwenden
    private static let meshes: (world: SCNGeometry, clouds: SCNGeometry) = {
        let blocks = CubeEarth.blocks(n: n)
        return (geometry(CubeEarth.mesh(n: n, blocks: blocks), clouds: false), geometry(CubeEarth.clouds(n: n), clouds: true))
    }()

    init(frame: CGRect, center: Coordinate, home: Coordinate?) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0x0b / 255.0, green: 0x10 / 255.0, blue: 0x30 / 255.0, alpha: 1)
        stars.image = Self.starfield()
        stars.contentMode = .scaleAspectFill
        stars.layer.magnificationFilter = .nearest
        stars.frame = bounds
        stars.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(stars)

        let scene = SCNScene()
        world.geometry = Self.meshes.world
        clouds.geometry = Self.meshes.clouds
        earth.addChildNode(world)
        earth.addChildNode(clouds)
        if let home { earth.addChildNode(Self.pin(at: home)) }
        scene.rootNode.addChildNode(earth)

        let cam = SCNCamera()
        cam.fieldOfView = 30 // senkrecht
        cam.zNear = 0.1
        cam.zFar = 80
        camera.camera = cam
        scene.rootNode.addChildNode(camera)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 650
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.look(at: SCNVector3(3, -4, -5)) // Licht von links oben vorn wie im Prototyp
        scene.rootNode.addChildNode(sun)

        scn.scene = scene
        scn.backgroundColor = .clear
        scn.antialiasingMode = .multisampling4X
        scn.rendersContinuously = true
        scn.frame = bounds
        scn.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(scn)

        (pitch, yaw) = CubeEarth.facing(center)
        apply()
        scn.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
        scn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
        scn.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
        accessibilityLabel = L("Erde als Würfel. Tippen, um hinzufliegen.")
    }

    required init?(coder: NSCoder) { fatalError("nicht benutzt") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Abstand so, dass der Würfel groß ist und fast ganz in die Breite passt (gleiche Formel im Prototyp)
        let aspect = bounds.height > 0 ? min(1, Double(bounds.width / bounds.height)) : 0.46
        camera.position = SCNVector3(0, 0, Float(1.6 / (tan(15 * Double.pi / 180) * aspect)))
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, link == nil {
            let l = CADisplayLink(target: WeakTarget(self), selector: #selector(WeakTarget.tick))
            l.add(to: .main, forMode: .common)
            link = l
            last = CACurrentMediaTime()
        } else if window == nil {
            link?.invalidate()
            link = nil
        }
    }

    fileprivate func tick() {
        let now = CACurrentMediaTime(), dt = min(0.05, now - last)
        last = now
        if now - idleSince > 3 { yaw -= dt * 0.12 } // dreht sich langsam weiter, wenn man nichts macht
        spin += dt * 0.03
        apply()
    }

    private func apply() {
        earth.eulerAngles = SCNVector3(Float(pitch), Float(yaw), 0)
        clouds.eulerAngles.y = Float(spin)
    }

    @objc private func pan(_ g: UIPanGestureRecognizer) {
        let d = g.translation(in: scn)
        g.setTranslation(.zero, in: scn)
        yaw += Double(d.x) * 0.008
        pitch = max(-1.4, min(1.4, pitch + Double(d.y) * 0.008))
        idleSince = CACurrentMediaTime()
        apply()
    }

    @objc private func tap(_ g: UITapGestureRecognizer) {
        let hits = scn.hitTest(g.location(in: scn), options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
        guard let hit = hits.first(where: { $0.node === world }) else { return }
        let p = hit.localCoordinates
        let c = CubeEarth.coordinate(of: .init(Double(p.x), Double(p.y), Double(p.z)))
        onPick?(CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude))
    }

    @objc private func pinch(_ g: UIPinchGestureRecognizer) {
        guard g.state == .ended, g.scale > 1.25 else { return }
        let c = CubeEarth.center(pitch: pitch, yaw: yaw)
        onPick?(CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude))
    }

    // MARK: - Bau

    private static func geometry(_ m: CubeEarth.Mesh, clouds: Bool) -> SCNGeometry {
        func source(_ v: [Float], _ semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
            let data = v.withUnsafeBufferPointer { Data(buffer: $0) }
            return SCNGeometrySource(data: data, semantic: semantic, vectorCount: v.count / 3, usesFloatComponents: true,
                                     componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        }
        let linear = m.colors.map { powf($0, 2.2) } // Farben sind sRGB, SceneKit rechnet linear (wie im Prototyp)
        let g = SCNGeometry(sources: [source(m.positions, .vertex), source(m.normals, .normal), source(linear, .color)],
                            elements: [SCNGeometryElement(indices: m.indices, primitiveType: .triangles)])
        let mat = SCNMaterial()
        mat.lightingModel = .lambert
        mat.diffuse.contents = UIColor.white
        if clouds {
            mat.isDoubleSided = true
            mat.transparency = 0.75
            mat.writesToDepthBuffer = false
        }
        g.materials = [mat]
        return g
    }

    /// Standort: roter Block mit weißer Spitze, steht senkrecht auf seiner Würfelseite
    private static func pin(at c: Coordinate) -> SCNNode {
        let t = CGFloat(2.0 / Double(n))
        let a = CubeEarth.anchor(for: c, n: n, height: 1)
        let node = SCNNode()
        let red = SCNNode(geometry: SCNBox(width: t * 0.8, height: t * 2.2, length: t * 0.8, chamferRadius: 0))
        red.geometry?.firstMaterial?.diffuse.contents = StyleTheme.hex(0xe0362b)
        red.position.y = Float(t * 1.1)
        let tip = SCNNode(geometry: SCNBox(width: t * 0.8, height: t * 0.6, length: t * 0.8, chamferRadius: 0))
        tip.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        tip.position.y = Float(t * 2.5)
        node.addChildNode(red)
        node.addChildNode(tip)
        node.simdPosition = SIMD3(Float(a.position.x), Float(a.position.y), Float(a.position.z))
        let up = SIMD3<Float>(Float(a.normal.x), Float(a.normal.y), Float(a.normal.z))
        node.simdOrientation = up.y < -0.99 ? simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0)) : simd_quatf(from: SIMD3(0, 1, 0), to: up)
        return node
    }

    /// Pixel-Sterne (fest, kein Zufall beim Start)
    private static func starfield() -> UIImage {
        let w = 195, h = 422
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            UIColor(red: 0x0b / 255.0, green: 0x10 / 255.0, blue: 0x30 / 255.0, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for i in 0..<120 {
                (CubeEarth.hash(i, 3, 9) > 0.8 ? UIColor(red: 1, green: 0.91, blue: 0.66, alpha: 1) : .white).setFill()
                ctx.fill(CGRect(x: Int(CubeEarth.hash(i, 1, 7) * Double(w)), y: Int(CubeEarth.hash(i, 2, 8) * Double(h)), width: 1, height: 1))
            }
        }
    }
}

/// CADisplayLink hält sein Ziel fest – über diesen Umweg wird die Ansicht trotzdem freigegeben
@MainActor
private final class WeakTarget: NSObject {
    weak var view: CubeEarthView?
    init(_ v: CubeEarthView) { view = v }
    @objc func tick() { view?.tick() }
}
