import XCTest
@testable import EzMapsCore

final class StyleTrialTests: XCTestCase {
    func run(_ t: inout StyleTrial, _ seconds: Int, visible: Bool = true, navigating: Bool = false) -> [StyleTrial.Event] {
        (0..<seconds).compactMap { _ in t.tick(seconds: 1, visible: visible, navigating: navigating) }
    }

    func testBudgetRunsOutOnceAndNeverAgain() {
        var t = StyleTrial()
        XCTAssertTrue(t.start("neon"))
        XCTAssertEqual(run(&t, 600), [.oneMinuteLeft, .expired])
        XCTAssertNil(t.active)
        XCTAssertFalse(t.start("neon"), "zweiter Test nicht möglich")
        XCTAssertTrue(t.start("western"), "anderer Stil hat eigenes Budget")
    }

    func testOnlyVisibleTimeCounts() {
        var t = StyleTrial(); _ = t.start("neon")
        _ = run(&t, 300, visible: false)
        XCTAssertEqual(t.remaining("neon"), 600)
        _ = run(&t, 100)
        XCTAssertEqual(t.remaining("neon"), 500)
    }

    func testPausingKeepsUsedTime() {
        var t = StyleTrial(); _ = t.start("neon"); _ = run(&t, 400); t.stop()
        XCTAssertTrue(t.start("neon"))
        XCTAssertEqual(t.remaining("neon"), 200)
    }

    func testNeverExpiresDuringNavigation() {
        var t = StyleTrial(); _ = t.start("neon")
        let ev = run(&t, 900, navigating: true)
        XCTAssertEqual(ev, [.oneMinuteLeft, .expiresAfterArrival])
        XCTAssertEqual(t.active, "neon", "Stil bleibt bis zur Ankunft")
        XCTAssertEqual(t.navigationEnded(), .expired)
        XCTAssertNil(t.active)
    }

    func testReinstallCannotReset() {
        // Gerät A hat 550 s verbraucht (Schlüsselbund), nach Neuinstallation startet die App leer
        var fresh = StyleTrial()
        fresh.merge(["neon": 550])
        XCTAssertEqual(fresh.remaining("neon"), 50)
        fresh.merge(["neon": 100])
        XCTAssertEqual(fresh.remaining("neon"), 50, "kleinerer Wert überschreibt nicht")
        fresh.merge(["neon": 99_999])
        XCTAssertEqual(fresh.remaining("neon"), 0)
    }

    func testCodable() throws {
        var t = StyleTrial(); _ = t.start("pixel"); _ = run(&t, 10)
        let back = try JSONDecoder().decode(StyleTrial.self, from: JSONEncoder().encode(t))
        XCTAssertEqual(back.remaining("pixel"), 590)
    }
}
