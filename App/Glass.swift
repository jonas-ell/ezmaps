import SwiftUI
import UIKit
import EzMapsCore

/// GM-043: Glas-Design (GM-032 Richtung B, Knöpfe GM-036). Werte wie im Prototyp (designs.css .B, onboarding.css, glas.css).
/// Bei „Transparenz reduzieren“ feste Farben ohne Unschärfe.
enum GlassTokens {
    static let accent = SwiftUI.Color(red: 0xB4 / 255.0, green: 0x4D / 255.0, blue: 0xFF / 255.0)
    static let accentDeep = SwiftUI.Color(red: 0x7A / 255.0, green: 0x2B / 255.0, blue: 0xD8 / 255.0)
    static let accentLight = SwiftUI.Color(red: 0xC2 / 255.0, green: 0x7B / 255.0, blue: 0xFF / 255.0)
    static let danger = SwiftUI.Color(red: 1, green: 0x3B / 255.0, blue: 0x4E / 255.0)
    static let warn = SwiftUI.Color(red: 1, green: 0x9F / 255.0, blue: 0x1C / 255.0)
    static let ok = SwiftUI.Color(red: 0x58 / 255.0, green: 0xB0 / 255.0, blue: 0x5F / 255.0)
    static let gold = SwiftUI.Color(red: 1, green: 0xD2 / 255.0, blue: 0x3F / 255.0)
    static let secondary = SwiftUI.Color(red: 0xA9 / 255.0, green: 0xA9 / 255.0, blue: 0xB2 / 255.0)
    /// Glasfläche: rgb(28,28,32) über Material
    static let base = SwiftUI.Color(red: 28 / 255.0, green: 28 / 255.0, blue: 32 / 255.0)

    static let sheet: CGFloat = 26
    static let card: CGFloat = 20
    static let small: CGFloat = 14
}

/// Glasfläche als Hintergrund (Blatt, Karte, Leiste)
struct GlassBackground: ViewModifier {
    var radius: CGFloat
    var tint: SwiftUI.Color?
    @Environment(\.accessibilityReduceTransparency) private var reduce

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background {
                if reduce {
                    shape.fill(tint ?? SwiftUI.Color(white: 0.11))
                } else {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill((tint ?? GlassTokens.base).opacity(tint == nil ? 0.62 : 0.78))
                    }
                }
            }
            .overlay { shape.strokeBorder(SwiftUI.Color.white.opacity(0.18), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
    }
}

extension View {
    func glass(_ radius: CGFloat = GlassTokens.sheet, tint: SwiftUI.Color? = nil) -> some View {
        modifier(GlassBackground(radius: radius, tint: tint))
    }
}

