# GameMap (Arbeitstitel)

Echtes Navi für iPhone und CarPlay im Look von Open-World-Spielen – mit eigenen Stilen
(keine Spielnamen oder -inhalte) und „Nebel des Krieges“.

## Bauen (auf dem Mac)

```sh
xcodegen generate
xcodebuild -project GameMap.xcodeproj -scheme GameMap \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
(cd Core && swift test)   # Logik in GameMapCore
```

## Aufbau

- `App/` – SwiftUI-App und CarPlay-Szene
- `Core/` – plattformunabhängige Logik (`GameMapCore`) und Tests
- `project.yml` – XcodeGen (kein `.xcodeproj` im Repo)

Kartendaten: © OpenStreetMap-Mitwirkende (ODbL).
