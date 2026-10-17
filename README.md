# EzMaps: Game Maps

Echtes Navi für iPhone und CarPlay im Look von Open-World-Spielen – mit eigenen Stilen
(keine Spielnamen oder -inhalte) und „Nebel des Krieges“.

## Bauen (auf dem Mac)

```sh
xcodegen generate
xcodebuild -project EzMaps.xcodeproj -scheme EzMaps \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
(cd Core && swift test)   # Logik in EzMapsCore
```

## Prototyp im Browser (iPhone + CarPlay, klickbar)

```sh
python tools/prototype/serve.py      # öffnet http://localhost:8765/tools/prototype/
```

- iPhone 16 (393 × 852 pt) und CarPlay nebeneinander, gemeinsamer Zustand.
- Echtes Routing über OSM-Straßen von Idstein, simulierte Fahrt mit Ansagen (Browser-Sprachausgabe), vier Stile.
- Pricedown liegt nur lokal in `tools/prototype/fonts/pricedown.otf` (nicht im Repo). Fehlt die Datei, wird Impact verwendet.
- Bildschirmfotos: `python tools/prototype/shots.py` → `docs/previews/`.
- Daten neu bauen: Rohdaten per Overpass nach `tools/prototype/raw/` laden (`idstein.json`, `named.json`, `hexen.json`), dann `cd tools/prototype && python prep.py raw/idstein.json raw/named.json raw/hexen.json data/idstein.json`.

## Aufbau

- `App/` – SwiftUI-App und CarPlay-Szene
- `Core/` – plattformunabhängige Logik (`EzMapsCore`) und Tests
- `project.yml` – XcodeGen (kein `.xcodeproj` im Repo)

Kartendaten: © OpenStreetMap-Mitwirkende (ODbL).