/// Lila Hauptknopf (GM-036): Verlauf über Material, Lichtkante oben, lila Schatten
struct PrimaryGlassButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    var tint: [SwiftUI.Color] = [SwiftUI.Color(red: 190 / 255.0, green: 95 / 255.0, blue: 1), GlassTokens.accentDeep]
    @Environment(\.accessibilityReduceTransparency) private var reduce
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return configuration.label
            .font(.system(size: 18, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                if reduce {
                    shape.fill(tint[0])
                } else {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(LinearGradient(colors: [tint[0].opacity(0.78), tint[1].opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        // Lichtkante oben
                        shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                    }
                }
            }
            .overlay { shape.strokeBorder(SwiftUI.Color.white.opacity(0.38), lineWidth: 0.5) }
            .shadow(color: tint[0].opacity(0.35), radius: 12, y: 8)
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Helles Glas für Nebenknöpfe, Preise, Chips, Zeilen
struct GlassButtonStyle: ButtonStyle {
    var height: CGFloat? = 46
    var radius: CGFloat = 16
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: height == nil ? nil : .infinity)
            .frame(height: height)
            .modifier(NeutralGlass(radius: radius, selected: selected))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Neutrales Glas (weiß 16 % → 6 %), optional lila „gewählt“
struct NeutralGlass: ViewModifier {
    var radius: CGFloat
    var selected = false
    @Environment(\.accessibilityReduceTransparency) private var reduce

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let top: SwiftUI.Color = selected ? GlassTokens.accent.opacity(0.32) : .white.opacity(0.16)
        let bottom: SwiftUI.Color = selected ? GlassTokens.accent.opacity(0.16) : .white.opacity(0.06)
        return content
            .background {
                if reduce {
                    shape.fill(selected ? GlassTokens.accentDeep : SwiftUI.Color(white: 0.2))
                } else {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
                        shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                    }
                }
            }
            .overlay { shape.strokeBorder(selected ? GlassTokens.accent : SwiftUI.Color.white.opacity(0.28), lineWidth: selected ? 1.5 : 0.5) }
    }
}

extension View {
    func neutralGlass(_ radius: CGFloat = 16, selected: Bool = false) -> some View {
        modifier(NeutralGlass(radius: radius, selected: selected))
    }
}

/// Runder Glasknopf (Zurück, Schließen, Teilen, Kartenknöpfe)
struct GlassRoundButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 44
    var tint: SwiftUI.Color = .white
    let action: () -> Void

    /// GM-045: kräftige HUD-Knöpfe von Codex (Assets/Generated/Icons/HUD) statt SF Symbols, wo es eins gibt
    static let hud = ["location.north.line": "hud-recenter", "paintpalette": "hud-styles", "map": "hud-explore",
                      "gearshape": "hud-settings", "chevron.left": "hud-back", "xmark": "hud-close",
                      "star": "hud-star", "star.fill": "hud-star-filled", "magnifyingglass": "hud-search",
                      "plus.magnifyingglass": "hud-zoom-in", "minus.magnifyingglass": "hud-zoom-out",
                      "arrow.up.and.down.and.arrow.left.and.right": "hud-pan",
                      "speaker.wave.2.fill": "hud-volume-on", "speaker.slash.fill": "hud-volume-off"]

    var body: some View {
        Button(action: action) {
            if let name = Self.hud[systemImage], UIImage(named: name) != nil {
                // Hintergrund wie hud-button-bg.svg: fast schwarz, feiner heller Rand
                Image(name).resizable().interpolation(.high).frame(width: size * 0.62, height: size * 0.62)
                    .frame(width: size, height: size)
                    .background(Circle().fill(SwiftUI.Color(white: 0.043).opacity(0.85)))
                    .overlay(Circle().strokeBorder(SwiftUI.Color.white.opacity(0.18), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .neutralGlass(size / 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Kleines Glas-Etikett
struct GlassChip: View {
    let text: String
    var systemImage: String?
    var iconColor: SwiftUI.Color = GlassTokens.accentLight

    var body: some View {
        HStack(spacing: 6) {
            if let s = systemImage { Image(systemName: s).foregroundStyle(iconColor) }
            Text(text).lineLimit(1)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .neutralGlass(14)
    }
}

/// Kleine Überschrift in Lila, Großbuchstaben (ekick im Prototyp)
struct Kicker: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(GlassTokens.accentLight)
    }
}

/// Fortschrittsbalken (Stufe, Ortsteil, Mission)
struct GlassProgress: View {
    var value: Double
    var marker: Double?
    var height: CGFloat = 8
    var gold = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SwiftUI.Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: gold ? [GlassTokens.gold, SwiftUI.Color(red: 1, green: 0.69, blue: 0)] : [GlassTokens.accentDeep, GlassTokens.accentLight],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, value))))
                    .shadow(color: GlassTokens.accentLight.opacity(0.7), radius: 5)
                if let m = marker {
                    Rectangle().fill(SwiftUI.Color.white.opacity(0.7)).frame(width: 2)
                        .offset(x: geo.size.width * CGFloat(min(1, max(0, m))))
                }
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityValue(Text("\(Int(value * 100)) %"))
    }
}

/// GM-038: Uhrzeit oben auf hellen Karten lesbar – weicher dunkler Verlauf hinter der Statusleiste
struct StatusBarScrim: View {
    var body: some View {
        LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: 58)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// Blatt-Griff
struct SheetGrabber: View {
    var body: some View {
        Capsule().fill(SwiftUI.Color.white.opacity(0.3)).frame(width: 36, height: 5).frame(maxWidth: .infinity)
    }
}
