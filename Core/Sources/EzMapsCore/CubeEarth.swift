import Foundation

/// GM-074: Land/Wasser der Erde (0,5°-Raster, Natural Earth). Daten in LandMaskData.swift (erzeugt).
public struct LandMask: Sendable {
    public let width: Int
    public let height: Int
    private let bits: [UInt8]

    public init(width: Int, height: Int, bits: [UInt8]) {
        self.width = width
        self.height = height
        self.bits = bits
    }

    public static let world: LandMask = {
        let data = Data(base64Encoded: worldBase64, options: .ignoreUnknownCharacters) ?? Data()
        return LandMask(width: worldWidth, height: worldHeight, bits: [UInt8](data))
    }()

    public func isLand(_ c: Coordinate) -> Bool {
        let x = Int(((c.longitude + 180) / 360 * Double(width)).rounded(.down))
        let y = Int(((90 - c.latitude) / 180 * Double(height)).rounded(.down))
        let i = ((y < 0 ? 0 : y >= height ? height - 1 : y) * width) + ((x % width) + width) % width
        guard i >> 3 < bits.count else { return false }
        return bits[i >> 3] & (0x80 >> UInt8(i & 7)) != 0
    }
}

/// GM-074: Pixel Quest – beim ganz Rauszoomen wird die Erde zu einem Würfel aus Blöcken (Nutzer-Wunsch).
/// Jede Würfelseite ist ein n × n Raster; Land ragt einen Block hoch, Wasser ist flach.
/// Seiten in der Reihenfolge von SCNBox (vorn +z = 0° Länge, rechts +x = 90° Ost, hinten, links, oben = Nordpol, unten).
/// Mirror in tools/prototype/js/cubeearth.js – change both.
public enum CubeEarth {
    public struct Vec3: Equatable, Sendable {
        public var x, y, z: Double
        public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
        static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
        static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
        static func * (a: Vec3, s: Double) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
        func dot(_ b: Vec3) -> Double { x * b.x + y * b.y + z * b.z }
        func cross(_ b: Vec3) -> Vec3 { Vec3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
    }

    public enum Face: Int, CaseIterable, Sendable { case front, right, back, left, top, bottom }

    public enum Block: Int, Sendable { case deepWater, water, ice, sand, grass, forest, snow }

    /// Normale, „rechts“ und „unten“ je Seite (wie die Bild-Ausrichtung von SCNBox)
    static func basis(_ f: Face) -> (n: Vec3, r: Vec3, d: Vec3) {
        switch f {
        case .front: return (Vec3(0, 0, 1), Vec3(1, 0, 0), Vec3(0, -1, 0))
        case .right: return (Vec3(1, 0, 0), Vec3(0, 0, -1), Vec3(0, -1, 0))
        case .back: return (Vec3(0, 0, -1), Vec3(-1, 0, 0), Vec3(0, -1, 0))
        case .left: return (Vec3(-1, 0, 0), Vec3(0, 0, 1), Vec3(0, -1, 0))
        case .top: return (Vec3(0, 1, 0), Vec3(1, 0, 0), Vec3(0, 0, 1))
        case .bottom: return (Vec3(0, -1, 0), Vec3(1, 0, 0), Vec3(0, 0, -1))
        }
    }

    /// Punkt auf der Würfelseite, u/v von −1 bis 1 (darüber hinaus: Ebene verlängert – reicht für Nachbarn an Kanten)
    public static func point(_ f: Face, u: Double, v: Double) -> Vec3 {
        let b = basis(f)
        return b.n + b.r * u + b.d * v
    }

    /// Richtung (beliebige Länge) → Koordinate
    public static func coordinate(of p: Vec3) -> Coordinate {
        let len = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
        guard len > 0 else { return Coordinate(latitude: 0, longitude: 0) }
        return Coordinate(latitude: asin(max(-1, min(1, p.y / len))) * 180 / .pi, longitude: atan2(p.x, p.z) * 180 / .pi)
    }

