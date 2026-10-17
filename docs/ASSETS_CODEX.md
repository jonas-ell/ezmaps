# Asset-Aufträge für Codex

Jeder Block unten ist ein fertiger Prompt zum Kopieren. Ergebnisse nach `Assets/Generated/<Ordner>/`.

## Regeln für alle Assets (rechtlich wichtig)

- Komplett eigenes Design. Keine Logos, Icons, Figuren, Fahrzeuge oder Namen aus bestehenden Spielen.
- Kein Text in Grafiken (außer ausdrücklich verlangt, z. B. „P“).
- Linien-Icons als **SVG** (`viewBox="0 0 24 24"`), damit Xcode sie als Vektor („Preserve Vector Data“) und als Template einfärben kann.
- Pixel-Assets als **PNG im Originalraster** (z. B. 16 × 16 px) mit harten Kanten. Die App skaliert sie mit „nearest neighbor“ hoch.
- Zu jedem Ordner eine `index.html`, die alle Dateien auf dem passenden Hintergrund in 1×, 2× und 4× zeigt (zur Abnahme).

## Stil-Farben

| | Neon City | Wild West | Pixel Quest | Toy Town |
|---|---|---|---|---|
| Akzent / Route | `#A13DF0` | `#C0261F` | `#FFCC33` | `#FF7A00` |
| Zweitakzent | `#D9AD3A` | `#B8862B` | `#FF6B3D` | `#1F6FE0` |
| Panel | `#000000` 80 % | Papier `#EFE2C0` | Navy `#1A2A6C` + weißer Rahmen | Weiß, Rand `#2F3640` 2,5 pt, Radius 14 |
| Text | `#FFFFFF` | Tinte `#2E1E10` | `#FFFFFF` | `#2F3640` |
| Kontur | `#000000` | `#3A2414` | `#000000` | `#2F3640` |
| Kartenhintergrund | `#3D3E40` | `#DCC59A` | Gras `#60A83A` | Rasen `#8DC63F` |

---

## 1. UI-Icons (Knöpfe, Tab-Leiste, Listen) – Grundsatz

Alle Stile nutzen **dieselben Icon-Namen**. Die Varianten unterscheiden sich nur in der Zeichenart.

```
Create an original, consistent UI icon set as SVG files, viewBox "0 0 24 24",
stroke-only, stroke="currentColor", stroke-width 2, stroke-linecap round,
stroke-linejoin round, no fills except tiny dots, 2px safe margin, optically balanced,
crisp at 20px and 60px. Original geometry – do not copy SF Symbols, Material Icons,
Lucide or any game UI. File names exactly as listed, folder Assets/Generated/Icons/Neon/.

Tab bar:      ic-tab-map, ic-tab-explore (compass), ic-tab-styles (diamond/gem),
              ic-tab-profile
Map buttons:  ic-search, ic-mic, ic-layers (style switch), ic-friends, ic-locate
              (navigation arrow for re-center), ic-north (compass needle with N),
              ic-zoom-in, ic-zoom-out, ic-volume-on, ic-volume-off, ic-clip
              (record 10s video clip), ic-share, ic-more (three dots), ic-close,
              ic-back, ic-chevron, ic-reroute, ic-settings, ic-end-route (flag with X),
              ic-route-options (three branching lines), ic-favorite (star),
              ic-history (clock arrow), ic-contact (person card), ic-calendar
Quick chips:  ic-home, ic-work (briefcase), ic-fuel (pump), ic-parking (P in rounded
              square), ic-charging (plug with bolt), ic-food (fork and knife)
Explore:      ic-fog (cloud with eye), ic-district (map pin with border), ic-badge
              (medal), ic-goal (target), ic-stats (bar chart), ic-streak (flame)
Privacy:      ic-lock, ic-eye-off, ic-location-off
Also write index.html previewing all icons white on #3D3E40 and black on #FFFFFF.
```

### 1b. Wild-West-Variante

```
Recreate the exact same icon list and file names as hand-inked engraving-style SVGs
for a parchment map theme. Folder Assets/Generated/Icons/Western/.
viewBox "0 0 24 24", stroke="currentColor" (will be tinted #2E1E10), stroke-width 1.8,
slightly irregular hand-drawn strokes (subtle wobble, varying width via 2 overlapping
paths is ok), small serif-like flicks at line ends, no gradients.
Feel: 19th-century map cartography, not cartoon. Fully original, no game references.
index.html preview on #EFE2C0.
```

