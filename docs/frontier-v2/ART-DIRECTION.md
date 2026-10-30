# Visuelle Spezifikation V2

Die maßgeblichen Bilder stehen in `Reference/`. Folgende Werte übersetzen deren Gestaltung in Startparameter; sie wurden nicht aus einem fertigen MapLibre-Rendering kalibriert.

| Bestandteil | Vorgabe | Vermeiden |
|---|---|---|
| Gelände | zusammenhängende hierarchische Bergrücken und Täler aus DEM | runde dekorative Höhenlinien, zufällige Berge |
| Licht | Nordwest 315°, Schatten nach Südost, an Karte gebunden | wechselnde Lichtquelle beim Drehen |
| Boden | `#A69E70`, trockene Bereiche `#B4A77B` | einheitliche große flache Blöcke |
| Wald | Grundfarbe `#626A3E`, feine Canopy-Textur, Relief bleibt sichtbar | gestempelte große Bäume, harte Kachelgrenzen |
| Fels | warm `#B7AD85`, helle Hangkanten `#D5CAA6` | graue Plastikberge, überstrahlende weiße Flächen |
| Wasser | `#98ADB0`, ruhige Fläche, Ufer `#666F4A` | kräftiges Comicblau, Wellenzeichen überall |
| Gebäude | `#3D3D2A`, echte Grundrisse | erfundene Rasterviertel |
| Straßen | `#D5C38C`, schmale Einfassung `#69613F` | breite weiße Verkehrsflächen in Übersicht |
| Route | Amber `#E0A047`, dunkle Einfassung | Neon-Glow oder sehr dicke Route |
| Icons | Creme `#F4E7C2`, Kontur `#303121` | Plaketten und große farbige POI-Kreise |

## Maßstäbe

Die Zielbilder zeigen eine regionale Übersicht. Sie sind keine Vorgabe, während jeder Fahrt genau diesen weiten Ausschnitt zu halten. Bei näherem Zoom bleiben Farben und Geländecharakter gleich; Straßendetails und Schrift wachsen sinnvoll mit.

| Zoom | Hauptstraße / Nebenstraße | Relief-Intensität | Material |
|---|---|---|---|
| 8–10 | ca. 0,8–1,2 / 0,4–0,6 px | ca. 0,65–0,75 | fein, ruhig |
| 12 | 1,5 / 0,8 px | 0,8 | Waldstruktur erkennbar |
| 15 | 2,8 / 1,5 px | 0,55 | weniger Textur |
| 18 | 5,5 / 3,3 px | 0,30 | Straßen/Labels führen |

Werte in logischen Style-Pixeln. Kontur zusätzlich ca. 0,8 px; Route bei z13 innen 4 und außen 6 px. Für reale Displayauflösung, Neigung und Straßenkomplexität kalibrieren. Keine unverhältnismäßig breite Straße, nur um fehlendes Relief zu kaschieren.

## UI

Die dunklen Panels der Referenz sind Hintergrundflächen mit geringer Eigenwirkung. Ungefähr `#222719` bei 90–95 % Deckkraft, Schrift cremefarben. Keine großen Rahmen um die Karte. Mit App-spezifischen Safe-Areas arbeiten. HUD-Glyphen auf kontrastreichen dunklen Flächen anzeigen. Fadenkreuz bei Pan, nicht dauerhaft über aktiver Navigation.

## Materialdateien

- `fv2-paper-grain`: schwaches transparentes Druckkorn über Grundfarbe.
- `fv2-forest-canopy`: dichter kleinteiliger Bewuchs, nur in echtem Wald-Layer.
- `fv2-grass-mottle`: schwache Vegetationsmischung, nur geeignete Wiesen/Grünflächen.
- `fv2-rock-grain`: feines Felskorn, nur Fels-/Gesteinsflächen, keine Höheninformation.
- `fv2-water-grain`: sehr zurückhaltende Wasserunregelmäßigkeit.

Alle 256²-Basisdateien periodisch; 512² ist der 2×-Atlas-Export. 768² und 1024² dienen weiteren Export-/Bearbeitungszwecken. Die Texturen dürfen sichtbare Landnutzungsflächen nicht überlagern, für die sie nicht gelten.

Die exakte organische Malstruktur der KI-Illustration ist nicht durch ein einzelnes Pattern reproduzierbar. Das entscheidende Zusammenspiel ist echter Reliefverlauf + echte Landnutzung + passende Farben + feine Materialstruktur + zurückhaltende Vektorlinien.
