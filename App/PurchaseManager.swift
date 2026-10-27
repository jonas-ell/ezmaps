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
    private(set) var access = StyleAccess()
    private(set) var isBusy = false
    /// Kurzer Fehlertext für die Paywall
    var errorText: String?

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
            errorText = L("Shop gerade nicht erreichbar")
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if let exp = t.expirationDate, exp < Date() { continue }
            owned.insert(t.productID)
        }
        access = StyleAccess(owned: owned)
    }

    func price(_ id: String) -> String? { products[id]?.displayPrice }

    /// Jahrespreis pro Monat, im Format von StoreKit („2,49 €“)
    var yearlyPerMonth: String? {
        guard let y = products[ProductID.yearly] else { return nil }
        return PlanMath.perMonth(yearly: y.price).formatted(y.priceFormatStyle)
    }

    var savingsPercent: Int {
        guard let m = products[ProductID.monthly], let y = products[ProductID.yearly] else { return 0 }
        return PlanMath.savingsPercent(monthly: m.price, yearly: y.price)
    }

    /// Kaufen. `true` = gekauft (Freischaltung ist dann schon aktualisiert)
    @discardableResult
    func purchase(_ id: String) async -> Bool {
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
        do { try await AppStore.sync() } catch { errorText = L("Wiederherstellen fehlgeschlagen") }
        await refreshEntitlements()
    }
}
