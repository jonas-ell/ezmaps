import Foundation
import Observation
import StoreKit
import EzMapsCore

/// GM-043: StoreKit 2 – EzMaps Plus (Jahr, Monat, für immer) und Einzelkäufe (GM-038/039, kein Gratis-Zeitraum GM-042).
/// Preise kommen immer aus StoreKit (`displayPrice`), nie fest im Code. Freischalt-Regeln: `StyleAccess` (Core, getestet).
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    private(set) var products: [String: Product] = [:]
    /// GM-071: beim Start der zuletzt bekannte Stand – sonst zeigte die App erst Klassik und sprang nach der
    /// App-Store-Antwort zum gewählten Stil (Nutzer). refreshEntitlements korrigiert kurz danach.
    private(set) var access = StyleAccess(owned: Set(UserDefaults.standard.stringArray(forKey: "ownedCache") ?? []))
    private(set) var isBusy = false
    /// Kurzer Fehlertext für die Paywall
    var errorText: String?
    /// GM-050: Test-Käufe (Preise aus TestStore, Kauf schaltet ohne Geld frei), solange App Store Connect noch keine
    /// Produkte liefert. Nur in Test-Builds (Debug oder EZTEST von tools/mac_device.sh), nie im App-Store-Build.
    private(set) var testMode = false
    @ObservationIgnored private let testKey = "testPurchases"

    static var testAllowed: Bool {
        #if DEBUG || EZTEST
        return true
        #else
        return false
        #endif
    }

    @ObservationIgnored private var updates: Task<Void, Never>?

    private init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    func loadProducts() async {
        do {
            let list = try await Product.products(for: ProductID.all)
            var map: [String: Product] = [:]
            for p in list { map[p.id] = p }
            products = map
        } catch {
            if !Self.testAllowed { errorText = L("Shop gerade nicht erreichbar") }
        }
        testMode = Self.testAllowed && products.isEmpty
    }

    /// GM-050: Test-Käufe zurücksetzen (Einstellungen, nur im Test-Modus)
    func resetTestPurchases() {
        UserDefaults.standard.removeObject(forKey: testKey)
        Task { await refreshEntitlements() }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if let exp = t.expirationDate, exp < Date() { continue }
            owned.insert(t.productID)
        }
        if testMode { owned.formUnion(UserDefaults.standard.stringArray(forKey: testKey) ?? []) }
        access = StyleAccess(owned: owned)
        UserDefaults.standard.set(Array(owned), forKey: "ownedCache")
    }

    func price(_ id: String) -> String? { products[id]?.displayPrice ?? (testMode ? TestStore.price(id) : nil) }

    /// Kaufbar? (echtes Produkt oder Test-Modus)
    func canBuy(_ id: String) -> Bool { products[id] != nil || (testMode && TestStore.pricesEUR[id] != nil) }

    /// Jahrespreis pro Monat, im Format von StoreKit („2,49 €“)
    var yearlyPerMonth: String? {
        if let y = products[ProductID.yearly] { return PlanMath.perMonth(yearly: y.price).formatted(y.priceFormatStyle) }
        guard testMode, let y = TestStore.pricesEUR[ProductID.yearly] else { return nil }
        return TestStore.display(PlanMath.perMonth(yearly: y))
    }

    var savingsPercent: Int {
        if let m = products[ProductID.monthly], let y = products[ProductID.yearly] { return PlanMath.savingsPercent(monthly: m.price, yearly: y.price) }
        guard testMode, let m = TestStore.pricesEUR[ProductID.monthly], let y = TestStore.pricesEUR[ProductID.yearly] else { return 0 }
        return PlanMath.savingsPercent(monthly: m, yearly: y)
    }

    /// Kaufen. `true` = gekauft (Freischaltung ist dann schon aktualisiert)
    @discardableResult
    func purchase(_ id: String) async -> Bool {
        if testMode && products[id] == nil && TestStore.pricesEUR[id] != nil {
            // GM-050: Test-Kauf – kurz „kaufen“, dann freischalten (kein Geld, nur auf diesem Gerät)
            isBusy = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            var owned = Set(UserDefaults.standard.stringArray(forKey: testKey) ?? [])
            owned.insert(id)
            UserDefaults.standard.set(Array(owned), forKey: testKey)
            await refreshEntitlements()
            isBusy = false
            return true
        }
        guard let product = products[id] else {
            errorText = L("Shop gerade nicht erreichbar")
            return false
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let t) = verification else {
                    errorText = L("Kauf konnte nicht geprüft werden")
                    return false
                }
                await t.finish()
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorText = L("Kauf fehlgeschlagen")
            return false
        }
    }

    /// „Käufe wiederherstellen“ (Apple-Pflicht)
    func restore() async {
        isBusy = true
        defer { isBusy = false }
        if !testMode { do { try await AppStore.sync() } catch { errorText = L("Wiederherstellen fehlgeschlagen") } }
        await refreshEntitlements()
    }
}
