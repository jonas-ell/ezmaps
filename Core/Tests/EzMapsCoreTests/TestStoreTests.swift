import XCTest
@testable import EzMapsCore

/// GM-050: Test-Preise müssen zur StoreKit-Testdatei passen und alle Produkte abdecken
final class TestStoreTests: XCTestCase {
    func testEveryProductHasATestPrice() {
        for id in ProductID.all { XCTAssertNotNil(TestStore.pricesEUR[id], id) }
        XCTAssertEqual(Set(TestStore.pricesEUR.keys), Set(ProductID.all))
    }

    func testPricesMatchStoreKitFile() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/EzMaps.storekit")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("StoreKit-Datei nicht gefunden (nur Core ausgecheckt)") }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var found: [String: String] = [:]
        for p in json["products"] as? [[String: Any]] ?? [] { found[p["productID"] as? String ?? ""] = p["displayPrice"] as? String }
        for g in json["subscriptionGroups"] as? [[String: Any]] ?? [] {
            for p in g["subscriptions"] as? [[String: Any]] ?? [] { found[p["productID"] as? String ?? ""] = p["displayPrice"] as? String }
        }
        for (id, price) in TestStore.pricesEUR {
            XCTAssertEqual(found[id].flatMap { Decimal(string: $0) }, price, id)
        }
    }

    func testDisplayFormat() {
        XCTAssertEqual(TestStore.display(Decimal(string: "4.99")!).replacingOccurrences(of: "\u{00A0}", with: " "), "4,99 €")
    }
}
