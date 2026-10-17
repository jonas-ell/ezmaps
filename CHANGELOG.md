# Changelog

Neue Einträge oben. Nummernreihe: `GM-xxx`.

## GM-002 – Name „EzMaps“ und erste Stil-Vorschau „Neon City“

**Ziel:** App-Name festlegen und den ersten Spielstil aus echten OSM-Daten (Idstein) zeigen.

**Dateien:** alle Dateien (Umbenennung `GameMap` → `EzMaps`, `GameMapCore` → `EzMapsCore`), `tools/preview/prep.py`, `tools/preview/render.html`, `tools/preview/shoot.py`, `docs/previews/neon-*.png`, `docs/ASSETS_CODEX.md`, `.gitignore`, `.gitattributes`

**Geändert:**
- Name, Bundle-ID `com.jonaselfounti.ezmaps`, Package und Entitlements umbenannt
- Vorschau-Werkzeug: Overpass-Daten → Ebenen in Metern, Dijkstra-Route nach Straßentyp gewichtet, Abbiegungen aus 25 m davor/danach
- Renderer (HTML-Canvas + Playwright): Übersicht, CarPlay 1920 × 720, iPhone 1179 × 2556, rundes Kombiinstrument-Radar
- Liste mit Asset-Prompts für Codex (App-Icon, Blips, Pfeile, Store-Grafiken)

**Tatsächlich geprüft:** Vorschau-Bilder auf Windows gerendert und angesehen; Route und Abbiegungen plausibel (Idstein, 3,3 km).

**Ungetestet:** Swift-Code weiterhin nicht gebaut (`xcodegen`, `xcodebuild`, `swift test`).

## GM-001 – Grundgerüst

**Ziel:** Leeres, baubares Projekt für das Spiel-Karten-Navi (iPhone + CarPlay).

**Dateien:** `project.yml`, `Core/Package.swift`, `App/*`, `Core/*`, `.gitignore`, `README.md`, `CHANGELOG.md`

**Geändert:**
- XcodeGen-Projekt, iOS 17, App-Target `EzMaps`
- CarPlay-Szene (`CarPlaySceneDelegate`) mit leerem Kartenfenster und `CPMapTemplate`
- Entitlement `com.apple.developer.carplay-maps` (nur für Simulator, bis Apple es erteilt)
- `EzMapsCore` als Swift-Package mit `MapStyle` und Tests
- `L("…")` mit englischen Texten in `en.lproj/Localizable.strings`

**Tatsächlich geprüft:** nichts – auf Windows geschrieben, kein Xcode/Swift verfügbar.

**Ungetestet:** `xcodegen generate`, `xcodebuild`, `swift test`, CarPlay-Szene im Simulator.