### 1c. Pixel-Quest-Variante

```
Recreate the exact same icon list and file names as pixel art PNGs, 16x16 px,
1px outline in #000000, fill #FFFFFF, max 1 accent color #FFCC33, transparent background,
no anti-aliasing, no semi-transparent pixels. Folder Assets/Generated/Icons/Pixel/.
Style: original 16-bit RPG menu icons, readable silhouettes, centered on the 16x16 grid.
Also export each at 4x (64x64) with nearest-neighbor scaling as <name>@4x.png.
Do not copy sprites from any existing game. index.html preview on #1A2A6C at 4x and 8x.
```

## 2. Abbiege-Pfeile (alle Stile)

```
Write an original set of turn-by-turn maneuver arrows as SVG (viewBox 0 0 96 96,
stroke="currentColor", stroke-width 10, round caps and joins, no fill, transparent):
straight, slight-left, left, sharp-left, slight-right, right, sharp-right,
uturn-left, uturn-right, roundabout-exit-1 … roundabout-exit-5 (counter-clockwise,
right-hand traffic as in Germany), merge-left, merge-right, fork-left, fork-right,
ramp-exit-right, ramp-exit-left, keep-left, keep-right, destination (flag),
destination-left, destination-right.
File names maneuver-<name>.svg in Assets/Generated/Maneuvers/Neon/.
Then the same set as hand-inked versions in Maneuvers/Western/ (stroke-width 8, slight
wobble) and as 24x24 pixel-art PNGs (white with 1px black outline, no anti-aliasing)
in Maneuvers/Pixel/. Add index.html previews. Original geometry only.
```

## 3. Karten-Symbole (Blips)

### Neon City

```
Original map marker glyphs as SVG, viewBox 0 0 32 32, no background circle:
a solid glyph in the accent color with a 3px black outline (paint-order stroke).
Files in Assets/Generated/Blips/Neon/:
blip-fuel #F08A2C (pump), blip-parking #5FB6FF (bold "P"), blip-food #7EE06A (fork+knife),
blip-shop #F5D742 (cart), blip-charging #33E1C7 (plug+bolt), blip-hospital #FF5A5A (cross),
blip-friend #FF4FD8 (person head), blip-home #FFFFFF, blip-work #FFFFFF,
blip-destination #F5D742 (solid circle with 3px black ring), blip-waypoint #A13DF0 (diamond).
Simple, readable at 18px on #3D3E40. index.html preview.
```

### Wild West

```
Same list and names as ink-stamp map symbols for an old parchment map, SVG viewBox 0 0 32 32,
fill and stroke #3A2414 with a 3px parchment-colored (#F2E4BF) halo outline,
engraving style. blip-destination is a red (#C0261F) hand-drawn "X" with parchment halo.
Folder Assets/Generated/Blips/Western/. Preview on #DCC59A.
```

### Toy Town

```
Same list and names as round road-sign style markers for a kids' play-mat map: SVG viewBox 0 0 32 32,
white outer ring (2px), colored disc (parking #1F6FE0, fuel #F08A2C, food #2FB94A, shop #F5D742,
charging #33E1C7, hospital #FF5A5A), white bold glyph, thin #2F3640 outline. Destination = checkered
flag on a pole. Folder Assets/Generated/Blips/Toy/. Preview on #8DC63F.
```

### Pixel Quest

```
Same list and names as original 8x8 or 10x10 pixel sprites (PNG, transparent, no AA),
16-bit RPG overworld feel: parking = blue sign with white P, fuel = red pump,
food = drumstick, shop = yellow cart, charging = green battery with bolt,
hospital = white box with red cross, friend = tiny smiling face, home = small house,
work = small tower, destination = treasure chest (closed, gold lock), waypoint = gold coin.
Export 1x and @4x (nearest neighbor). Folder Assets/Generated/Blips/Pixel/.
```

## 4. Spieler-Markierung

