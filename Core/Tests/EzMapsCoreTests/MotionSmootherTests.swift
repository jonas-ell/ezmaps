import XCTest
@testable import EzMapsCore

final class MotionSmootherTests: XCTestCase {
    let start = Coordinate(latitude: 50.2215, longitude: 8.268)

    /// Größter Sprung zwischen zwei Bildern (60 Hz) in Metern / Grad
    func maxStep(_ s: FreeMotionSmoother, from t0: Double, to t1: Double) -> (m: Double, deg: Double) {
        var last = s.pose(at: t0)!
        var m = 0.0, deg = 0.0
        var t = t0 + 1.0 / 60
        while t <= t1 {
            let p = s.pose(at: t)!
            m = max(m, p.coordinate.distance(to: last.coordinate))
            deg = max(deg, abs(FreeMotionSmoother.delta(last.heading, p.heading)))
            last = p
            t += 1.0 / 60
        }
        return (m, deg)
    }

    func testNoJumpWhenGPSLagsBehind() {
        // 15 m/s nach Norden; jede Meldung liegt 4 m hinter der Schätzung (GPS hinkt) – vorher Ruck von 4 m
        var s = FreeMotionSmoother()
        s.fix(start, speed: 15, course: 0, at: 0)
        for i in 1...5 {
            let truePos = start.moved(meters: 15 * Double(i) - 4, bearing: 0)
            let before = s.pose(at: Double(i) - 0.0001)!
            s.fix(truePos, speed: 15, course: 0, at: Double(i))
            let after = s.pose(at: Double(i))!
            XCTAssertLessThan(after.coordinate.distance(to: before.coordinate), 0.3, "kein Sprung beim neuen Fix \(i)")
        }
        // pro Bild höchstens Fahrstrecke (0,25 m) plus etwas Ausgleich
        XCTAssertLessThan(maxStep(s, from: 5, to: 6).m, 0.45)
    }

    func testConvergesToMeasurement() {
        var s = FreeMotionSmoother()
        s.fix(start, speed: 10, course: 90, at: 0)
        s.fix(start.moved(meters: 5, bearing: 90), speed: 10, course: 90, at: 1) // Schätzung 10 m, Messung 5 m
        let soon = s.pose(at: 1.0)!, later = s.pose(at: 1.8)!
        let rawLater = start.moved(meters: 5 + 8, bearing: 90)
        XCTAssertGreaterThan(soon.coordinate.distance(to: start.moved(meters: 5, bearing: 90)), 4, "erst noch nah an der alten Schätzung")
        XCTAssertLessThan(later.coordinate.distance(to: rawLater), 0.5, "nach 0,8 s praktisch auf der Messung")
    }

    func testTurnsSmoothlyInsteadOfSteps() {
        // Rechtskurve 20 °/s – Richtung soll zwischen den Meldungen mitdrehen, nicht in 20°-Stufen
        var s = FreeMotionSmoother()
        var c = start
        for i in 0...4 {
            s.fix(c, speed: 12, course: Double(i) * 20, at: Double(i))
            c = c.moved(meters: 12, bearing: Double(i) * 20 + 10)
        }
        let step = maxStep(s, from: 4, to: 4.99)
        XCTAssertLessThan(step.deg, 1.0, "höchstens ~0,33° pro Bild bei 20°/s")
        XCTAssertEqual(s.pose(at: 4.5)!.heading, 90, accuracy: 3, "dreht weiter (80° + 10°)")
    }

    func testStandstillStaysPut() {
        var s = FreeMotionSmoother()
        s.fix(start, speed: 0, course: -1, at: 0)
        XCTAssertLessThan(s.pose(at: 1.5)!.coordinate.distance(to: start), 0.01)
    }

    func testTunnelStopsAfterMaxPredict() {
        var s = FreeMotionSmoother()
        s.fix(start, speed: 20, course: 0, at: 0)
        let a = s.pose(at: 2.5)!, b = s.pose(at: 10)!
        XCTAssertEqual(a.coordinate.distance(to: b.coordinate), 0, accuracy: 0.01)
        XCTAssertEqual(a.coordinate.distance(to: start), 50, accuracy: 1)
    }

    func testBigJumpIsNotSmeared() {
        var s = FreeMotionSmoother()
        s.fix(start, speed: 10, course: 0, at: 0)
        let far = start.moved(meters: 300, bearing: 45)
        s.fix(far, speed: 10, course: 0, at: 1)
        XCTAssertLessThan(s.pose(at: 1)!.coordinate.distance(to: far), 0.5)
    }

    func testRouteProgressContinuous() {
        var r = RouteProgressSmoother()
        r.fix(progress: 0, speed: 14, at: 0)
        var prev = r.value(at: 0)!
        var maxStep = 0.0
        for i in 1...4 {
            var t = Double(i - 1) + 1.0 / 60
            while t < Double(i) { let v = r.value(at: t)!; maxStep = max(maxStep, abs(v - prev)); prev = v; t += 1.0 / 60 }
            r.fix(progress: 14 * Double(i) - 3, speed: 14, at: Double(i)) // Messung 3 m hinter der Schätzung
            let v = r.value(at: Double(i))!
            maxStep = max(maxStep, abs(v - prev)); prev = v
        }
        XCTAssertLessThan(maxStep, 0.3, "kein Ruck auf der Route")
        XCTAssertEqual(r.value(at: 100, limit: 50)!, 50, "nie über das Routenende")
        r.fix(progress: 0, speed: 14, at: 5) // Neuberechnung: neuer Fortschritt direkt
        XCTAssertEqual(r.value(at: 5)!, 0, accuracy: 0.001)
    }
}
