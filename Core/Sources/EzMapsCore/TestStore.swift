import Foundation

/// GM-050: Test-Käufe, solange die Produkte in App Store Connect noch nicht angelegt sind.
/// Nur in Test-Builds aktiv (`#if DEBUG || EZTEST` in PurchaseManager), nie im App-Store-Build.
/// Preise = App/EzMaps.storekit (Test `TestStoreTests` prüft, dass beide gleich sind) – change both.
public enum TestStore {
    /// Preis in Euro je Produkt-ID
    public static let pricesEUR: [String: Decimal] = [
        ProductID.monthly: Decimal(string: "4.99")!,
        ProductID.yearly: Decimal(string: "29.99")!,
        ProductID.lifetime: Decimal(string: "79.99")!,
        "ezmaps.style.neon": Decimal(string: "39.99")!,
        "ezmaps.style.western": Decimal(string: "29.99")!,
        "ezmaps.style.pixel": Decimal(string: "29.99")!,
        "ezmaps.style.toy": Decimal(string: "29.99")!,
    ]

    /// „4,99 €“ (deutsches Format, wie StoreKit es in Deutschland zeigt)
    public static func display(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        return f.string(from: value as NSDecimalNumber) ?? "\(value) €"
    }

    public static func price(_ id: String) -> String? { pricesEUR[id].map(display) }
}
