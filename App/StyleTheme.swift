import SwiftUI
import UIKit
import EzMapsCore

/// GM-043: Farben und Schrift je Kartenstil. Mirror in tools/prototype/js/map.js (STYLES) – change both.
struct StyleTheme {
    let route: UIColor
    let routeEdge: UIColor
    let alternative: UIColor
    let background: UIColor
    /// heller Kartenstil (Klassik, Wild West, Toy Town): Bedienelemente bleiben dunkles Glas, Hinweis-Text dunkler Rand
    let isLight: Bool

    static func of(_ style: MapStyle) -> StyleTheme {
        switch style {
        case .classic:
            return StyleTheme(route: hex(0x1a73e8), routeEdge: hex(0x0b3d91), alternative: UIColor(red: 90 / 255.0, green: 110 / 255.0, blue: 140 / 255.0, alpha: 0.5),
                              background: hex(0xf2efe9), isLight: true)
        case .neonCity:
            return StyleTheme(route: NeonColors.route, routeEdge: NeonColors.routeEdge, alternative: NeonColors.alternative,
                              background: NeonColors.background, isLight: false)
        case .wildWest:
            return StyleTheme(route: hex(0xc0261f), routeEdge: hex(0x4a0d0a), alternative: UIColor(red: 90 / 255.0, green: 60 / 255.0, blue: 30 / 255.0, alpha: 0.45),
                              background: hex(0xc4ac80), isLight: true)
        case .pixelQuest:
            return StyleTheme(route: hex(0xffcc33), routeEdge: hex(0x7a4a00), alternative: UIColor(white: 1, alpha: 0.6),
                              background: hex(0x60a83a), isLight: false)
        case .toyTown:
            return StyleTheme(route: hex(0xff7a00), routeEdge: hex(0xffffff), alternative: UIColor(white: 1, alpha: 0.75),
                              background: hex(0x8dc63f), isLight: true)
        }
    }

    static func hex(_ v: Int) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xff) / 255.0, green: CGFloat((v >> 8) & 0xff) / 255.0, blue: CGFloat(v & 0xff) / 255.0, alpha: 1)
    }
}

/// GM-034/035: Stilname in der Projekt-Schrift (Neon City → Pricedown, sonst Anton; Wild West → Rye;
/// Pixel Quest → Press Start 2P; Toy Town → Fredoka Bold; Klassik → System). Nur der Name, keine anderen Texte.
struct StyleName: View {
    let style: MapStyle
    var size: CGFloat = 17

    var body: some View {
        let title = L(style.titleKey)
        switch style {
        case .neonCity:
            Text(title)
                .font(.custom(UIFont(name: "Pricedown-Black", size: size) != nil ? "Pricedown-Black" : "Anton-Regular", size: size * 1.18))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                .shadow(color: .black, radius: 0, x: -1.5, y: -1.5)
                .shadow(color: .black, radius: 0, x: 1.5, y: -1.5)
                .shadow(color: .black, radius: 0, x: -1.5, y: 1.5)
        case .wildWest:
            Text(title).font(.custom("Rye-Regular", size: size))
        case .pixelQuest:
            Text(title).font(.custom("PressStart2P-Regular", size: size * 0.72)).shadow(color: .black, radius: 0, x: 2, y: 2)
        case .toyTown:
            Text(title).font(.custom("Fredoka-Bold", size: size))
        case .classic:
            Text(title).font(.system(size: size, weight: .bold))
        }
    }
}

/// Für `.sheet(item:)` (Shop, „Test vorbei“)
extension MapStyle: Identifiable {
    public var id: String { rawValue }
}
