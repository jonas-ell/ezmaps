# Asset-Lieferung

Umsetzung von `docs/ASSETS_CODEX.md`. Einstieg zur visuellen Abnahme:
[`index.html`](index.html). Die Vorschauen funktionieren lokal ohne Server und
zeigen jede Datei in 1×, 2× und 4×; Pixel-UI-Icons zusätzlich in 8×.

| Ordner | Inhalt |
|---|---|
| `Icons/{Neon,Western,Pixel}` | Je 43 identisch benannte UI-Icons; Pixel zusätzlich als @4x |
| `Maneuvers/{Neon,Western,Pixel}` | Je 25 Manöver, einschließlich fünf Kreisverkehr-Ausfahrten |
| `Blips/{Neon,Western,Pixel}` | Je elf Kartensymbole; Pixel zusätzlich als @4x |
| `Player` | Zwei Vektorpfeile und acht Auto-Richtungen, jeweils mit @4x |
| `CarPlay` | 13 Vorlagen, jeweils 30 pt sowie `-list`/`-map` mit 44 pt |
| `Badges` | Zwölf Motive in Gold, Silber, Bronze und Locked: 48 SVGs |
| `AppIcon` | Standard, Dark, Tinted; jeweils 1024×1024, deckendes RGB |
| `Store` | Neon, Western, Pixel; jeweils 1290×2796, ohne Text |

## Herstellung und Wiederholbarkeit

Alle Geometrien und Pixelraster wurden für dieses Projekt neu erstellt; keine
Icon-Bibliothek und keine Spielgrafiken wurden als Quelle verwendet.

```sh
python tools/assets/generate.py
python tools/assets/validate.py
```

Benötigt Python 3.10+ und Pillow 9+. `generate.py` erzeugt Vektoren, native
Pixelraster, Vorschauen und Manifest. Die Bildgenerator-Ausgaben werden dabei
nicht überschrieben. `validate.py` prüft die vollständige Lieferung einschließlich
der Bildgenerator-Ausgaben: Dateinamen, SVG-XML, viewBox, Maße, Farbraum,
Transparenz, Pixelpalette, exakte Nearest-Neighbor-Exporte und Vorschau-Links.

App-Icons und Store-Grafiken stammen aus dem eingebauten `image_gen`-Tool.
Die tatsächlich verwendeten Prompts stehen in `imagegen-prompts.json`.
`artwork-provenance.json` dokumentiert Originaldateinamen und Exportmaße.
`tools/assets/import_artwork.py NAME SOURCE.png` übernimmt eine neue Ausgabe,
normalisiert ihre Größe ohne Beschnitt und aktualisiert Vorschauen/Manifest.
Pixel-Store-Grafiken werden per Nearest Neighbor skaliert, andere Marketingbilder
per Lanczos. Tinted wird beim Export auf neutrales Graustufen-RGB normalisiert.

## Verwendung

- SVG-UI-Icons und Manöver verwenden `currentColor`; die Vorschauen betten sie
  inline ein. Im Asset-Katalog als Template verwenden und Vektordaten erhalten.
  Beim Import gegebenenfalls `currentColor` auf Schwarz auflösen; die Originale
  bleiben als einfärbbare Quellen erhalten.
- Farbige Blips, Spieler und Abzeichen als Originalbilder verwenden.
- Pixelraster mit Nearest Neighbor skalieren (`.interpolation(.none)` in SwiftUI).
  `@4x` sind explizite Vorschau-/Exportdateien, keine iOS-Screen-Scale-Zuweisung.
- Das Nord-/Süd-Auto hat 9×13 Pixel, Ost/West 13×9, diagonale Richtungen 17×17.
  Alle mittig am Spieleranker ausrichten. Die erweiterten Flächen verhindern
  Beschnitt bei Drehung. Dateisuffixe sind `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw`.
- Kreisverkehr: Zufahrt von unten, Verlauf gegen den Uhrzeigersinn, für Rechtsverkehr.
- `cp-parking` verwendet wegen der ausdrücklichen textfreien CarPlay-Vorgabe
  ein geparktes Auto. Die übrigen CarPlay-Vorlagen übernehmen Neon-Geometrien.
- Die fertigen Quelldateien liegen hier zur Abnahme; dieser Auftrag verändert
  weder App-Oberflächen noch die bestehende Xcode-Projektkonfiguration.

Die unter „Nicht von Codex“ genannten Schriften, Kartenquellen, Verkehrszeichen
und Stimmen gehören nicht zu dieser Asset-Lieferung.
