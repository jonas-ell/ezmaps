# Swift-Erfahrungen aus dem Vorgängerprojekt (Mimic Sounds)

Jeder Punkt hat dort wirklich einen Build-Fehler, einen Absturz, einen Darstellungsfehler oder eine
App-Review-Ablehnung verursacht. **Vor jeder Swift-Änderung lesen.**

## 1. Ohne Compiler arbeiten

- **Syntaxprüfung ist kein Build.** Typfehler fallen erst auf dem Mac auf. Echte Fehler:
  - `ambiguous use of operator '*'`: `Double` mal `CGFloat` gemischt. Immer explizit typisieren (`let wobble: CGFloat = …`), `CGFloat(...)` umwandeln. Dasselbe bei `cos`/`sin`.
  - `switch must be exhaustive`: neue `enum`-Fälle in **jedem** `switch` nachziehen. Vor dem Ändern eines `enum` mit grep alle `switch` suchen.
  - Argumentreihenfolge exakt wie in der Deklaration, auch bei Standardwerten.
  - `$0` in einer Closure mit benannten Parametern ist verboten.
  - Lokale Konstante mit Methodennamen (`let x = x(…)`) → „ambiguous expression“.
  - Zu lange Ausdrücke → „unable to type-check“. In typisierte Zwischenvariablen aufteilen.
  - Fehlendes `self.` in Closures.
  - Neue Dateien im `Package.swift`-Pfad vergessen → `swift test` findet sie nicht.
- **SDK-Namen nicht raten** (Beispiel Google Mobile Ads 13: `InterstitialAd`, `Request`, `MobileAds.shared`). Im Zweifel Compiler-Meldungen als Quelle nehmen.
- **Mehrdeutige Typen:** Frameworks mit generischen Namen (z. B. RiveRuntime `Color`) → `SwiftUI.Color` ausschreiben.

## 2. SwiftUI-Fallen

- `GeometryReader` setzt Inhalt oben links → `.frame(width: geo.size.width, height: geo.size.height)`.
- Hintergrundbild mit `.scaledToFill()` direkt im `ZStack` bläht den Screen auf → `.background { Image(...).resizable().scaledToFill() }` + `.clipped()`.
- **Kleine Bildschirme:** Apple prüft iPhone-Apps auf dem iPad im Fenster **375 × 667 pt** („crowded layout“-Ablehnung). Jeden Screen absichern: scrollbar machen (`FitOrScroll`), feste Höhen bei Kompakthöhe < 700 pt verkleinern, `.minimumScaleFactor`/`.lineLimit`.
- Pro Frame berechnete Bewegung (`TimelineView(.animation)`) nicht zusätzlich implizit animieren → `.animation(nil) { … }` abschirmen. Keine Bewegung direkt aus verrauschten Sensorwerten, keine Sub-Pixel-Bewegung, keine nachschwingenden Federn bei Dauerbewegung.
- Posen nicht überblenden (doppelt/halbdurchsichtig) → hart schneiden.
- `.onChange(of:)` feuert nur bei echter Änderung → zusätzlich `.onAppear`.
- `hashValue` ist pro Start zufällig → eigener Hash (FNV-1a) für stabile Werte.
- Reduce Motion respektieren.

## 3. Sprache und Nebenläufigkeit

- `didSet`, das sich selbst zuweist, ruft sich endlos auf (Signal 11). Nur zuweisen, wenn sich der Wert wirklich ändert:
  `var level: Double = 0 { didSet { let c = min(1, max(0, level)); if c != level { level = c } } }`
- UI-Zustand in `@MainActor @Observable`-Klassen. In Tests kleine Methoden aufrufen statt `await MainActor.run { … }` (crashte).
- `Task.sleep`: Task merken, bei neuem Ereignis `cancel()`, nach jedem `sleep` `guard !Task.isCancelled`.
- Lange Abläufe mit „Generation“-UUID schützen.
- `async let` + `Task.detached` + `@unchecked Sendable` vorsichtig: erst bauen, Meldungen lesen.

## 4. Apple-Frameworks

- **StoreKit 2:** Woche kann als `.day` × 7 kommen – alle Einheiten auswerten. Testphasen-Text nur bei echter Berechtigung. Preise immer aus StoreKit.
- **ATT/Einwilligung:** erst UMP-Dialog, ATT nur danach und nur bei Zustimmung.
- **Keine unnötigen Frameworks** (CallKit führte zur Ablehnung – China). Stattdessen `AVAudioSession.isOtherAudioPlaying`, `secondaryAudioShouldBeSilencedHint`.
- **Audio-Sitzung:** Kategorie bewusst wählen; danach `setActive(false, options: .notifyOthersOnDeactivation)`. Stop einer Wiedergabe deaktiviert die Sitzung – Reihenfolge beachten. Navi-Ansagen: Ducking (`.voicePrompt` + `.duckOthers`) statt Unterbrechen.
- Assets prüfen: `UIImage(named:) != nil`, sauberer Ersatz.
- **Lokalisierung:** jeder neue Text sofort mit Englisch; Platzhalter in beiden Sprachen gleich; Plural beachten.
- **Firebase:** `firestore.rules` sind Code; Grenzen auch serverseitig prüfen.

## 5. Projektstruktur

- Logik plattformunabhängig in `Core/` (Package) → `swift test` ohne Simulator. Für das Navi: Routenlogik, Nebel-Raster, Statistik.
- **Formeln doppelt halten:** Prototyp-JS (`tools/prototype/js/route.js`) und Swift (`Core/`) gemeinsam ändern. Kommentar „Mirror in … – change both“.
- Jeder Fix bekommt einen Kommentar mit Grund (`// GM-012: …`).
- Für jeden echten Fehler erst einen Regressionstest, dann beheben.

## 6. CarPlay

- Eigene Szene (`CPTemplateApplicationSceneDelegate`) im `UIApplicationSceneManifest`. iPhone-Szene läuft getrennt; geteilter Zustand in ein gemeinsames Modell (im Prototyp: `app.state`).
- `carWindow` hat je Auto andere Größen (800 × 480 bis Breitbild) und kann sich ändern → Layout immer aus der aktuellen Größe berechnen (im Prototyp umschaltbar).
- Ohne Entitlement startet die CarPlay-Szene im Auto nicht; im Simulator geht es. Vorher aktuelle Apple-Doku prüfen.
- Performance: Autoradios sind langsam. Karte nicht doppelt rendern, Zeichenaufwand messen.
