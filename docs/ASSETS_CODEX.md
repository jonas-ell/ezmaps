# Asset-Aufträge für Codex – Stil „Neon City“

Regeln für **alle** Assets (rechtlich wichtig):
- Komplett eigenes Design. Keine Logos, Symbole, Schriften, Figuren oder Namen aus bestehenden Spielen.
- Kein Text im Bild (außer wo ausdrücklich verlangt).
- Ergebnis-Dateien in `Assets/Generated/<Ordner>/` ablegen, Dateinamen wie angegeben.

Farbpalette (aus der Vorschau, bitte exakt verwenden):

| Rolle | Hex |
|---|---|
| Hintergrund / Land | `#16191D` |
| Blip-Füllung | `#0D0F12` |
| Route / Akzent (Lila) | `#B04DFF` |
| Ziel (Gelb) | `#FFD23F` |
| Tanken (Orange) | `#FF8A2A` |
| Parken (Blau) | `#3FA9FF` |
| Essen (Grün) | `#4CD964` |
| Krankenhaus (Rot) | `#FF4D5E` |
| Polizei (Indigo) | `#5B7CFF` |
| Spieler-Pfeil | `#F4F6F8` mit Kontur `#0B0D10` |

---

## 1. App-Icon (Bildgenerator)

Datei: `Assets/Generated/AppIcon/appicon-1024.png` (1024 × 1024, quadratisch, **ohne** abgerundete Ecken und ohne Transparenz – iOS rundet selbst).

```
Create an original iOS app icon, 1024x1024 PNG, full-bleed square, no rounded corners,
no transparency, no text, no letters.
Concept: a stylized top-down night city map seen through a game-style circular radar.
A bold white navigation arrow (simple chevron/triangle) in the center pointing up,
a glowing purple (#B04DFF) GPS route line curving from the arrow toward the top right,
ending in a small yellow (#FFD23F) destination dot. Background: very dark charcoal
(#16191D) with subtle grey street grid lines and a few dark green park blocks,
slightly tilted perspective. Thin purple ring around the radar circle.
Style: clean, modern, high contrast, slightly glossy, readable at 60x60 px.
Must be fully original – do not imitate any existing video game logo, map, icon or font.
```

Zusätzlich die gleiche Grafik in einer **dunklen** und einer **getönten** Variante (iOS 18), falls möglich:
`appicon-1024-dark.png`, `appicon-1024-tinted.png` (Graustufen, transparenter Hintergrund).

## 2. Karten-Blips (SVG, Codex schreibt den Code)

Ordner: `Assets/Generated/Blips/`, je eine SVG, `viewBox="0 0 64 64"`, keine Rasterbilder.

```
Write a set of original map marker icons as clean SVG files (viewBox 0 0 64 64).
Each marker: filled circle r=28 in #0D0F12, ring stroke width 4.5 in the accent color,
centered glyph in the accent color, flat, no gradients, no text except where noted,
crisp at 24px. Must be original geometry, not copied from any game or icon set.
Files and glyphs:
- blip-fuel.svg      accent #FF8A2A  – simple fuel pump silhouette
- blip-parking.svg   accent #3FA9FF  – bold letter "P" (geometric sans)
- blip-food.svg      accent #4CD964  – fork and knife
- blip-shop.svg      accent #FFD23F  – shopping cart
- blip-hospital.svg  accent #FF4D5E  – plus cross
- blip-police.svg    accent #5B7CFF  – five-pointed star
- blip-charging.svg  accent #33E1C7  – plug with lightning bolt
- blip-destination.svg accent #FFD23F – solid inner dot r=11
- blip-friend.svg    accent #FF4FD8  – simple person head-and-shoulders
- blip-home.svg      accent #FFFFFF  – simple house
- blip-work.svg      accent #FFFFFF  – briefcase
Also an index.html that shows all icons on #16191D at 24, 48 and 96 px for review.
```

## 3. Spieler-Pfeil (SVG)

Datei: `Assets/Generated/Player/player-arrow.svg`

```
Write an original SVG navigation arrow (viewBox 0 0 64 64): a wide chevron/arrowhead
pointing up with a notch at the bottom, fill #F4F6F8, outline 3px #0B0D10,
soft drop shadow via SVG filter. Plus player-arrow-moving.svg with a subtle purple
(#B04DFF) outer glow. Simple, readable at 32px, not copied from any game.
```

## 4. Abbiege-Pfeile (SVG)

Ordner: `Assets/Generated/Maneuvers/`, `viewBox="0 0 96 96"`, weiß `#FFFFFF`, runde Linienenden, Strichstärke 10.

```
Write a consistent set of original turn-by-turn maneuver arrows as SVG
(viewBox 0 0 96 96, white stroke #FFFFFF, stroke-width 10, round caps and joins,
no fill, transparent background):
straight, slight-left, left, sharp-left, slight-right, right, sharp-right,
uturn-left, uturn-right, roundabout-exit-1 … roundabout-exit-4 (counter-clockwise
German traffic), merge-left, merge-right, fork-left, fork-right, highway-exit-right,
destination (flag), destination-left, destination-right.
File names: maneuver-<name>.svg. Add an index.html preview on #0D0F12.
```

## 5. Onboarding-Bild „Neon City“ (Bildgenerator)

Datei: `Assets/Generated/Onboarding/style-neon-city.png` (1290 × 1290)

```
Original illustration, 1290x1290 PNG, no text: a dark, moody top-down 3D-tilted city map
at night in charcoal tones (#16191D), grey streets, dark green parks, a glowing purple
(#B04DFF) GPS route weaving through the streets toward a yellow (#FFD23F) destination marker,
small round colored map markers, a white navigation arrow in the foreground.
Cinematic, video-game-inspired but fully original – no recognizable game assets,
logos, characters, cars or fonts.
```

## 6. App-Store-Hintergrund (Bildgenerator)

Datei: `Assets/Generated/Store/store-bg.png` (1290 × 2796)

```
Original vertical background, 1290x2796 PNG, no text: abstract dark charcoal (#16191D)
city street grid fading into black at top and bottom, a single glowing purple (#B04DFF)
route line sweeping diagonally, subtle film grain. Leave large empty space in the upper
third for a headline. Fully original, no game references.
```

## Nicht von Codex – bitte so beschaffen

- **Schriften:** Überschriften/Zahlen in **Pricedown** (Typodermic). Die kostenlose Desktop-Lizenz erlaubt nur Bilder/Videos/Grafiken – **für die App muss vor Release eine App-/Embedding-Lizenz bei Typodermic gekauft werden** (typodermicfonts.com). Bis dahin liegt die Datei nur lokal (`tools/preview/fonts/`, nicht in Git). Fließtext in *Inter* (SIL OFL 1.1, frei einbettbar).
- **Navi-Stimme:** zum Start Apples `AVSpeechSynthesizer` (keine Lizenzkosten). Eigene Sprecher später z. B. über ElevenLabs mit kommerziellem Abo.
- **Kartendaten:** OpenStreetMap (ODbL) – Hinweis „© OpenStreetMap-Mitwirkende“ immer sichtbar.
