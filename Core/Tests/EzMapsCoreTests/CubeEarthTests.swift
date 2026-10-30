import XCTest
@testable import EzMapsCore

final class CubeEarthTests: XCTestCase {
    func testLandMask() {
        let m = LandMask.world
        XCTAssertTrue(m.isLand(Coordinate(latitude: 50.22, longitude: 8.27)), "Idstein")
        XCTAssertTrue(m.isLand(Coordinate(latitude: -25, longitude: 135)), "Australien")
        XCTAssertTrue(m.isLand(Coordinate(latitude: -89.9, longitude: 0)), "Südpol")
        XCTAssertFalse(m.isLand(Coordinate(latitude: 40, longitude: -40)), "Atlantik")
        XCTAssertFalse(m.isLand(Coordinate(latitude: 0, longitude: -150)), "Pazifik")
        XCTAssertFalse(m.isLand(Coordinate(latitude: 54.5, longitude: 3)), "Nordsee")
    }

    func testRoundTripAndFaces() {
        for c in [Coordinate(latitude: 50.2, longitude: 8.3), Coordinate(latitude: -33.9, longitude: 151.2),
                  Coordinate(latitude: 40.7, longitude: -74), Coordinate(latitude: 85, longitude: 20)] {
            let back = CubeEarth.coordinate(of: CubeEarth.vector(for: c))
            XCTAssertEqual(back.latitude, c.latitude, accuracy: 1e-9)
            XCTAssertEqual(back.longitude, c.longitude, accuracy: 1e-9)
            let cell = CubeEarth.cell(for: c, n: 48)
            let mid = CubeEarth.coordinate(cell.face, col: cell.col, row: cell.row, n: 48)
            XCTAssertLessThan(mid.distance(to: c), 250_000, "Blockmitte nah an \(c)")
        }
        XCTAssertEqual(CubeEarth.cell(for: Coordinate(latitude: 30, longitude: 8), n: 48).face, .front)
        XCTAssertEqual(CubeEarth.cell(for: Coordinate(latitude: 50, longitude: 8), n: 48).face, .top, "Deutschland liegt schon auf der Nordseite")
        XCTAssertEqual(CubeEarth.cell(for: Coordinate(latitude: 30, longitude: 100), n: 48).face, .right)
        XCTAssertEqual(CubeEarth.cell(for: Coordinate(latitude: 0, longitude: -90), n: 48).face, .left)
        XCTAssertEqual(CubeEarth.cell(for: Coordinate(latitude: 0, longitude: 180), n: 48).face, .back)
        XCTAssertEqual(CubeEarth.cell(for: Coordinate(latitude: 80, longitude: 0), n: 48).face, .top)
        // Norden ist oben auf der Vorderseite: höhere Breite → kleinere Zeile
        XCTAssertLessThan(CubeEarth.cell(for: Coordinate(latitude: 30, longitude: 0), n: 48).row,
                          CubeEarth.cell(for: Coordinate(latitude: 0, longitude: 0), n: 48).row)
    }

    func testBlocks() {
        let n = 48, blocks = CubeEarth.blocks(n: n)
        XCTAssertEqual(blocks.count, 6)
        func at(_ c: Coordinate) -> CubeEarth.Block { let k = CubeEarth.cell(for: c, n: n); return blocks[k.face.rawValue][k.row * n + k.col] }
        XCTAssertTrue(CubeEarth.isRaised(at(Coordinate(latitude: 50.2, longitude: 10))), "Deutschland ist Land")
        XCTAssertEqual(at(Coordinate(latitude: 0, longitude: 20)), .grass, "Kongo")
        XCTAssertEqual(at(Coordinate(latitude: 75, longitude: -40)), .snow, "Grönland")
        XCTAssertEqual(at(Coordinate(latitude: -85, longitude: 0)), .snow, "Antarktis")
        XCTAssertEqual(at(Coordinate(latitude: 30, longitude: -40)), .deepWater, "Atlantik")
        let land = blocks.joined().filter(CubeEarth.isRaised).count
        XCTAssertEqual(Double(land) / Double(6 * n * n), 0.29, accuracy: 0.05, "etwa 29 % Land")
    }

    func testMeshIsClosedAndOutward() {
        let n = 16
        let m = CubeEarth.mesh(n: n, blocks: CubeEarth.blocks(n: n))
        XCTAssertEqual(m.positions.count, m.normals.count)
        XCTAssertEqual(m.positions.count, m.colors.count)
        XCTAssertGreaterThanOrEqual(m.quadCount, 6 * n * n * 4)
        // jedes Dreieck zeigt mit seiner Normalen nach außen (gegen den Uhrzeigersinn von außen)
        for k in stride(from: 0, to: m.indices.count, by: 3) {
            func p(_ i: UInt32) -> CubeEarth.Vec3 { let j = Int(i) * 3; return .init(Double(m.positions[j]), Double(m.positions[j + 1]), Double(m.positions[j + 2])) }
            let a = p(m.indices[k]), b = p(m.indices[k + 1]), c = p(m.indices[k + 2])
            let j = Int(m.indices[k]) * 3
            let nrm = CubeEarth.Vec3(Double(m.normals[j]), Double(m.normals[j + 1]), Double(m.normals[j + 2]))
            XCTAssertGreaterThan((b - a).cross(c - a).dot(nrm), 0)
        }
        XCTAssertGreaterThan(CubeEarth.clouds(n: n).quadCount, 0)
    }

    func testFacingAndCenter() {
        let c = Coordinate(latitude: 50.2, longitude: 8.3)
        let f = CubeEarth.facing(c)
        let back = CubeEarth.center(pitch: f.pitch, yaw: f.yaw)
        XCTAssertEqual(back.latitude, c.latitude, accuracy: 1e-9)
        XCTAssertEqual(back.longitude, c.longitude, accuracy: 1e-9)
        XCTAssertEqual(CubeEarth.center(pitch: 0, yaw: -3 * .pi / 2).longitude, -90, accuracy: 1e-9, "über 180° hinaus gedreht")
    }

    func testAnchorPointsOutAtLocation() {
        let c = Coordinate(latitude: 50.22, longitude: 8.27)
        let a = CubeEarth.anchor(for: c, n: 48, height: 1)
        XCTAssertEqual(a.normal, CubeEarth.Vec3(0, 1, 0), "Idstein liegt auf der Nordseite")
        XCTAssertEqual(a.position.y, 1 + 2.0 / 48, accuracy: 1e-9, "auf dem Land-Block")
        XCTAssertLessThan(CubeEarth.coordinate(of: a.position).distance(to: c), 250_000)
    }

    func testHashMatchesJS() {
        // gleiche Werte wie tools/prototype/js/cubeearth.js (hash(1,2,3), hash(5,40,47))
        XCTAssertEqual(CubeEarth.hash(1, 2, 3), 0.593221994022192, accuracy: 1e-12)
        XCTAssertEqual(CubeEarth.hash(5, 40, 47), 0.9601893636770987, accuracy: 1e-12)
    }
}