    /// Koordinate → Einheitsrichtung
    public static func vector(for c: Coordinate) -> Vec3 {
        let la = c.latitude * .pi / 180, lo = c.longitude * .pi / 180
        return Vec3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))
    }

    /// Welche Seite und welcher Block liegt unter einer Koordinate
    public static func cell(for c: Coordinate, n: Int) -> (face: Face, col: Int, row: Int) {
        let p = vector(for: c)
        let face = Face.allCases.max { basis($0).n.dot(p) < basis($1).n.dot(p) }!
        let b = basis(face), k = b.n.dot(p)
        let u = b.r.dot(p) / k, v = b.d.dot(p) / k
        let clampIdx = { (x: Double) in max(0, min(n - 1, Int(((x + 1) / 2 * Double(n)).rounded(.down)))) }
        return (face, clampIdx(u), clampIdx(v))
    }

    /// Punkt `h` Blöcke über der Mitte des Blocks unter `c` und die Außenrichtung der Seite – für den Standort-Stift
    public static func anchor(for c: Coordinate, n: Int, height h: Double) -> (position: Vec3, normal: Vec3) {
        let k = cell(for: c, n: n), b = basis(k.face), t = 2 / Double(n)
        let u = -1 + (Double(k.col) + 0.5) * t, v = -1 + (Double(k.row) + 0.5) * t
        return (b.n * (1 + h * t) + b.r * u + b.d * v, b.n)
    }

    /// Mitte eines Blocks als Koordinate
    public static func coordinate(_ f: Face, col: Int, row: Int, n: Int) -> Coordinate {
        coordinate(of: point(f, u: -1 + (Double(col) + 0.5) * 2 / Double(n), v: -1 + (Double(row) + 0.5) * 2 / Double(n)))
    }

    /// Blockart je Seite (Zeile für Zeile). Land = mind. 5 von 9 Stichproben; mind. 2 Wasser-Nachbarn = Sand (Strand),
    /// Polargebiete Schnee/Eis, Nordwälder dunkler; Wasser fern vom Land dunkler.
    public static func blocks(n: Int, mask: LandMask = .world) -> [[Block]] {
        let step = 2 / Double(n)
        func land(_ f: Face, _ u: Double, _ v: Double) -> Bool {
            var hits = 0
            for a in [-0.33, 0, 0.33] { for b in [-0.33, 0, 0.33] where mask.isLand(coordinate(of: point(f, u: u + a * step, v: v + b * step))) { hits += 1 } }
            return hits >= 5
        }
        return Face.allCases.map { f in
            var out: [Block] = []
            out.reserveCapacity(n * n)
            for row in 0..<n {
                for col in 0..<n {
                    let u = -1 + (Double(col) + 0.5) * step, v = -1 + (Double(row) + 0.5) * step
                    let lat = abs(coordinate(of: point(f, u: u, v: v)).latitude)
                    let isLand = land(f, u, v)
                    let near = [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)].map { mask.isLand(coordinate(of: point(f, u: u + $0.0 * step, v: v + $0.1 * step))) }
                    if isLand {
                        if lat > 62 { out.append(.snow) } else if near.filter({ !$0 }).count >= 2 { out.append(.sand) } else if lat > 50 { out.append(.forest) } else { out.append(.grass) }
                    } else if lat > 74 {
                        out.append(.ice)
                    } else {
                        let far = [(2.5, 0.0), (-2.5, 0.0), (0.0, 2.5), (0.0, -2.5)].allSatisfy { !mask.isLand(coordinate(of: point(f, u: u + $0.0 * step, v: v + $0.1 * step))) }
                        out.append(near.contains(true) || !far ? .water : .deepWater)
                    }
                }
            }
            return out
        }
    }

    public struct RGB: Equatable, Sendable {
        public var r, g, b: Double
        public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        func scaled(_ s: Double) -> RGB { RGB(min(1, r * s), min(1, g * s), min(1, b * s)) }
    }

    /// Farben passend zu style-pixel-quest (Gras #5d9b37, Wasser wie die Karte)
    public static func color(_ b: Block) -> RGB {
        switch b {
        case .deepWater: return RGB(0.11, 0.17, 0.60)
        case .water: return RGB(0.16, 0.25, 0.80)
        case .ice: return RGB(0.72, 0.86, 0.96)
        case .sand: return RGB(0.87, 0.80, 0.54)
        case .grass: return RGB(0.36, 0.61, 0.22)
        case .forest: return RGB(0.20, 0.44, 0.15)
        case .snow: return RGB(0.95, 0.97, 1.0)
        }
    }

    static let dirt = RGB(0.47, 0.33, 0.20)

    public static func isRaised(_ b: Block) -> Bool { b.rawValue >= Block.sand.rawValue }

    /// Gleichmäßig verteilter Zufall 0…1, fest je Eingabe (gleiches Ergebnis in Swift und JS)
    public static func hash(_ a: Int, _ b: Int, _ c: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: a &* 374_761_393 &+ b &* 668_265_263 &+ c &* 1_274_126_177)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h) / 4_294_967_295
    }

    /// Dreiecksnetz für SceneKit/three.js: je 4 Ecken pro Viereck, Farben je Ecke
    public struct Mesh: Sendable {
        public var positions: [Float] = []
        public var normals: [Float] = []
        public var colors: [Float] = []
        public var indices: [UInt32] = []
        public var quadCount: Int { indices.count / 6 }

        mutating func quad(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ d: Vec3, normal: Vec3, color: RGB) {
            // Reihenfolge gegen den Uhrzeigersinn von außen gesehen
            let pts = (b - a).cross(c - a).dot(normal) >= 0 ? [a, b, c, d] : [a, d, c, b]
            let base = UInt32(positions.count / 3)
            for p in pts {
                positions += [Float(p.x), Float(p.y), Float(p.z)]
                normals += [Float(normal.x), Float(normal.y), Float(normal.z)]
                colors += [Float(color.r), Float(color.g), Float(color.b)]
            }
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
    }

    /// Würfel-Erde als Netz. Halbe Kantenlänge 1, ein Block ist 2/n groß; Land steht einen Block hoch.
    public static func mesh(n: Int, blocks: [[Block]]) -> Mesh {
        var m = Mesh()
        let t = 2 / Double(n), sub = 2
        for f in Face.allCases {
            let (nv, r, d) = basis(f)
            let grid = blocks[f.rawValue]
            func raised(_ col: Int, _ row: Int) -> Bool {
                guard col >= 0, col < n, row >= 0, row < n else { return false } // Kante: Wand immer zeichnen
                return isRaised(grid[row * n + col])
            }
            func at(_ u: Double, _ v: Double, _ h: Double) -> Vec3 { nv * (1 + h * t) + r * u + d * v }
            for row in 0..<n {
                for col in 0..<n {
                    let b = grid[row * n + col]
                    let h: Double = isRaised(b) ? 1 : 0
                    let u0 = -1 + Double(col) * t, v0 = -1 + Double(row) * t
                    let base = color(b)
                    // Oberseite in 2 × 2 „Pixel“ mit leicht anderer Helligkeit – Blockstruktur
                    let s = t / Double(sub)
                    for j in 0..<sub {
                        for i in 0..<sub {
                            let shade = 0.9 + 0.2 * hash(f.rawValue * 7 + i, col * 2 + j, row)
                            let a = u0 + Double(i) * s, c = v0 + Double(j) * s
                            m.quad(at(a, c, h), at(a, c + s, h), at(a + s, c + s, h), at(a + s, c, h), normal: nv, color: base.scaled(shade))
                        }
                    }
                    guard h > 0 else { continue }
                    // Seitenwände, wo der Nachbar tiefer liegt: oben ein Streifen Blockfarbe, darunter Erde (Sand ganz)
                    let sides: [(Bool, Vec3, Vec3, Vec3)] = [
                        (raised(col - 1, row), r * -1, at(u0, v0, 0), at(u0, v0 + t, 0)),
                        (raised(col + 1, row), r, at(u0 + t, v0, 0), at(u0 + t, v0 + t, 0)),
                        (raised(col, row - 1), d * -1, at(u0, v0, 0), at(u0 + t, v0, 0)),
                        (raised(col, row + 1), d, at(u0, v0 + t, 0), at(u0 + t, v0 + t, 0)),
                    ]
                    let band = b == .sand ? 1.0 : 0.3
                    for (covered, out, e0, e1) in sides where !covered {
                        let up = nv * t, mid = nv * (t * (1 - band))
                        let shade = 0.85 + 0.1 * hash(f.rawValue, col, row)
                        if band < 1 { m.quad(e0, e1, e1 + mid, e0 + mid, normal: out, color: dirt.scaled(shade)) }
                        m.quad(e0 + mid, e1 + mid, e1 + up, e0 + up, normal: out, color: base.scaled(shade * 0.92))
                    }
                }
            }
        }
        return m
    }

    /// Wolken: flache weiße Platten vier Blöcke über dem Boden, in Haufen (gröberes Raster entscheidet mit)
    public static func clouds(n: Int, seed: Int = 1) -> Mesh {
        var m = Mesh()
        let t = 2 / Double(n), h = 4.5
        for f in Face.allCases {
            let (nv, r, d) = basis(f)
            for row in 0..<n {
                for col in 0..<n {
                    let coarse = hash(f.rawValue + seed * 11, col / 4, row / 3)
                    let fine = hash(f.rawValue + seed * 13, col, row)
                    guard coarse > 0.8 && fine > 0.4 || fine > 0.995 else { continue }
                    let u0 = -1 + Double(col) * t, v0 = -1 + Double(row) * t
                    func at(_ u: Double, _ v: Double) -> Vec3 { nv * (1 + h * t) + r * u + d * v }
                    m.quad(at(u0, v0), at(u0, v0 + t), at(u0 + t, v0 + t), at(u0 + t, v0), normal: nv, color: RGB(1, 1, 1))
                }
            }
        }
        return m
    }

    /// Drehung des Würfels (Euler wie SceneKit: x = Breite, y = −Länge), damit `c` vorn mittig steht, Norden oben
    public static func facing(_ c: Coordinate) -> (pitch: Double, yaw: Double) {
        (c.latitude * .pi / 180, -c.longitude * .pi / 180)
    }

    /// Umkehrung von `facing`: welche Koordinate gerade vorn mittig ist
    public static func center(pitch: Double, yaw: Double) -> Coordinate {
        var lon = -yaw * 180 / .pi
        lon = (lon + 180).truncatingRemainder(dividingBy: 360)
        if lon < 0 { lon += 360 }
        return Coordinate(latitude: max(-89, min(89, pitch * 180 / .pi)), longitude: lon - 180)
    }
}