```
Neon City (SVG, viewBox 0 0 64 64): arrowhead pointing up with notch at bottom,
fill #E9E9E9, outline 5px #000000. player-neon.svg
Wild West (SVG): same silhouette, fill #F6EAD0, outline #3A2414, slightly hand-inked edge.
player-western.svg
Pixel Quest (PNG pixel art): a chunky pixel arrowhead / bullet shape, 7x10 px pointing up:
1px black outline, white (#FFFFFF) core, light grey (#DCDCDC) body, darker grey (#A4A4A4)
shade on the right and bottom edge, flat back end, 1px pointed tip (reference: user sketch).
No AA. Provide 8 headings (N, NE, E, SE, S, SW, W, NW) as player-pixel-<dir>.png plus @4x.
Toy Town (SVG, viewBox 0 0 64 64): original toy car seen from above, red body #E8372C,
light-blue windows, yellow headlights, thick #2F3640 outline, soft drop shadow. player-toy.svg
Folder Assets/Generated/Player/. Original design, not copied from any game.
```

## 5. CarPlay-Vorlagenbilder

```
CarPlay bar-button and list images as monochrome template PDFs or SVGs
(single color #000000 on transparent, system tints them), sizes: bar button 30x30 pt,
list item 44x44 pt, map button 44x44 pt. Reuse geometry of the Neon icon set:
cp-search, cp-style, cp-friends, cp-zoom-in, cp-zoom-out, cp-locate, cp-home, cp-work,
cp-fuel, cp-parking, cp-charging, cp-favorite, cp-history.
Folder Assets/Generated/CarPlay/. No text, no color (Apple tints templates).
```

## 6. Abzeichen (Nebel des Krieges)

```
12 original achievement badges as SVG (viewBox 0 0 128 128), circular medal shape,
flat with subtle inner ring, no text. Themes: first-drive, 10-km, 100-km, night-owl
(moon), early-bird (sun), old-town (tower), explorer-25, explorer-50, explorer-100
(map with pin), weekly-goal (target), streak-7 (flame), convoy (three cars, abstract).
Color sets: gold #D9AD3A, silver #B9BEC4, bronze #B87333, locked #555555.
Files badge-<name>-<tier>.svg in Assets/Generated/Badges/. Original artwork.
```

## 7. App-Icon (Bildgenerator)

Datei: `Assets/Generated/AppIcon/appicon-1024.png` (1024 × 1024, quadratisch, ohne Rundung, ohne Transparenz) plus `-dark` und `-tinted`.

```
Original iOS app icon, 1024x1024 PNG, full-bleed square, no rounded corners, no text.
A tilted top-down grey open-world city map at dusk (#3D3E40 land, darker blocks,
light grey streets), a thick flat purple (#A13DF0) GPS route line with a dark edge
sweeping from bottom center to top right, ending at a yellow (#F5D742) destination dot
with black ring; a white arrowhead player marker with black outline at the bottom of
the route. High contrast, readable at 60x60 px. Fully original – no game logos, fonts
or recognizable game map content.
```

## 8. Store-Grafiken (Bildgenerator)

```
Original vertical background 1290x2796 PNG, no text: dark grey open-world city map
fading to black at top and bottom, one thick flat purple (#A13DF0) route line sweeping
diagonally, subtle grain. Empty space in the upper third for a headline. Also two
variants: parchment map with red (#C0261F) route, and pixel-art overworld with gold
(#FFCC33) dotted path. No game references.
```

## Nicht von Codex

- **Schriften:**
  - **Neon City:** *Pricedown* (Typodermic). Die kostenlose Desktop-Lizenz erlaubt nur Bilder und Videos. **Vor Release muss die App-/Embedding-Lizenz gekauft werden.** Bis dahin liegt die Datei nur lokal (`tools/preview/fonts/`, nicht in Git).
  - **Wild West:** *Rye*.
  - **Pixel Quest:** *Press Start 2P* (Überschriften) und *VT323* (Text).
  - **Fließtext:** *Inter*.
  - Rye, Press Start 2P, VT323 und Inter stehen unter der SIL OFL 1.1 und dürfen eingebettet werden; die jeweilige `OFL.txt` kommt ins Bundle.
- **Tempolimit-Schild:** zeichnet die App selbst (amtliches Verkehrszeichen 274, gemeinfrei).
- **Navi-Stimme:** zum Start `AVSpeechSynthesizer`, eigene Sprecher später lizenziert.
- **Kartendaten:** OpenStreetMap (ODbL). Der Hinweis „© OpenStreetMap-Mitwirkende“ ist immer sichtbar.
