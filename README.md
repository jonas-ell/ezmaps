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

## Aufbau

- `App/` – SwiftUI-App und CarPlay-Szene
- `Core/` – plattformunabhängige Logik (`EzMapsCore`) und Tests
- `project.yml` – XcodeGen (kein `.xcodeproj` im Repo)

Kartendaten: © OpenStreetMap-Mitwirkende (ODbL).
