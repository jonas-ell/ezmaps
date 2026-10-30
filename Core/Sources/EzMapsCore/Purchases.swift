import Foundation

/// GM-043: Produkte und Freischaltung (GM-038 Plus, GM-039 Einzelkauf, GM-042 ohne Gratis-Zeitraum).
/// Die App fragt StoreKit nach den gekauften Produkt-IDs und gibt sie hier hinein – die Regeln sind so testbar.
public enum ProductID {
    public static let yearly = "ezmaps.plus.yearly"
    public static let monthly = "ezmaps.plus.monthly"
    public static let lifetime = "ezmaps.plus.lifetime"
    public static let plus: [String] = [lifetime, yearly, monthly]

    /// Einzelkauf eines Stils (nil = Klassik, gratis)
    public static func single(_ style: MapStyle) -> String? {
        switch style {
        case .classic: return nil
        case .neonCity: return "ezmaps.style.neon"
        case .wildWest: return "ezmaps.style.western"
        case .pixelQuest: return "ezmaps.style.pixel"
        case .toyTown: return "ezmaps.style.toy"
        case .frontier: return "ezmaps.style.frontier"
        }
    }

    public static var all: [String] { plus + MapStyle.allCases.compactMap(single) }
}

/// Was der Nutzer besitzt
public struct StyleAccess: Equatable, Sendable {
    public var owned: Set<String>

    public init(owned: Set<String> = []) { self.owned = owned }

    /// Plus (Abo oder für immer) schaltet alles frei
    public var hasPlus: Bool { !owned.isDisjoint(with: ProductID.plus) }

    public func isUnlocked(_ style: MapStyle) -> Bool {
        if style.isFree || hasPlus { return true }
        guard let id = ProductID.single(style) else { return true }
        return owned.contains(id)
    }

    /// Einzeln gekauft (bleibt nach Kündigung von Plus)
    public func ownsSingle(_ style: MapStyle) -> Bool {
        guard let id = ProductID.single(style) else { return false }
        return owned.contains(id)
    }

    public var unlocked: [MapStyle] { MapStyle.allCases.filter(isUnlocked) }
}

/// Rechnen für die Paywall (Preise kommen immer aus StoreKit)
public enum PlanMath {
    /// Jahrespreis pro Monat, auf Cent abgerundet (29,99 → 2,49; die Paywall zeigt „2,50 €“ nur, wenn StoreKit so formatiert)
    public static func perMonth(yearly: Decimal) -> Decimal {
        var v = yearly / 12
        var r = Decimal()
        NSDecimalRound(&r, &v, 2, .down)
        return r
    }

    /// „spare X %“: Jahr gegen 12 × Monat, auf 5 % abgerundet (ehrlich, nie mehr als echt)
    public static func savingsPercent(monthly: Decimal, yearly: Decimal) -> Int {
        let full = monthly * 12
        guard full > 0, yearly < full else { return 0 }
        let pct = NSDecimalNumber(decimal: (full - yearly) / full * 100).doubleValue
        return Int(pct / 5) * 5
    }
}
