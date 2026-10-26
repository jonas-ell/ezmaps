import XCTest
@testable import EzMapsCore

/// GM-029: Grenzfälle der Entfernungs- und Zeitanzeige (iPhone, Ansagen, CarPlay)
final class FormattingTests: XCTestCase {
    func testDistanceSteps() {
        XCTAssertEqual(Formatting.distance(0), "0 m")
        XCTAssertEqual(Formatting.distance(-5), "0 m")
        XCTAssertEqual(Formatting.distance(44), "40 m")
        XCTAssertEqual(Formatting.distance(96), "100 m")
        XCTAssertEqual(Formatting.distance(130), "150 m")
        XCTAssertEqual(Formatting.distance(1_249), "1,2 km")
        XCTAssertEqual(Formatting.distance(12_400), "12 km")
    }

    /// Regressionstest: knapp unter 1 km wurde „1000 m“, knapp unter 10 km „10,0 km“
    func testDistanceRoundingBoundaries() {
        XCTAssertEqual(Formatting.distance(980), "1,0 km")
        XCTAssertEqual(Formatting.distance(999), "1,0 km")
        XCTAssertEqual(Formatting.distance(974), "950 m")
        XCTAssertEqual(Formatting.distance(9_960), "10 km")
        XCTAssertEqual(Formatting.distance(9_940), "9,9 km")
    }

    func testSpokenDistance() {
        XCTAssertEqual(Formatting.spokenDistance(300), "300 Metern")
        XCTAssertEqual(Formatting.spokenDistance(1_500), "1,5 Kilometern")
        XCTAssertEqual(Formatting.spokenDistance(999), "1,0 Kilometern")
    }

    func testMinutes() {
        XCTAssertEqual(Formatting.minutes(0), "1 Min")
        XCTAssertEqual(Formatting.minutes(89), "1 Min")
        XCTAssertEqual(Formatting.minutes(3_570), "1 Std")
        XCTAssertEqual(Formatting.minutes(3_900), "1 Std 5 Min")
    }

    func testClock() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let d = cal.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 7, minute: 5))!
        XCTAssertEqual(Formatting.clock(d, calendar: cal), "7:05")
    }

    /// CarPlay bekommt Zahl + Einheit; ab 1 km in km mit einer Nachkommastelle (GM-024: vorher „14.602 m“)
    func testCarPlayDistance() {
        XCTAssertEqual(Formatting.carPlayDistance(14_602).value, 14.6, accuracy: 0.001)
        XCTAssertTrue(Formatting.carPlayDistance(14_602).kilometers)
        XCTAssertEqual(Formatting.carPlayDistance(980).value, 1.0, accuracy: 0.001)
        XCTAssertTrue(Formatting.carPlayDistance(980).kilometers)
        XCTAssertEqual(Formatting.carPlayDistance(430).value, 450)
        XCTAssertFalse(Formatting.carPlayDistance(430).kilometers)
        XCTAssertEqual(Formatting.carPlayDistance(37).value, 40)
    }
}
