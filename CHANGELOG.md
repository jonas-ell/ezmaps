# Changelog

Neue Einträge oben. Nummernreihe: `GM-xxx`.

## GM-045 – Replay-Kamera wie Freifahren in CarPlay

**Ziel:** Nutzer: Im Replay soll die Kamera so stehen wie beim Freifahren, mit dem Pfeil groß in der Mitte.

**Dateien:** `Core/Sources/EzMapsCore/ReplayPlanner.swift`, `tools/prototype/js/{replay,aufdecken}.js`, `App/ReplayExporter.swift`, `docs/previews/replay-gm044-carplay.mp4` (neu erzeugt)

**Geändert:**
- Kamera **flach von oben (0°)**, **Fahrtrichtung oben**, **Pfeil groß in der Mitte**. Das ist dieselbe Einstellung wie `FollowCamera` in CarPlay (pitch 0, Pfeil mittig).
- `ReplayPlanner.followPitch = 0`; Mirror `replay.js` `followTilt = 0`.
- Nah wie im Auto (Prototyp 1,8 px/m).
- App: Pfeil-Bild `PlayerNeonGlow` (wie CarPlay), 72 pt.
- Nur der Überblick am Ende rückt nach rechts neben die Ergebnis-Tafel.

**Tatsächlich geprüft:** `swift test` Core 53 grün. Prototyp-Video ohne Fehler erzeugt, Standbilder angesehen. `swiftc -parse` ReplayExporter.

**Ungetestet:** App-Export auf dem Mac (nicht gebaut, GM-043).

## GM-044 – Fahrt-Replay im CarPlay-Format (Querformat 16:9)

**Ziel:** Nutzer: „das video soll im carplay format sein“. Bisher Hochformat 9:16, jetzt Querformat wie der CarPlay-Bildschirm.

**Dateien:** `Core/Sources/EzMapsCore/ReplayPlanner.swift` + Test, `tools/prototype/js/{replay,aufdecken}.js`, `tools/prototype/aufdecken.css`, `App/ReplayExporter.swift`, `docs/previews/replay-gm044-carplay.mp4` (neu, ersetzt `replay-gm041.mp4` als Vorlage)

**Geändert:**
- `ReplayPlanner`: Standard 1920 × 1080 (Mirror `replay.js`). Test angepasst.
- Aufbau wie CarPlay:
  - Titel-Tafel lila links oben („Fahrt zum Hexenturm · 1,9 km · 6 Min“, wie die Abbiegekarte).
  - Ergebnis-Tafel links unten („+56 % neue Straßen“, Stufe).
  - „EzMaps“ rechts oben, OSM-Hinweis rechts unten.
  - Auto bei 62 % der Breite (rechts der Tafeln); Überblick am Ende nur in der Kartenfläche rechts.
- App-Export (`ReplayExporter`): 960 × 540 pt × 2 = 1920 × 1080. Kamera-Mittelpunkt quer zur Blickrichtung versetzt (Snapshotter kennt keinen Anker). Player im Blatt 16:9.

**Tatsächlich geprüft:**
- `swift test` Core: 53 grün.
- Prototyp-Video 300 Bilder ohne Fehler, MP4 erzeugt, Standbilder angesehen.
- `swiftc -parse` für `ReplayExporter.swift`.

**Ungetestet:** App-Export auf dem Mac (nicht gebaut, siehe GM-043).

## GM-043 – Alles in Code: GM-029 bis GM-042 in Swift umgesetzt (ungebaut) – Auftrag für den lokalen Claude: bauen und Fehler beheben

**Ziel:** Nutzer: „code alles zuende“. Die Aufträge GM-029 bis GM-042 waren nur Prototyp und Text, die App stand bei GM-028 (nur Neon, kein Shop). Jetzt ist alles als Swift-Code da. Die Cloud hat keinen Zugang zum Mac-Gate (`~/.ssh` leer): **Die App ist nicht gebaut.** Erste Aufgabe ist Bauen und Compilerfehler beheben.

**Dateien:**
- **Core (getestet):** `MapStyle.swift` (Klassik gratis, 5 Stile), `Purchases.swift` (Produkt-IDs, `StyleAccess`, `PlanMath`), `Autobahn.swift` (Autobahn GmbH, Filter „vor mir auf der Route“), `Journal.swift` (Fahrten, Favoriten, Zuhause/Arbeit, Parkplatz, Abzeichen, Wochenmission), Tests `StoreAndJournalTests.swift`
- **Kartenstile:** `tools/maplibre/build_style.py` erzeugt jetzt `App/MapStyles/style-{classic,neon-city,wild-west,pixel-quest,toy-town}.json`. Neon ist unverändert, byte-gleich geprüft.
- **App (neu):**
  - `Glass.swift` (Glas-Bausteine GM-032/036)
  - `StyleTheme.swift` (Farben je Stil, `StyleName` in Projekt-Schrift)
  - `PurchaseManager.swift` (StoreKit 2)
  - `EzMaps.storekit` (Testdatei, Preise GM-038/039, kein Einführungsangebot GM-042)
  - `OnboardingView.swift`, `ShopScreens.swift`, `ExploreScreens.swift`, `ReplayExporter.swift`, `Shortcuts.swift`
  - `Fonts/` (Rye, Press Start 2P, Fredoka Bold, Anton, alle OFL, mit `OFL.txt`)
  - `Assets.xcassets/AppIconPreview`
- **App (geändert):** `AppModel.swift`, `ContentView.swift` (komplett im Glas-Look), `NeonMapView.swift` (Stilwechsel, Leuchtspur), `CarPlaySceneDelegate.swift`, `SettingsScreen.swift`, `SpeechService.swift`, `GameStorage.swift`, `PrivacyInfo.xcprivacy` (SystemBootTime 35F9.1), `en.lproj/Localizable.strings` (+174)
- **Projekt:** `project.yml` (UIAppFonts, StoreKit-Testdatei im Schema), `tools/mac_build.sh` (kopiert Pricedown aus `~/EzMapsPrivate/Fonts/` falls vorhanden), `.gitignore` (`App/Fonts/Pricedown.otf`)

**Was jetzt in der App ist:**
- **5 Kartenstile** (alle in der 1.0, GM-041). Klassik gratis, die anderen über Plus oder Einzelkauf. Stil wechselt auf iPhone und CarPlay gleich, Routenfarben je Stil.
- **Shop „EzMaps Plus“**:
  - Für immer 79,99 € (Anker), Jährlich 29,99 € (als €/Monat, vorausgewählt, „Beliebt · spare X %“), Monatlich 4,99 €.
  - Einzelstil Neon 39,99 €, andere 29,99 €.
  - Apple-Pflichtangaben, Wiederherstellen, Abo verwalten. Kein Gratis-Zeitraum.
- **Stil-Test 10 Minuten** je Stil:
  - zählt auf iPhone und CarPlay, nie mitten in der Fahrt beendet;
  - Schlüsselbund + iCloud, mit Systemlaufzeit gemessen;
  - Uhr im Startblatt, in der Navigation und in CarPlay;
  - danach Blatt „Test vorbei“, nie in CarPlay.
- **Onboarding** (3 Schritte + Willkommen): Standortfrage erst nach Erklärung, Stilwahl mit Klassik vorausgewählt, Zuhause/Arbeit per Suche, Sprachansagen.
- **Glas-Oberfläche**:
  - Startblatt mit Wochenmission und Schnellzielen (Zuhause, Arbeit, Favoriten, Dein Auto).
  - Runde Knöpfe: Standort, Stile, Entdecken, Einstellungen.
  - Suche mit Meine Orte, Favoriten, Zuletzt.
  - Vorschau mit Stern, „Als Zuhause/Arbeit speichern“, „+X % neue Straßen“ je Route.
  - Navigation mit lila Abbiegekarte, Baustellen-Banner und rundem Ende-Knopf.
  - Uhrzeit-Verlauf oben (Scrim).
- **Stadt aufdecken**:
  - Fahrt wird aufgezeichnet, Leuchtspur hinter dem Auto (iPhone und CarPlay).
  - Ankunft mit „+X % neue Straßen“, gefahren, entdeckt, neue Abzeichen, Mission geschafft.
  - Tab **Entdecken**: Karte mit Nebel und Leuchtpunkten; „Dieses Gebiet“ = Anteil der Straßen im Kartenausschnitt (aus MapLibre); Stufe, Abzeichen, Mission, Meine Fahrten.
- **Fahrt-Replay als MP4** (1080 × 1920, 10 s): MapLibre-Bilder mit Kamera aus `ReplayPlanner`, Titel, Ergebnis, Wasserzeichen, OSM-Hinweis. Teilen per ShareLink.
- **Meine Fahrten** (lokal, löschbar, abschaltbar).
- **Wo hab ich geparkt?**: Standort beim Trennen von CarPlay, Blatt mit „Zu Fuß hin“ (Apple Karten), Teilen, Vergessen.
- **Baustellen/Sperrungen**: Autobahn GmbH für die Autobahnen der Route; Banner ab 5 km; Ansage einmal ab 2 km. Keine Blitzer.
- **Stimme** wählbar (alle deutschen iOS-Stimmen), **Sprechtempo**.
- **Siri/Kurzbefehle**: „Mit EzMaps nach Hause“, „… zur Arbeit“, „Wo hab ich geparkt?“.

**Tatsächlich geprüft:**
- `swift test` in Core (Linux): **53 Tests grün**.
- Alle 21 App-Dateien mit `swiftc -parse`: nur Syntax, **kein Typ-Check, kein Build**.
- Die 5 Stil-JSONs in MapLibre GL JS (Browser) gerendert: `docs/previews/maplibre-5-stile-gm043.png`.
- StoreKit-Datei und PrivacyInfo als JSON/Plist gültig.

**Ungetestet:**
- Die ganze App, weil nicht gebaut. Mit Compilerfehlern ist zu rechnen (MapLibre-API-Namen, Observation, Concurrency).
- StoreKit-Käufe.
- Schlüsselbund/iCloud.
- Replay-Export (Laufzeit pro Bild unbekannt).
- „Dieses Gebiet“ (`visibleFeatures`).
- Siri-Phrasen.

**Bewusst noch nicht gemacht:**
- **Widgets**: braucht ein Widget-Extension-Ziel in `project.yml`.
- **Ortsteile mit Namen und Grenzen**: statt dessen „Dieses Gebiet“ = Kartenausschnitt.
- **Fahrspur-Pfeile, Live-Aktivität/Dynamic Island, Spritpreise.**
- **iOS 26 `.glassEffect()`**: SDK-abhängig, bei Xcode 26 mit `if #available` ergänzen.

### Auftrag (Swift) – lokaler Claude
1. `ssh mac-ezmaps clean && git archive HEAD | ssh mac-ezmaps extract && ssh mac-ezmaps build` und **alle Compilerfehler beheben**, ohne Funktionen zu streichen. Typische Stellen:
   - `ExploreScreens.swift` (`NSExpression mgl_interpolate`, `visibleFeatures`, `getCoordinates`)
   - `ReplayExporter.swift` (`MLNMapSnapshotOptions`, `MLNAltitudeForZoomLevel`)
   - `AppModel` (@Observable-Init-Reihenfolge)
   - `Shortcuts.swift` (AppIntents Swift-6-Warnungen)
2. Im Simulator mit StoreKit-Testdatei durchgehen:
   - Onboarding
   - Stil testen bis zum Ende, auch in CarPlay
   - Plus kaufen, kündigen, wiederherstellen
   - Einzelkauf
   - Demo-Fahrt: Ankunft „+100 %“, Replay erzeugen und teilen
   - Entdecken
   - Baustelle auf der A3 (Ziel Frankfurt)
   - Parkplatz nach CarPlay-Trennen
3. **App Store Connect:** Abo-Gruppe „EzMaps Plus“ (`ezmaps.plus.yearly` 29,99 €, `ezmaps.plus.monthly` 4,99 €, **ohne** Einführungsangebot), Nicht-Verbrauchsartikel `ezmaps.plus.lifetime` 79,99 €, `ezmaps.style.neon` 39,99 €, `ezmaps.style.western/.pixel/.toy` je 29,99 €; Familienfreigabe für Einmalkäufe an.
4. **iCloud Key-Value Storage** als Capability anlegen (`com.apple.developer.ubiquity-kvstore-identifier`). Ohne das zählt nur der Schlüsselbund.
5. Store-Screenshots neu (`tools/mac_screens.sh`). Das Onboarding wird im Screenshot-Modus übersprungen.
6. Danach: Widget-Extension (Zuhause/Arbeit mit Fahrzeit, Dein Auto).

## GM-042 – Replay-Video als echte Datei, kein 7-Tage-Test mehr – Auftrag für den lokalen Claude

**Ziel:** Nutzer: zeigen, wie das Replay-Video aussieht; „7 Tage testen“ raus.

**Dateien:** `tools/prototype/js/{aufdecken,glas}.js`, `tools/prototype/aufdecken.css`, `docs/previews/replay-gm041.mp4` (neu)

**Geändert:**
- **Kein Gratis-Zeitraum mehr im Abo.** Shop: Knopf „Jährlich starten“ statt „7 Tage gratis testen“, Zeile „29,99 € im Jahr“. Einzelkauf und „Test vorbei“: „Plus holen“. Testen geht nur noch über den 10-Minuten-Stil-Test (GM-041). **Ersetzt** in GM-038 Punkt 1 „Einführungsangebot 1 Woche gratis“ und „isEligibleForIntroOffer“, in GM-039 „Plus 7 Tage gratis testen“.
- **Replay-Video**: `aufdecken.html?video` zeichnet das Video Bild für Bild (405 × 720 pt, 300 Bilder, 10 s), Export mit ffmpeg als MP4 (Vorlage `docs/previews/replay-gm041.mp4`). Ablauf:
  1. 0 bis 1,5 s: Titel „Fahrt zum Hexenturm · 1,9 km · 6 Min“
  2. Kamera fliegt schräg mit, gefahrene Strecke als kräftige lila Leuchtlinie, neue Straßen heller
  3. Ab 72 %: Herauszoomen auf die ganze Strecke, Ziel-Punkt
  4. Ab 8 s: „+56 % neue Straßen“ groß mit Leuchten und Glas-Karte „Idstein-Kenner · Stufe 3“ mit Balken
  - Immer zu sehen: „EzMaps“ oben links und „© OpenMapTiles · © OpenStreetMap-Mitwirkende“ unten rechts
  - Nebel im Video leichter (schmaler Ausschnitt), damit die Schrägansicht ruhig bleibt

**Tatsächlich geprüft:** Playwright: 300 Bilder ohne Fehler, MP4 erzeugt und Standbilder angesehen.

**Ungetestet:** Nichts in Swift.

### Auftrag (Swift)
1. StoreKit: **kein** Einführungsangebot anlegen; Paywall-Knopf je Plan „Jährlich starten“ / „Monatlich starten“ / „Für immer freischalten“
2. Replay-Video genau wie `docs/previews/replay-gm041.mp4` (Ablauf oben, Werte in `aufdecken.js` → `videoPlayer`)

## GM-041 – Stadt aufdecken (Konzept + Logik), Stil-Test nicht umgehbar, Fahrt-Replay – Auftrag für den lokalen Claude

**Ziel:** Nutzer zu GM-040:
- Alle 5 jetzigen Stile kommen in die 1.0, neue Stile danach.
- Design-Konzept für „Stadt aufdecken“ machen.
- Keine Probezeit, aber kurzes Testen, auch in CarPlay, nicht durch Neuinstallieren umgehbar.
- Fahrt-Replay: ja.
- Alles in Code umsetzen.

**Dateien:**
- `Core/Sources/EzMapsCore/{Exploration,StyleTrial,ReplayPlanner}.swift` + Tests
- `tools/prototype/js/{explore,replay,aufdecken}.js`, `tools/prototype/aufdecken.{html,css}`
- `App/GameStorage.swift` (neu), `App/AppModel.swift`, `App/ContentView.swift`, `App/en.lproj/Localizable.strings`
- `docs/KONZEPT_IDEEN.md`

**Geändert:**
- **Logik Aufdecken** (`Exploration.swift`, gespiegelt in `explore.js`):
  - Gefahrene Strecke wird zu Straßenzellen (Kacheln Zoom 20, ~24 m). Das geht in ganz Deutschland, ohne eigene Straßendaten und ohne Server.
  - GPS-Lücken über 400 m (Tunnel) decken nichts dazwischen auf.
  - `TripReveal` (+X % neue Straßen), Anteil je Ortsteil, Stufen 0/10/25/50/75 % (Neu hier, Unterwegs, Kenner, Insider, Legende), 10 Abzeichen mit eigenen Namen.
- **Stil-Test** (`StyleTrial.swift`):
  - 10 Min je Kauf-Stil, einmal.
  - Zählt, solange der Stil auf iPhone **oder** CarPlay sichtbar ist (gleichzeitig nur einmal).
  - Läuft nie in einer Fahrt ab, erst nach der Ankunft.
  - `merge` nimmt den größeren Verbrauch aus Schlüsselbund und iCloud. Löschen und Neuinstallieren bringt keinen neuen Test.
- **Fahrt-Replay** (`ReplayPlanner.swift`, gespiegelt in `replay.js`):
  - 10 s, 30 Bilder/s, 9:16.
  - Kamera folgt der Strecke (weich gedreht), am Ende Überblick über die ganze Strecke.
- **App:**
  - `GameStorage`: Aufdecken als Datei; Testzeit in Schlüsselbund und `NSUbiquitousKeyValueStore`.
  - `AppModel` zeichnet die Fahrt auf (Genauigkeit ≤ 30 m, alle 10 m; Demo-Fahrt nur in Debug-Builds) und deckt bei Ankunft oder Abbruch auf.
  - Ankunft zeigt „+X % neue Straßen“ (DE und EN).
- **Prototyp `aufdecken.html`**, 9 Screens im Glas-Look:
  - Meine Stadt (Nebel)
  - Ortsteil
  - Fahrt iPhone (nur dünnes Leuchten, „+3 neu“)
  - Ankunft mit Aufleuchten
  - Abzeichen (goldener Rand)
  - Wochenmission
  - Fahrt-Replay (läuft als Animation)
  - Stil-Test vorbei
  - CarPlay mit Test-Uhr

**Tatsächlich geprüft:**
- `swift test` in Core (Linux): 46 Tests grün, davon 19 neu.
- `swiftc -parse` für die 3 geänderten App-Dateien.
- Playwright: `aufdecken.html` ohne Fehler, alle Screens angesehen.
- `explore.js` gegen Swift-Werte gegengerechnet.

**Ungetestet:**
- App nicht auf dem Mac gebaut: Schlüsselbund, iCloud, Ankunftszeile.
- Ob Schlüsselbund-Einträge nach dem Löschen der App bleiben, ist von Apple nicht garantiert (heute: ja).

### Auftrag (Swift)
1. **Bauen und prüfen**: `GameStorage.swift` und die Änderungen in `AppModel`/`ContentView` auf dem Mac bauen. Demo-Fahrt im Simulator (Debug): Bei Ankunft muss „+100 % neue Straßen“ stehen, bei derselben Fahrt nochmal „+0 %“.
2. **Tab/Ansicht „Entdecken“** wie Prototyp „Meine Stadt“ und „Ortsteil“:
   - Nebel als MapLibre-Ebene: dunkle Fläche, gefahrene Zellen als Linien-Layer ausgeschnitten (GeoJSON-Quelle aus `ExploreCell.center` der Zellen, zusammenhängende Zellen als Linien).
   - Ortsteile: Grenzen aus OSM `place=suburb/quarter/village` (Photon `reverse` oder Kachel-Ebene `place`), Straßenzellen je Ortsteil per `querySourceFeatures` der Straßen-Ebene → `ExploreCell.cells(along:)` → `ExplorationStore.share(of:)`.
3. **Ankunft** wie Prototyp „Ankunft · Aufleuchten“: neue Zellen 0,8 s nacheinander aufleuchten, Kacheln „+X % neue Straßen / Abschnitte / Ort“, Stufenbalken, Knöpfe „Replay“ und „Fertig“. Nur im Stand. „Bewegung reduzieren“ beachten.
4. **Während der Fahrt** (iPhone und CarPlay): nur dünnes Leuchten der frisch gefahrenen neuen Strecke, kleine Zahl „+3 neu“ in der unteren Leiste (iPhone). Keine Meldungen, keine Abzeichen während der Fahrt.
5. **Abzeichen und Stufe**: `Badge.earned(...)` nach der Ankunft; neue Abzeichen als eigener Moment nach dem Ankunft-Blatt, Teilen-Knopf.
6. **Stil-Test**: `StyleTrial` im `AppModel` halten (`GameStorage.loadTrial()` beim Start). Jede Sekunde `tick(seconds:visible:navigating:)`; `visible` = Stil auf iPhone im Vordergrund **oder** in CarPlay. Zeit über `ProcessInfo.processInfo.systemUptime` messen, nicht über die Uhrzeit. Speichern alle 10 s und beim Wechsel in den Hintergrund. In CarPlay kleine Uhr „Test 4:12“ (Kartenleiste/Hinweis). Bei `.expired`: zurück zu Klassik, dann Blatt „Test vorbei“ (Prototyp), nie in CarPlay. iCloud-Schlüsselwerte: Capability „iCloud → Key-value storage“ in `project.yml`/Entitlements ergänzen.
7. **Fahrt-Replay**: `ReplayPlanner().frames(for: track)` → je Bild MapLibre-Kamera setzen (`MLNMapSnapshotter` oder Offscreen-`MLNMapView`), Strecke bis `progress` als Linie, neue Zellen hell. Mit `AVAssetWriter` (H.264, 1080 × 1920, 30 fps) speichern, Wasserzeichen „EzMaps“ und „© OpenStreetMap-Mitwirkende“ ins Bild. Teilen über `ShareLink`. Ab 2 Minuten Fahrt anbieten.
8. **Datenschutz**: Aufdecken und Fahrten bleiben auf dem Gerät. Testzeit liegt in iCloud (Apple). `docs/legal` und Datenschutzangaben im Store prüfen. Einstellungen: „Entdeckte Karte zurücksetzen“ (`ExplorationStore.reset()`), setzt die Testzeit **nicht** zurück.

## GM-040 – Gesamtblick: Konzept- und Verbesserungsideen

**Ziel:** Nutzer: ganze App ansehen und Ideen sammeln, wie alles besser wird, auch vom Konzept her.

**Dateien:** `docs/KONZEPT_IDEEN.md` (neu)

**Geändert:** Nur Doku. Ist-Stand (Swift bei GM-028, nur Neon, kein StoreKit; GM-029 bis GM-039 offen), Konzept-Vorschläge (1.0 klein: Klassik + Neon + Plus, weitere Stile als Updates; Aufdecken als echter Unterschied; Reverse Trial 3 Tage Neon; Paywall-Zeitpunkte; Fahrt-Replay-Video; eigene Server vor Werbung; fehlender Live-Verkehr; anonyme Zählung), Produkt-Ideen, Arbeitsreihenfolge, Top 5.

**Tatsächlich geprüft:** Swift-Dateien, Prototyp, TODO und Doku gelesen. Nichts gebaut.

**Ungetestet:** –

### Auftrag
Noch keiner – erst entscheidet der Nutzer, welche Ideen umgesetzt werden. Die Arbeitsreihenfolge in Abschnitt 3 gilt nur, wenn der Nutzer sie freigibt.

## GM-039 – Einzelkäufe von Stilen wieder da (teuer, neben Plus) – Auftrag für den lokalen Claude

**Ziel:** Nutzer will auch Einzelkäufe einzelner Karten. Ergänzt GM-038 (Punkt 1 „Einzelstil-Produkte nicht anlegen“ ist damit aufgehoben).

**Dateien:** `tools/prototype/js/glas.js`

**Geändert (Prototyp):**
- Neuer Screen „Einzelkauf“ (Stil-Seite): großes Kartenbild des Stils, Merkmale als Chips, darunter zuerst Plus (lila, „Besser · alle 4 Stile“, 2,50 €/Monat, „Plus 7 Tage gratis testen“), dann Nebenknopf „Nur Neon City · 39,99 € einmalig“
- Shop: Link „Nur einen Stil kaufen ›“; Tipp auf eine Stil-Kachel öffnet die Stil-Seite
- Preise einmalig: **Neon City 39,99 €**, **Wild West / Pixel Quest / Toy Town je 29,99 €**. Absichtlich teuer: ein Stil kostet so viel wie mehr als ein Jahr Plus, alle vier einzeln 129,96 € gegen 79,99 € „Für immer“

**Tatsächlich geprüft:** Playwright (Chromium) ohne Fehler, Shop und Stil-Seite angesehen.

**Ungetestet:** Nichts in Swift.

### Auftrag (Swift)
1. Nicht-Verbrauchsartikel `ezmaps.style.neon` 39,99 €, `ezmaps.style.western`/`.pixel`/`.toy` je 29,99 € (StoreKit-Testdatei + App Store Connect). Freischaltung je Stil: Plus (Abo oder Lifetime) **oder** der passende Einzelkauf
2. `StyleDetailView` wie Prototyp; Plus immer oben und vorausgewählt, Einzelkauf als `GlassButton` (GM-036) darunter; Preise aus `Product.displayPrice`
3. Wer einen Einzelstil hat und Plus kündigt, behält diesen Stil. Im Shop gekaufte Stile mit Haken statt Preis
4. Familienfreigabe für Einzelkäufe und Lifetime an, Text „Wiederherstellen“ deckt alles ab

## GM-038 – EzMaps Plus (Abo mit teurem Einmalkauf als Anker) + UI-Fehler behoben – Auftrag für den lokalen Claude

**Ziel:** Nutzer: Einmalpreise sehr teuer machen, damit das Monatsabo günstig wirkt (Preispsychologie). Alle UIs prüfen, manches sah schief aus. **Ersetzt die Preise aus GM-035 und GM-037** (keine Einzelstile mehr).

**Dateien:** `tools/prototype/js/{glas,onboarding,designs,glasfix}.js`, `tools/prototype/{glas,onboarding,designs}.css`

**Preismodell „EzMaps Plus“ (alle Stile, iPhone + CarPlay, jeder neue Stil inklusive):**
| Angebot | Preis | Rolle |
|---|---|---|
| Für immer | **79,99 €** einmalig | Anker: steht oben, macht das Abo billig |
| Jährlich | **29,99 €/Jahr**, angezeigt als **2,50 €/Monat**, 7 Tage gratis | vorausgewählt, Schild „Beliebt · spare 50 %“ |
| Monatlich | **4,99 €/Monat** | Einstieg, Vergleichswert für „spare 50 %“ |
- Konkurrenz (GM-037): Abos 5,99 bis 14,99 €/Monat bzw. 34,99 bis 69,99 €/Jahr → wir sind bei Monat und Jahr günstiger. Den Einmalkauf machen wir absichtlich teuer.
- Psychologie: Anker zuerst, Mitte vorausgewählt, Preis pro Monat statt pro Jahr, Gratis-Woche im Knopf („7 Tage gratis testen“), Rabatt in Prozent, nur 3 Wahlmöglichkeiten.
- Klassik und die ganze Navigation bleiben gratis (Ansagen, CarPlay mit Klassik).

**UI-Korrekturen (Prototyp):**
1. Kartenhinweis „© OpenStreetMap-Mitwirkende“ lag auf oder in Blättern und Leisten (feste Abstände) → wird jetzt gemessen und sitzt immer 6 pt über dem unteren Blatt (`glasfix.js`)
2. Uhrzeit oben war auf hellen Kartenstellen kaum lesbar → weicher dunkler Verlauf hinter der Statusleiste
3. Willkommen: leerer Kasten mit Lila-Leuchten hinter „EzMaps“ (alte `.logo`-Regel) entfernt, App-Icon mit feinem Rand und Schatten
4. Parkplatz: Fußgänger-Symbol stand über dem Text im Knopf → nebeneinander
5. Shop: Schild „Beliebtester Stil“ brach um → eine Zeile; Stilnamen in den Kacheln wieder in den Stil-Schriften
6. Kein Netz: Hinweis zu lang (lief bis an den Rand) → „Offline · Route bleibt gespeichert“
7. Stil wählen: Toy Town fehlte → alle 5 Stile, Klassik breit oben, Schild „PLUS“ statt „PREMIUM“
8. „Wohin fährst du oft?“: Karte schien unruhig durch den Text → dunkler
9. Suche: grauer Kasten „Tastatur“ → echte deutsche Tastatur-Attrappe mit „Los“-Taste
10. „Neon City gehört dir“ → „Plus ist aktiv“; „Kaufen“ im Testbanner → „Plus holen“

**Tatsächlich geprüft:** Playwright (Chromium) ohne Fehler, alle 20 Glas-Screens einzeln angesehen.

**Ungetestet:** Nichts in Swift, keine Abos in App Store Connect.

### Auftrag (Swift)
1. **StoreKit 2, Abo-Gruppe „EzMaps Plus“:** `ezmaps.plus.yearly` 29,99 € mit Einführungsangebot 1 Woche gratis, `ezmaps.plus.monthly` 4,99 €; dazu Nicht-Verbrauchsartikel `ezmaps.plus.lifetime` 79,99 €. Alte Einzelstil-Produkte aus GM-035 nicht anlegen. Freischaltung: `Transaction.currentEntitlements` enthält eins der drei → alle Stile frei. StoreKit-Testdatei anpassen.
2. **Paywall** genau wie Prototyp (`glas.html`, Screen „Shop (EzMaps Plus)“): 2×2-Stil-Kacheln, drei Plan-Zeilen (Für immer, Jährlich vorausgewählt, Monatlich), Knopf ändert Text je Plan („7 Tage gratis testen“, „Monatlich starten“, „Für immer freischalten“). Alle Preise aus `Product.displayPrice`; „2,50 € pro Monat“ aus `price / 12` mit `priceFormatStyle`; „spare 50 %“ aus Monat×12 gegen Jahr berechnen. Gratis-Woche nur zeigen, wenn `isEligibleForIntroOffer`.
3. **Apple-Pflichten (Richtlinie 3.1.2):** Abo-Titel, Laufzeit, Preis und Verlängerungshinweis direkt über dem Knopf; Links zu Nutzungsbedingungen (EULA) und Datenschutz; „Käufe wiederherstellen“; Kündigen-Hinweis. Kein Countdown-Druck, kein versteckter Schließen-Knopf.
4. **Dauerhafter Nutzen fürs Abo (sonst lehnt Apple es eventuell ab):** neue Stile regelmäßig (z. B. alle 2 bis 3 Monate), im App-Store-Text so nennen. Baustellen-Anzeige je Stil und Fotomodus dürfen Plus-Vorteile sein, Navigation und Sicherheit nicht.
5. **Testmodus / Stil testen (GM-033)** bleibt, Banner-Knopf „Plus holen“ öffnet die Paywall.
6. **UI-Korrekturen 1 bis 10** übernehmen: Attribution per Layout direkt über dem unteren Blatt (`safeAreaInset`/`overlay(alignment: .bottomTrailing)` am Blatt, keine festen Werte); Statusleisten-Verlauf (`LinearGradient` schwarz 55 % → klar, 58 pt, `.ignoresSafeArea`); Knopf-Inhalt immer `HStack`; Labels `lineLimit(1)` + `minimumScaleFactor(0.85)`; Onboarding mit 5 Stilen.
7. `docs/APPSTORE_TEXTE.md`: „Kein Abo“ aus GM-037 streichen, stattdessen „Navigation gratis, Plus für alle Stile“.

## GM-037 – Preise höher, aber unter der Konkurrenz (Spiel-Karten-Apps) – Auftrag für den lokalen Claude

**Ziel:** Nutzer: Preise viel teurer machen, aber günstiger als die Konkurrenz bleiben. Außerdem prüfen, ob die Konkurrenz-Apps Rechte an den Spielen haben.

**Dateien:** `tools/prototype/js/glas.js`

**Marktvergleich (App Store DE, Oktober 2026):**
- MapSkins GPS: Premium 7,99 € / 44,99 €, Jahr 39,99 bis 44,99 €; CarPlay ja
- Game Maps IRL: Mappr: Lifetime 22,99 € / 34,99 €, Monat 5,99 bis 9,99 €, Jahr bis 69,99 €; CarPlay ja
- Game Maps: Car Maps: Jahr 9,99 €, aber CarPlay extra 59,99 € im Jahr
- Pixel Maps – Game Maps IRL: Monat 6,99 €, Lifetime 22,99 €
- Game Maps – Play the IRL Map: Woche 7,99 €, Monat 14,99 €, Jahr 44,99 €
- Günstigster Einmalkauf für alles: 22,99 €

**Geändert (Prototyp, Shop):** Neon City **12,99 €** (vorher 7,99 €), Wild West / Pixel Quest / Toy Town je **9,99 €** (vorher 5,99 €), Alle Stile **21,99 €** „statt 42,96 €“ (vorher 19,99 €). Damit ist „Alle Stile“ der günstigste Einmalkauf am Markt, die Einzelstile lohnen sich kaum, das Paket wird zum Hauptkauf.

**Rechte der Konkurrenz (Recherche, keine Rechtsberatung):** Keine der Apps nennt eine Lizenz von Spiele-Herstellern. „Game Maps: Car Maps“ schreibt selbst „nicht verbunden mit Spiele-Herstellern“, Mappr nennt seine Stile „eigene künstlerische Designs“. Trotzdem nutzen einige Spielnamen in Texten und Versionshinweisen. Der Hersteller der bekanntesten Gangster-Spielreihe lässt Fan-Projekte mit seinen Karten regelmäßig per DMCA entfernen. Ob er gegen diese Apps vorgeht, ist nicht bekannt. Folge für uns: so bleiben wie bisher – keine Spielnamen, keine Spiel-Grafiken, eigene Stilnamen, Pricedown nur mit App-Lizenz (GM-035). Das ist ein Vorteil gegenüber Apps, die jederzeit aus dem Store fliegen können.

**Tatsächlich geprüft:** Playwright (Chromium) ohne Fehler, Shop angesehen.

**Ungetestet:** Nichts in Swift. Preise nicht in App Store Connect angelegt.

### Auftrag (Swift)
1. App Store Connect und StoreKit-Testdatei: `ezmaps.style.neon` 12,99 €, `ezmaps.style.western`/`.pixel`/`.toy` je 9,99 €, `ezmaps.styles.all` 21,99 € (ersetzt die Preise aus GM-035 Punkt 1). Anzeige weiter aus `Product.displayPrice`, „statt …“ aus der Summe berechnet
2. Im Shop „Alle Stile“ stärker zeigen: Text „Kein Abo · einmal zahlen“ und „CarPlay inklusive“ sichtbar lassen
3. `docs/APPSTORE_TEXTE.md`: Werbetext ohne Spielnamen, mit „Kein Abo“, „CarPlay inklusive“, „Navigation und Ansagen gratis“

## GM-036 – Knöpfe auch im Glas-Look – Auftrag für den lokalen Claude

**Ziel:** Nutzer: Glas-Look fehlte bei den Knöpfen (waren volle Farbflächen).

**Dateien:** `tools/prototype/designs.css`, `tools/prototype/onboarding.css`

**Geändert (Prototyp):**
- Hauptknopf („Los“, „Neon City · 7,99 €“, „Standort erlauben“ …): **lila Glas** statt Vollfarbe – Verlauf `rgba(190,95,255,.78)` → `rgba(122,43,216,.72)`, Hintergrund-Unschärfe 20 px + Sättigung 1,6, Rand 0,5 pt weiß 38 %, Lichtkante oben (innen 1 px weiß 50 %), dunkle Kante unten (innen 1 px schwarz 25 %), leichtes inneres Leuchten, Schatten lila 35 % (Radius 24, y 8)
- Nebenknöpfe, Preis-Schilder, „Alle Stile“-Zeile, Routen-Zeilen, Chips, runde Knöpfe: **helles Glas** – Verlauf weiß 16 % → 6 % von oben nach unten, Unschärfe 20 px, Rand 0,5 pt weiß 28 %, Lichtkante oben (innen 1 px weiß 35 %), Schatten schwarz 25 %
- Gewählte Route: lila Glas 32 % → 16 % + 1,5 pt Akzent-Rand; gekauft-Schild grünes Glas

**Tatsächlich geprüft:** Playwright (Chromium) ohne Fehler: Shop, Onboarding, Startkarte/Vorschau/Navigation (Glas) angesehen.

**Ungetestet:** Nichts in Swift.

### Auftrag (Swift, ersetzt die Knopf-Angaben in GM-032 Block 1)
- `PrimaryButton`: `.ultraThinMaterial` + darüber `LinearGradient` (Werte oben, 135°), `RoundedRectangle(18, .continuous)`, `.strokeBorder` weiß 38 % 0,5 pt, Lichtkante als oberer innerer Rand (Overlay mit Verlauf weiß 50 % → klar über die ersten 2 pt), Schatten lila 35 %
- `GlassButton` (neu, für Nebenknöpfe, Preise, „Alle Stile“, Chips, runde Knöpfe): `.ultraThinMaterial` + Verlauf weiß 16 % → 6 %, Rand weiß 28 %, Lichtkante weiß 35 %
- Ende-Knopf (rot) und Kauf-Schild im Stil-Test-Banner gleiches Glas-Prinzip mit Rot bzw. Lila
- Gedrückt: Deckkraft −15 %, Skalierung 0,97 (`ButtonStyle`); „Transparenz reduzieren“ → feste Farben ohne Unschärfe
- Auf iOS 26: wenn verfügbar `.glassEffect()` (Liquid Glass) nutzen, sonst die Nachbildung oben (`if #available`)

## GM-035 – Neue Preise, Pricedown für Neon City, Pixel-Schrift für Pixel Quest – Auftrag für den lokalen Claude

**Ziel:** Nutzer: Preise viel zu günstig. Name „Neon City“ in der Pricedown-Schrift aus dem Projekt, „Pixel Quest“ in einer Minecraft-artigen Pixel-Schrift.

**Dateien:** `tools/prototype/{glas,onboarding}.{html,css}`, `tools/prototype/js/{glas,onboarding}.js`

**Geändert (Prototyp):**
- Shop: Neon City **7,99 €**, Wild West / Pixel Quest / Toy Town je **5,99 €**, Alle Stile **19,99 €** („statt 25,96 €“, enthält auch künftige Stile). Klassik gratis
- Stil-Namen in den Projekt-Schriften: Neon City Pricedown (`.nname`, in der Cloud Ersatz Anton), Wild West Rye, Pixel Quest Press Start 2P, Toy Town Fredoka

**Tatsächlich geprüft:** Playwright (Chromium) ohne Fehler, Shop und Onboarding-Stilwahl angesehen.

**Ungetestet:** Nichts in Swift. Preise nicht mit App Store Connect abgeglichen (Preisstufen).

### Auftrag (Swift)
1. **Preise** in App Store Connect / StoreKit-Testdatei: `ezmaps.style.neon` 7,99 €, `ezmaps.style.western`/`.pixel`/`.toy` je 5,99 €, `ezmaps.styles.all` 19,99 €. Nächstliegende Apple-Preisstufen wählen; Anzeige immer aus `Product.displayPrice`. Text „statt …“ aus der Summe der Einzelpreise berechnen, nicht fest einbauen. `docs/APPSTORE_TEXTE.md` anpassen
2. **Pricedown für den Namen „Neon City“** (Wunsch des Nutzers). Bedingungen:
   - Nur mit **App-Lizenz** von Typodermic (die vorhandene Datei hat nur Desktop-Lizenz). Nutzer kauft sie; bis dahin Anton (GM-034)
   - Schriftdatei **nie ins Repo** (Repo ist öffentlich, `tools/prototype/fonts/` bleibt in `.gitignore`). Stattdessen: `tools/mac_build.sh` kopiert, falls vorhanden, `~/EzMapsPrivate/Fonts/pricedown.otf` vor dem Build nach `App/Fonts/` (dort in `.gitignore`); `UIAppFonts` enthält beide Namen, Code nimmt Pricedown, wenn `UIFont(name:)` sie findet, sonst Anton
   - Nur der Name, sonst keine Texte in Pricedown; keine Spielnamen in Texten (Markenrecht, App-Review 4.1 – die Schrift ist stark mit einem bekannten Spiel verbunden, deshalb nur für den Stilnamen)
3. **Korrektur (Nutzer): die Projekt-Schriften benutzen, keine neuen.** Stil-Namen genau in den Schriften, die der Prototyp seit GM-003/GM-004 für die Stile nutzt (`tools/prototype/style.css`, `.sf-*`):
   - Neon City → **Pricedown** (siehe Punkt 2), schwarze Kontur
   - Wild West → **Rye**
   - Pixel Quest → **Press Start 2P** (die Pixel-Schrift des Stils; nicht Silkscreen, nicht die Minecraft-Originalschrift), harter Schatten 2 pt, Größe ×0,72
   - Toy Town → **Fredoka** Bold
   - Klassik → SF Pro
   Rye, Press Start 2P und Fredoka sind SIL OFL (Google Fonts): TTF + `OFL.txt` in `App/Fonts/` (dürfen ins Repo), `UIAppFonts`. Im Baustein `StyleName` (GM-034) einsetzen; Lizenzen in Einstellungen → Über. Prototyp angepasst (`.nname`, `.wname`, `.pname`, `.tname` in `glas.css`/`onboarding.css`)

## GM-034 – Name „Neon City“ wieder in der Stil-Schrift – Auftrag für den lokalen Claude

**Ziel:** Der Nutzer will, dass der Name „Neon City“ überall in seiner eigenen Schrift steht (wie früher im Prototyp mit Pricedown).

**Dateien:** `tools/prototype/{glas,onboarding}.{html,css}`, `tools/prototype/js/{glas,onboarding}.js`

**Geändert (Prototyp):**
- Neue Klasse `.nname`: Schrift Pricedown (nur lokal), Ersatz Impact, dann **Anton** (Google Fonts, SIL OFL), schwarze Kontur 1,5 px, etwas größer (1,18 em). Angewendet auf jeden „Neon City“: Shop (große Karte, Kauf-Knopf), Stil-Test-Banner, „Neon City gehört dir“, Onboarding-Kachel, Einstellungen

**Tatsächlich geprüft:** Playwright (Chromium) ohne Fehler, Shop/Test/Freigeschaltet/Onboarding/Einstellungen angesehen. In der Cloud fehlt Pricedown, dort ist Anton zu sehen.

**Ungetestet:** Nichts in Swift.

### Auftrag (Swift)
- Überall, wo der **Name** „Neon City“ erscheint (Stilwahl im Onboarding, Shop, Stil-Test-Banner, Freigeschaltet, Einstellungen, Stile-Seite), eigene Schrift statt SF Pro, mit schwarzer Kontur (2 Schatten oder `.stroke`-Text in SwiftUI) und Größe ×1,18. Nur der Name, nicht ganze Sätze oder Knöpfe drumherum
- **Lizenz:** Pricedown hat nur eine Desktop-Lizenz und darf **nicht** in die App, solange der Nutzer keine App-Lizenz (Typodermic) gekauft hat. Bis dahin **Anton** (SIL OFL 1.1, frei auch für Apps): `App/Fonts/Anton-Regular.ttf` + `OFL.txt` ins Repo, in `project.yml` unter `UIAppFonts` eintragen, Lizenz in Einstellungen → Über nennen
- Baustein `StyleName(style:)` in `App/Design/`: Neon City → Anton/Pricedown, Wild West → Rye (OFL), Pixel Quest → „Press Start 2P“ (OFL), Toy Town → Fredoka (OFL), Klassik → SF Pro. Gleiche Regeln (nur Namen)
- Mit Dynamic Type skalieren (`.relativeTo(.title2)`), Kontur auch bei kleinen Größen lesbar

## GM-033 – Glas-Design: weitere Screens (Shop, Stil testen, Fahrten …) und Logik-Prüfung – Auftrag für den lokalen Claude

**Ziel:** Hinweis „Kein Konto, kein Tracking“ raus; weitere Screens 1:1 im Glas-Look zeigen; alle Abläufe auf Logik prüfen.

**Dateien:** `tools/prototype/glas.html`, `tools/prototype/glas.css`, `tools/prototype/js/glas.js` (neu), `tools/prototype/js/onboarding.js`, `CHANGELOG.md` (GM-032 angepasst)

**Geändert (Prototyp):**
- Neue Seite `http://localhost:8765/tools/prototype/glas.html` mit 10 Screens: Shop, Stil testen, Freigeschaltet, Meine Fahrten, Favorit merken, Wo hab ich geparkt, Baustelle voraus, Neu berechnen, Kein GPS / kein Netz, Standort aus
- Onboarding: „Kein Konto, kein Tracking“ und „Dein Standort bleibt auf dem iPhone“ entfernt, stattdessen „Ansagen laufen weiter“; Stil-Schritt wählt Klassik vor („Weiter mit Klassik“); Losfahr-Hinweis aus dem Onboarding genommen

**Logik-Prüfung (Befunde, alle im Auftrag unten berücksichtigt):**
1. „Dein Standort bleibt auf dem iPhone“ war **falsch**: Start/Ziel gehen an Valhalla/Photon → Satz gestrichen (auch rechtlich heikel)
2. Onboarding „Weiter mit Neon City“, obwohl Neon Premium ist → Klassik vorgewählt; Premium-Kachel startet „Stil testen“, nicht einen Kauf
3. Stil-Test darf **nie während einer Fahrt ablaufen** (plötzlicher Stilwechsel = Ablenkung) → Ende erst nach Ankunft/Beenden
4. Kategorie „Favoriten“ in der Suche hatte keinen Weg, Orte zu merken → Stern in der Routen-Vorschau
5. „Zuhause · 14 Min“ setzt eine berechnete Route voraus → Minuten nur zeigen, wenn eine Route jünger als 15 Min vorliegt, sonst nur „Zuhause“
6. Losfahr-Hinweis braucht Mitteilungen + Routing im Hintergrund (iOS führt das nicht verlässlich aus) → nicht in Version 1, raus aus dem Onboarding
7. Ankunft „neue Straßen / Stufe“ setzt Entdecken voraus, das in Swift fehlt → ausblenden, bis Entdecken gebaut ist
8. Einstellungen ohne „Demo-Fahrt“ → Apple-Prüfer braucht sie (siehe `docs/APPSTORE_TEXTE.md`) → bleibt in den Einstellungen
9. Shop ohne „Käufe wiederherstellen“ wird von Apple abgelehnt → Pflicht-Link
10. „Alle Stile, auch künftige“ ist ein Versprechen → technisch: Freischaltung `ezmaps.styles.all` gilt für jeden Stil in Code, nicht nur für eine Liste
11. Fahrten-Verlauf speichert Wege (inkl. Wohnort) → nur lokal, abschaltbar, löschbar; im Fotomodus Start/Ziel ausblendbar (GM-029)
12. Standort abgelehnt → App darf nicht leer sein: Karte und Suche gehen, „Los“ führt zu den iOS-Einstellungen

**Tatsächlich geprüft:** Playwright (Chromium) ohne Skriptfehler, alle 10 neuen Screens und das geänderte Onboarding als Bild angesehen.

**Ungetestet:** Nichts in Swift.

### Auftrag (Swift, nach GM-032, gleiche Glas-Bausteine)

Vorlage: `glas.html`. Je Punkt eigener Eintrag, Logik in Core mit Tests wo möglich.

1. **Shop** (`StoreView`): Kopf „Stile“ + Schließen; große Karte Neon City mit Schild „Beliebtester Stil“ und Live-Mini-Karte; Liste der Stile (Vorschau 54 pt, Name, Satz, Preis aus `Product.displayPrice` bzw. ✓ wenn gekauft); `PrimaryButton` „<Stil> · Preis“, darunter Zeile „Alle Stile · Preis einmalig“; Feintext „Einmalkauf, kein Abo. Gilt für iPhone und CarPlay.“; Link „Käufe wiederherstellen“ (`AppStore.sync()`). StoreKit 2 wie GM-029 Punkt 1
2. **Stil testen**: 10 Min je Premium-Stil, einmal pro Stil (in UserDefaults merken). Glas-Banner oben „Neon City · Vorschau, noch m:ss“ + „Kaufen“. Ablauf: wenn keine Navigation läuft, zurück zu Klassik + Shop-Blatt; während der Navigation erst nach Ende. Logik in Core `StyleTrial` (Test: läuft nicht ab, solange `isNavigating`)
3. **Freigeschaltet**: Blatt mit Haken, „<Stil> gehört dir“, „Losfahren“, „Andere Stile ansehen“; Stil sofort aktiv (auch CarPlay)
4. **Meine Fahrten**: Liste nach Tagen, Mini-Karte je Fahrt, Summe Monat (km, Fahrten, Zeit), Teilen → Fotomodus. Core `TripLog` (Codable, nur lokal, max. 200 Fahrten), Einstellung „Fahrten speichern“ (an) + „Alle löschen“. Spur aus `NavigationSession` (GM-029 Punkt 8)
5. **Favoriten**: Stern-Knopf in der Routen-Vorschau, Chip „Als Favorit gemerkt“; Kategorie „Favoriten“ in der Suche zeigt sie; Löschen per Wischen
6. **Parkplatz** im Glas-Look wie Bild (GM-029 Punkt 3 gilt weiter)
7. **Baustelle voraus**: oranges Glas-Banner (`#FF9F1C` 82 %) unter dem Abbiegehinweis, „Baustelle in 1,8 km“ + Satz aus der Meldung (GM-029 Punkt 4)
8. **Neu berechnen**: lila Glas-Banner „Route wird neu berechnet · Du bist anders gefahren“, Ankunftszeit grau + „wird aktualisiert …“ bis die neue Route da ist (kein Vollbild)
9. **Kein GPS / kein Netz**: Chips „Kein GPS · Position geschätzt“ (nach 5 s ohne Fix während der Fahrt, Fortschritt mit letzter Geschwindigkeit schätzen, Core-Test) und „Offline · Route bleibt“ (`NWPathMonitor`); Tacho zeigt „–“
10. **Standort aus**: Blatt „Standort ist aus · In Einstellungen erlauben“ (`UIApplication.openSettingsURLString`) + Suche bleibt nutzbar; Kartenmitte Idstein bzw. letzter bekannter Ort
11. Logik-Befunde 1–12 oben in Code und Texten umsetzen; `docs/legal/index.md` um Fahrten-Verlauf (lokal) ergänzen

## GM-032 – Entscheidung: UI-Richtung „B · Glas“ – Auftrag für den lokalen Claude

**Ziel:** Der Nutzer hat sich für das Glas-Design entschieden (GM-030 Richtung B, GM-031 Onboarding Richtung B). Die ganze iPhone-Oberfläche wird darauf umgestellt. A, C, D werden nicht umgesetzt.

**Dateien:** `CHANGELOG.md` (nur Auftrag, kein Code)

**Tatsächlich geprüft:** Nichts gebaut. Vorlagen: `docs/previews/designs/B-glas.png`, `http://localhost:8765/tools/prototype/designs.html` (Abschnitt B), `http://localhost:8765/tools/prototype/onboarding.html` (Abschnitt B). Werte stammen aus `tools/prototype/designs.css` (`.B …`) und `tools/prototype/onboarding.css` (`.B .f …`).

**Ungetestet:** Alles, Umsetzung steht aus.

### Auftrag (Swift, iPhone; CarPlay bleibt bei Apples Vorlagen)

Vor dem Start `docs/LESSONS_SWIFT.md` lesen. Je Block eigener Eintrag GM-0xx, nach jedem Block Mac-Build + Screenshots (`tools/mac_screens.sh`) und mit den Vorlagen vergleichen. Keine Gedankenstriche in UI-Texten (GM-023). Deutsch + Englisch.

**1. Design-Bausteine (`App/Design/Glass.swift`, neu)**
- Farben: Akzent `#B44DFF`, Verlauf bis `#7A2BD8` (135°), Ende/Gefahr `#FF3B4E`, Text weiß, Nebentext `#A9A9B2`, Erfolg `#58B05F`
- Glas-Fläche `GlassCard`: `.ultraThinMaterial` (dunkel), darüber `rgb(28,28,32)` mit 45 % Deckkraft, Rand 0,5 pt weiß 18 %, Ecken 26 pt (Blätter) / 20 pt (Karten) / 14 pt (Felder, Zeilen), `.continuous`; Schatten schwarz 35 %, Radius 30, y 10
- `GlassChip` (Kapsel, Innenabstand 8×13 pt, 14 pt semibold, Symbol in Akzentfarbe), `GlassRoundButton` (48-pt-Kreis), `PrimaryButton` (Höhe 56, Ecken 18, Verlauf, Schatten Akzent 45 % Radius 24 y 8, 19 pt heavy), `SecondaryButton` (Text 15 pt, weiß 75 %), `SheetGrabber` (38 × 5 pt, weiß 35 %)
- Schrift: SF Pro (System), Titel 28 pt heavy, Laufweite −0,6; Zahlen `.monospacedDigit()`
- „Transparenz reduzieren“ an: feste Fläche `#1C1C20` statt Material. „Bewegung reduzieren“ beachten
- Alle Bausteine mit `#Preview`

**2. Startkarte** (Vorlage B, Bild 1)
- Suche **unten** im Daumenbereich als Glas-Blatt mit Griff: Feld „Wohin?“ + Mikrofon, darunter Chips „Zuhause · 14 Min“, „Arbeit · 22 Min“, „Tanken“, „Parken“ (Zuhause/Arbeit nur wenn festgelegt; Minuten aus dem letzten Routing, sonst ohne Zeit)
- Rechts oben zwei `GlassRoundButton`: Zentrieren, Einstellungen
- Hochziehen oder Tippen öffnet die Suche im selben Blatt (Blatt wird hoch, Tastatur), kein Vollbild-Wechsel
- OSM-Hinweis über dem Blatt rechts

**3. Suche** (Onboarding-Seite B, Bild 6)
- Feld oben im Blatt mit Akzent-Rand 1,5 pt. Ohne Eingabe: 4 Kategorie-Kacheln (Tanken, Parken, Essen, Favoriten) und „Zuletzt“ als Glas-Liste (Symbol in 38-pt-Kachel mit 12 pt Ecken, Titel, Untertitel, Entfernung rechts)

**4. Routen-Vorschau** (B, Bild 2)
- Zurück als runder Glas-Knopf oben links (kein Balken mehr)
- Glas-Blatt unten: Titel 28 pt heavy, Untertitel, Schließen-Kreis 36 pt oben rechts
- Routen als Zeilen (Ecken 16): **Minuten groß zuerst**, darunter „Schnellste · 1,9 km · an 9:47“. Gewählte Zeile: Akzent 22 % Fläche + 1,5 pt Rand Akzent; erste Route mit Chip „Empfohlen“
- `PrimaryButton` „Los“
- Karte so einpassen, dass die Route über dem Blatt liegt (Blatthöhe messen, nicht schätzen)

**5. Navigation** (B, Bild 3)
- Abbiegehinweis oben als Glas-Karte mit Akzent-Tönung (`#7C28C8` 72 % über Material): Pfeil 46 pt, Entfernung 40 pt heavy, Straße 18 pt bold
- Darunter links Chip „danach links · Wiesbadener Str.“, rechts Tempolimit-Schild 56 pt (Zeichen 282 bei unbegrenzt bleibt, GM-022)
- Unten eine Glas-Leiste: links runder Tacho (km/h in 48-pt-Kreis, weiß 8 %), Mitte Ankunftszeit 24 pt heavy + „5 Min · 1,1 km“, rechts runder Ende-Knopf `#FF3B4E` mit ×. Zentrieren nur, wenn die Karte verschoben wurde
- „Musik leiser“ als kleiner Chip, wenn aktiv

**6. Ankunft** (Onboarding B, Bild 7)
- Glas-Blatt: „Angekommen · 9:47“ (Akzent, klein, Großbuchstaben), Zielname, 3 Werte-Kacheln (km, Min, neue Straßen grün), Stufen-Balken nur wenn Entdecken aktiv ist; „Fertig“ + runder Teilen-Knopf

**7. Onboarding (neu, nur beim ersten Start)** (Onboarding B, Bild 1, 2, 3, 5; Bild 4 „Fahrzeug“ gestrichen)
- 1 Willkommen: Karte im Hintergrund (langsame Kamerafahrt, bei „Bewegung reduzieren“ still), App-Icon, „EzMaps“, ein Satz, „Los geht's“, „Ich habe schon EzMaps“ (= überspringen)
- 2 Standort: Erklärung (zwei Zeilen „Karte zeigt dich“, „Ansagen laufen weiter“; **kein** Hinweis „Kein Konto, kein Tracking“ und **nicht** „Standort bleibt auf dem iPhone“, siehe GM-033), **erst nach Tipp auf „Standort erlauben“** `requestWhenInUseAuthorization`; „Später“ geht weiter. Abgelehnt → später Hinweis mit Knopf zu den iOS-Einstellungen
- 3 Stil wählen: 2×2 Kacheln mit echter Mini-Karte (MapLibre-Schnappschuss, gecacht), Klassik „Gratis“, andere „Premium · Kostenlos testen“ (StoreKit siehe GM-029 Punkt 1; bis dahin nur vorhandene Stile)
- ~~Fahrzeug wählen~~: **gestrichen (Nutzer-Entscheidung), nicht umsetzen.** Spieler-Symbol bleibt der Pfeil. Das Onboarding hat damit nur 4 Schritte
- 4 Zuhause/Arbeit + Schalter Sprachansagen und Losfahr-Hinweis (Mitteilungs-Erlaubnis nur fragen, wenn eingeschaltet)
- Fortschritt oben als 3 Striche (Akzent) + „Schritt x von 3“ (Standort, Stil, Zuhause/Arbeit). `AppSettings.onboardingDone`; Screenshot-Modus überspringt das Onboarding

**8. Einstellungen**
- Eigene Glas-Liste statt `Form`: oben Karte „Stil“ mit Mini-Vorschau, dann Gruppen Navigation (Stimme, Autobahn meiden, Tempolimit anzeigen …), Orte (Zuhause, Arbeit), Daten und Recht. Schalter in Akzentfarbe, alles scrollbar

**9. Prüfen**
- Kleine Geräte 375 × 667 (LESSONS_SWIFT 2): nichts abgeschnitten, Blätter scrollen
- App bleibt dunkel; auf hellem Kartenstil (Klassik) muss Glas lesbar bleiben (dann `.regularMaterial` + 60 % Fläche)
- VoiceOver-Beschriftungen für alle runden Knöpfe
- Store-Screenshots neu (`tools/mac_screens.sh`), zusätzlich Onboarding Bild 1–3

## GM-031 – Onboarding und weitere Screens in den vier UI-Richtungen

**Ziel:** Nutzer will auch Onboarding usw. sehen; Ideen aus anderen Navi-Apps einbeziehen.

**Dateien:** `tools/prototype/onboarding.html`, `tools/prototype/onboarding.css`, `tools/prototype/js/onboarding.js` (neu), `tools/prototype/js/vorschau.js` (startet nur noch auf der eigenen Seite)

**Geändert:**
- Neue Seite `http://localhost:8765/tools/prototype/onboarding.html`: 8 Screens (Willkommen, Standort mit Erklärung vor der iOS-Frage, Stil wählen, Fahrzeug wählen, Zuhause/Arbeit + Ansagen, Suche ohne Eingabe, Ankunft mit Stufe, Einstellungen) je Richtung A–D. Gleiches HTML, Aussehen nur per CSS-Skin
- Ideen aus der Recherche: Standort bei Navi-Apps gleich zu Beginn, aber mit Erklär-Bildschirm vorher (Waze-Muster; abgelehnte iOS-Abfrage lässt sich nur über Einstellungen zurückholen); Fahrzeug-Symbol wählbar wie bei Waze/Google Maps

**Tatsächlich geprüft:** Playwright (Chromium) ohne Skriptfehler, alle 32 Screens als Bild angesehen.

**Ungetestet:** Nichts in Swift; Auswahl der Richtung durch den Nutzer steht aus. Bilder nicht im Repo (zu groß), Seite selbst öffnen.

## GM-030 – UI-Entwürfe A bis D (HUD, Glas, Minimal, Sticker)

**Ziel:** Der Nutzer mag das jetzige UI nicht; vier Richtungen zum Auswählen zeigen.

**Dateien:** `tools/prototype/designs.html`, `tools/prototype/designs.css`, `tools/prototype/js/designs.js` (neu), `docs/previews/designs/{A-hud,B-glas,C-minimal,D-sticker}.png` (neu)

**Geändert:**
- Neue Prototyp-Seite `http://localhost:8765/tools/prototype/designs.html`: je Richtung Startkarte, Routen-Vorschau, Navigation auf der echten Neon-Karte
- A HUD (Barlow Condensed, Monospace-Zahlen, abgeschrägte Ecken), B Glas (iOS-nah, Bedienung unten), C Minimal (Pillen), D Sticker (dicke Konturen, Gelb)

**Tatsächlich geprüft:** Playwright (Chromium) ohne Skriptfehler, alle 12 Bildschirme als Bild angesehen.

**Ungetestet:** Nichts in Swift. Auswahl durch den Nutzer steht aus, danach Auftrag für den lokalen Claude.

## GM-029 – Ideen-Vorschau (Parkplatz, Baustellen, Stimmen, Widgets, Fotomodus, Route sofort) + neuer Gratis-Stil „Klassik“ – mit Auftrag für Swift

**Ziel:** Die vom Nutzer gewählten Ideen im Prototyp zeigen (die Radar-Minikarte war zuerst dabei und ist auf Wunsch des Nutzers wieder gestrichen) und so genau beschreiben, dass der lokale Claude sie in Swift umsetzen kann. Neon City ist der beliebteste Stil und wird deshalb Premium; gratis ist ab jetzt der neue Stil „Klassik“.

**Dateien:** `tools/prototype/vorschau.html`, `tools/prototype/vorschau.css`, `tools/prototype/js/vorschau.js` (alle neu), `tools/prototype/data/autobahn_a3_idstein.json` (neu, echte Meldungen), `tools/prototype/js/{map,phone,carplay}.js`, `tools/prototype/style.css`, `Assets/Generated/Ideen/*.png` (neu, 15 Symbole), `docs/previews/ideen/*.jpg` (neu, 7 Bilder), `docs/TODO_PROTOTYP_REVIEW.md`

**Geändert (Prototyp):**
- Neue Seite **Ideen-Vorschau**: `python tools/prototype/serve.py` → `http://localhost:8765/tools/prototype/vorschau.html`. Alle Bilder mit dem echten Karten-Renderer; Bilder auch in `docs/previews/ideen/`
- Neuer Stil **Klassik** (`STYLES.classic`, `free: true`, Palette `CLASSIC` in `js/map.js`): heller Stadtplan – Land `#f2efe9`, Wohnen `#ece7e0`, Gewerbe `#ebe3e8`, Feld `#eef0d6`, Park `#d4ebc8`, Wald `#c3dfb4`, Wasser `#aad3df`, Gebäude `#ddd5cc` (Kante `#cbc0b5`), Straßen weiß mit Rand `#c9c1b6`, Hauptstraßen `#fde7a6`, Autobahn `#f7c56b`, Bahn `#a3a3a3`, Breite ×1,15, Route `#1a73e8` (Rand `#0b3d91`). Theme `.t-classic` (weiß, blau, Inter). Stilwahl, Stile-Seite und CarPlay zeigen „Gratis“ nur noch für Klassik, sonst „Premium · Vorschau testen“
- Symbole je Stil als PNG (@3x) für die App: `Assets/Generated/Ideen/parked-car-{classic,neon,western,pixel,toy}@3x.png` (60 × 90 pt), `roadworks-{stil}@3x.png` und `closure-{stil}@3x.png` (40 × 40 pt). Quelle/Spiegel: `drawParkedCar`, `drawWorkIcon` in `tools/prototype/js/vorschau.js`
- Kleinigkeiten im klickbaren Prototyp: Text der Stilwahl („Klassik ist gratis …“), Symbole von Zuhause/Arbeit in hellen Stilen sichtbar

**Tatsächlich geprüft:** Playwright (Chromium): Vorschau-Seite ohne Skriptfehler, alle Abschnitte als Bild angesehen; klickbarer Prototyp mit Stil „Klassik“ (Stilwahl, Karte iPhone + CarPlay) ohne Fehler. Autobahn-API live abgefragt (CORS offen, JSON wie unten). Routing-Zeiten gemessen: Valhalla FOSSGIS 0,5–1,0 s (mit/ohne Alternativen gleich), Photon 0,6 s.

**Ungetestet:** Nichts davon ist in Swift gebaut. Auf dem Mac nichts geprüft.

### Auftrag für den lokalen Claude (Swift) – Reihenfolge = Priorität

Allgemein: vor jedem Punkt `docs/LESSONS_SWIFT.md`; Logik in `Core/` mit Tests (`swift test` geht auch unter Linux); Texte deutsch + englisch; je Punkt eigener Eintrag GM-0xx; nach jedem Punkt Mac-Build. Bilder zum Vergleich: `docs/previews/ideen/`.

**1. Gratis-Stil „Klassik“, Neon City Premium (vor der Veröffentlichung nötig)**
- `MapStyle`: neuer Fall `.classic = "classic"`, `titleKey` „Klassik“ (en „Classic“), `MapStyle.free = .classic`. Alle `switch` über `MapStyle` nachziehen (grep). `MapStyleTests` anpassen (genau ein Gratis-Stil = classic)
- `tools/maplibre/build_style.py` um Klassik erweitern (Werte oben, aus `CLASSIC` in `js/map.js`), erzeugt `App/MapStyles/style-classic.json` (nie von Hand). Route in Klassik `#1a73e8`/`#0b3d91` (in `NeonColors` → besser `StyleColors` je Stil)
- Neue Nutzer starten mit Klassik. Neon City „Vorschau testen“: Demo-Fahrt im Stil (oder 10 Minuten freie Nutzung), danach zurück zu Klassik mit Kauf-Hinweis
- StoreKit 2, nicht verbrauchbar: `ezmaps.style.neon`, `ezmaps.style.western`, `ezmaps.style.pixel`, `ezmaps.style.toy`, `ezmaps.styles.all` (alle, auch künftige). Preise nur aus StoreKit; „Käufe wiederherstellen“ in den Einstellungen; `Transaction.updates` beim Start abhören. StoreKit-Testdatei für den Simulator
- Stile-Seite wie `docs/previews/ideen/9-gratis-klassik.jpg`: Neon groß zuerst mit „Beliebtester Stil“, Pillen „Gratis“/„Premium“, unten „Alle Stile – Freischalten“
- `docs/APPSTORE_TEXTE.md` anpassen: Klassik gratis, Neon City & Co. als In-App-Kauf; In-App-Käufe in App Store Connect anlegen

**2. Route ohne Wartezeit** (Bild `8-route-sofort.jpg`)
- Beim Antippen eines Treffers sofort `.preview` mit Ziel, gestrichelter Luftlinie und Schätzung „≈ x Min“ (Luftlinie × 1,35 / 45 km/h) – kein Vollbild-Ladefenster mehr, nur kleiner Hinweis „Route kommt …“. Route und Alternativen ersetzen die Linie, sobald da
- Vorab rechnen: Wenn Suchtreffer da sind, Route zum obersten Treffer im Hintergrund holen (Task, bei neuer Eingabe abbrechen; max. 1 Anfrage je 2 s – Fair-Use)
- Cache: Antworten 5 Min merken (Schlüssel: Ziel + Start auf 50 m gerundet + Optionen). Logik in Core (`RouteCache`) mit Tests
- Ziel: < 300 ms bis zur Route bei Cache-Treffer, sonst ≤ 1 s. Zeit messen und im Log ausgeben

**3. „Wo hab ich geparkt?“** (Bild `3-parkplatz.jpg`, Symbole `parked-car-*.png`)
- Merken, wenn sich CarPlay trennt (`didDisconnect`) und die letzte Position < 5 Min alt ist; zusätzlich „Hier geparkt“ von Hand (lange auf den Standort drücken) und „Auto vergessen“
- Core `ParkedCar` (Koordinate, Zeit, Adresse) Codable, gespeichert in UserDefaults der App-Gruppe (für Widgets); Adresse per Photon `/reverse`
- Karte: Auto-Symbol des aktiven Stils, **Schnauze nach oben** (nicht mitdrehen), Schild „Dein Auto · seit 14:32“. Karte unten: Adresse, Entfernung, Fußweg (Entfernung / 1,3 m/s), Knöpfe „Zu Fuß hin“ (Apple Karten, `MKLaunchOptionsDirectionsModeWalking`), „Teilen“, „✕“
- Auch im CarPlay-Kartenfenster sichtbar

**4. Baustellen und Sperrungen (Autobahn GmbH)** (Bild `4-baustellen.jpg`, Symbole `roadworks-*`/`closure-*`)
- API: `GET https://verkehr.autobahn.de/o/autobahn/` (Liste), `…/{Straße}/services/roadworks`, `…/closure`, `…/warning`. Felder: `display_type` (ROADWORKS, SHORT_TERM_ROADWORKS, CLOSURE, WARNING …), `title`, `subtitle` (Richtung), `coordinate {lat, long}` (Text), `geometry` (LineString, lon/lat), `isBlocked` („true“/„false“), `startTimestamp`, `description` (Liste). Beispiel: `tools/prototype/data/autobahn_a3_idstein.json`. **Keine** Blitzer o. Ä. übernehmen (§ 23 StVO); Nutzungsbedingungen der API vor dem Start prüfen und Quelle „Verkehrsdaten: Autobahn GmbH des Bundes“ in den Einstellungen nennen
- Core `AutobahnClient` (über `HTTPClient`, Tests mit Attrappe) + `IncidentMatcher`: nur Meldungen, deren Linie ≤ 30 m an der Route liegt **und** in Fahrtrichtung (Winkel Meldung ↔ Route < 60°). Straßen aus den Routennamen (`A 3`/`A3`), Abfrage beim Routen und alle 10 Min
- Karte je Stil (Werte aus `drawWork`): Linie auf der Fahrbahn, Grund + Strichlinie: Klassik weiß/`#e8710a`, Neon `#0b0b0c`/`#ff9f1c` mit Leuchten (Sperrung `#ff2d55`), Western `#f2e4bf`/`#c0261f`, Pixel schwarz/`#ffcc33` eckig, Toy weiß/`#ff6b00`; Sperrung jeweils rot. Symbol (PNG) in der sichtbaren Mitte. MapLibre: `MLNLineStyleLayer` mit `lineDashPattern`, Neon zusätzlich `lineBlur`; `MLNSymbolStyleLayer` mit den PNGs
- Warnung 2 km vorher (Autobahn), 1 km sonst: Banner unter dem Abbiegehinweis im Stil (Bild `4-baustellen.jpg` rechts) + Ansage „Achtung, Baustelle in 2 Kilometern.“; CarPlay: `CPNavigationAlert` (8 s)

**5. Stimmen-Auswahl (allgemein, nicht je Stil)** (Bild `5-stimmen.jpg`)
- Einstellungen → „Stimme“: alle `AVSpeechSynthesisVoice.speechVoices()` mit Sprache `de*`, sortiert Premium > Erweitert > Standard, mit Probehören (Satz „In 300 Metern rechts abbiegen auf Hauptstraße.“), Häkchen, Hinweis wie Premium-Stimmen in iOS geladen werden
- Sprechtempo-Regler (0,40–0,60, Standard 0,50). `AppSettings.voiceIdentifier`, `speechRate`; `SpeechService` nimmt sie, Ersatz `de-DE`

**6. ~~Radar-Minikarte~~ – gestrichen (Nutzer-Entscheidung), nicht umsetzen.**

**7. Widgets und Kurzbefehle** (Bild `6-widgets-kurzbefehle.jpg`)
- Vorher nötig: „Zuhause“/„Arbeit“ in den Einstellungen festlegen (Suche wiederverwenden)
- Widget-Erweiterung (WidgetKit, neues Target in `project.yml`, App-Gruppe `group.<Bundle-ID>`): klein „Nach Hause“ (Fahrzeit, Ankunft), klein „Dein Auto“ (Entfernung, Adresse), mittel „Zur Arbeit“ (Fahrzeit, Baustellen-Hinweis, Knopf „Losfahren“ = `ezmaps://route?to=work`), Sperrbildschirm rund + rechteckig. Kartenbild nicht im Widget rendern (Speichergrenze) – die App legt ein Vorschaubild (PNG) in die App-Gruppe; Fahrzeit aus dem letzten Wert, Aktualisierung höchstens alle 15–30 Min
- App Intents + `AppShortcutsProvider` (Deutsch, mit `\(.applicationName)`): „Navigiere nach Hause“, „Navigiere zur Arbeit“, „Navigiere zu …“ (Ort), „Wo ist mein Auto?“, „Fahrzeit nach Hause“ (Antwort ohne App), „Tankstelle in der Nähe“. Navigation-Intents öffnen die App und starten direkt (auch für CarPlay)

**8. Fotomodus** (Bild `7-fotomodus.jpg`)
- Core: `NavigationSession` merkt die gefahrene Spur (Punkt alle 20 m) – Test
- Knopf „Foto“ im Ankunfts-Blatt (und später „Meine Fahrten“). Editor: Format Story 1080 × 1920 / Quadrat 1080 × 1080 / Breit 1920 × 1080, Stil (eigene Stile; fremde mit Wasserzeichen „Premium“), Schalter Werte/Titel/Datum/„Start und Ziel ausblenden“ (je 300 m abschneiden – Wohnort schützen)
- Bild: `MLNMapSnapshotter` (Kamera auf die Spur eingepasst) + darüber Route, Start/Ziel, Titel, Werte (km, Min, später „neue Straßen“), Logo als Bild-Asset (**nicht** Pricedown – keine App-Lizenz), Hinweis „© OpenMapTiles · © OpenStreetMap-Mitwirkende“ immer im Bild
- Teilen über `ShareLink`; „Sichern“ braucht `NSPhotoLibraryAddUsageDescription`

**Danach:** `docs/legal/index.md` um Autobahn GmbH ergänzen (übermittelt: befahrene Autobahnen, IP), `PrivacyInfo.xcprivacy` prüfen (keine neuen Datenarten), `docs/VEROEFFENTLICHUNG.md` (In-App-Käufe, Widget-Target, App-Gruppe) nachziehen.
## GM-028 – Straßennamen in schmaler Fettschrift, weniger Rechenlast

**Ziel:** Straßennamen wie im Foto des Nutzers; Ruckeln verringern.

**Dateien:** `tools/maplibre/build_glyphs.py` (neu), `Resources/Glyphs/Barlow Condensed SemiBold/*.pbf` (neu), `Resources/Glyphs/OFL-BarlowCondensed.txt`, `tools/maplibre/build_style.py`, `App/MapStyles/style-neon-city.json`, `App/{FollowCamera,NeonMapView,ContentView,CarPlaySceneDelegate}.swift`, `project.yml`, `tools/mac_{run,screens,archive}.sh`, `docs/store/*`

**Geändert:**
- Straßennamen in Barlow Condensed SemiBold (SIL OFL 1.1), Großbuchstaben, größer, mehr Buchstabenabstand. Kartenschrift (SDF-Glyphen) selbst erzeugt und in der App gebündelt (`asset://Glyphs/…`) – OpenFreeMap hat nur Noto Sans
- CarPlay: Karte und Kamera mit 30 statt 60 Bildern/s
- Kamera setzt im Stand nichts neu
- iPhone-Karte pausiert, wenn die App nicht aktiv ist (gesperrt, Hintergrund, nur CarPlay)
- Übertragungs-Skripte schicken `Resources/` mit

**Tatsächlich geprüft:** Glyphen mit MapLibre GL JS im Browser gerendert; Mac: BUILD SUCCEEDED, 27/27 Tests; iPhone- und CarPlay-Screenshots angesehen (neue Schrift sichtbar).

**Ungetestet:** Flüssigkeit auf echtem iPhone und Autoradio (Simulator ist dafür ungeeignet).

## GM-027 – Screenshot-Durchsicht: CarPlay-Vorschau, Hinweistext, (i), ruhigere Übersicht

**Ziel:** Alle Screenshots durchsehen und gefundene Fehler beheben.

**Dateien:** `App/{CarPlaySceneDelegate,FollowCamera,NeonMapView,ContentView}.swift`, `tools/maplibre/build_style.py`, `App/MapStyles/style-neon-city.json`, `docs/store/*`

**Geändert:**
- CarPlay-Vorschau: Kamera vor dem Einpassen stoppen (überschrieb den Ausschnitt), Strecke rechts neben dem iOS-Fenster, passende Ränder für das ~400 pt breite Fenster
- CarPlay: OSM-Hinweis oben rechts, zweizeilig, nie unter den iOS-Fenstern; kein GPS-Punkt und kein (i) von MapLibre; Tempolimit links neben den Kartenknöpfen
- iPhone: (i)-Knopf ganz aus (ragte in Such- und Vorschau-Leiste), Startkarte Zoom 15 statt 13, Routen-Vorschau mit mehr Rand
- Karte: kleine Straßen erst ab Zoomstufe (Nebenstraßen 12, Zufahrten 14) – die Übersicht war eine weiße Fläche
- Hinweis: grauer Punkt in der CarPlay-Navigation ist ein Teich (Wasser), kein Fehler

**Tatsächlich geprüft:** `mac_check.sh`: BUILD SUCCEEDED (signiert + unsigniert), 27/27 Tests; alle 5 iPhone- und 3 CarPlay-Bilder angesehen.

**Ungetestet:** Auf echtem iPhone/Auto noch nicht gefahren. Zwei Prüfläufe überschnitten sich zwischendurch auf dem Mac (Fehlermeldung „EzMaps.xcodeproj does not exist“) – das lag an parallel laufenden Läufen, nicht am Code.

## GM-026 – Straßennamen und Kartensymbole wie Vorlage, Neon-Pfeil V2 von Codex

**Ziel:** Straßennamen auch in der Fahrt sichtbar, weiße Symbole wie im Foto, neuer Pfeil.

**Dateien:** `tools/maplibre/build_style.py`, `App/MapStyles/style-neon-city.json`, `App/{NeonMapView,FollowCamera,CarPlaySceneDelegate}.swift`, `App/Assets.xcassets/{PlayerNeon,PlayerNeonGlow}.imageset` (neu), `Assets/Generated/Player/NeonV2/*` (Codex), `tools/mac_build.sh`, `docs/store/*`

**Geändert:**
- Straßennamen ab Zoom 13,5 (vorher 15, die CarPlay-Fahrkamera lag darüber), auch Nebenwege
- Weiße Kartensymbole mit schwarzem Rand (Einkauf, Kreuz, Tanken, Parken, Essen, Laden) ab Zoom 14,5; Bilder zeichnet die App beim Laden
- Pfeil V2 von Codex als Asset; während der Navigation mit lila Leuchten
- (i)-Knopf in der Fahrt aus; CarPlay-Screenshot-Lauf: Fenster nur einschalten, wenn es fehlt, Klick zweimal mit Pause, Bildschirm wecken

**Tatsächlich geprüft:** Mac: BUILD SUCCEEDED, 27/27 Tests; iPhone-Screenshots neu angesehen; CarPlay „frei“ mit Straßennamen und neuem Pfeil angesehen.

**Ungetestet:** Letzter CarPlay-Lauf: AppleScript kam nicht an das Simulator-Fenster (vermutlich Mac gesperrt) – CarPlay-Bilder vom vorherigen Lauf behalten.

## GM-025 – Pfeil gleitet weich, CarPlay ohne Route als Hauptmodus, Prüflauf mit Screenshots

**Ziel:** Ruckelnden Pfeil beheben; CarPlay soll auch ohne Route gut aussehen (Pfeil mittig); nach jeder Änderung Screenshots.

**Dateien:** `App/FollowCamera.swift` (neu), `App/{NeonMapView,CarPlaySceneDelegate,AppModel}.swift`, `tools/mac_build.sh`, `tools/mac_screens.sh`, `tools/mac_check.sh` (neu), `docs/ASSETS_CODEX.md`, `docs/store/*`

**Geändert:**
- Ursache Ruckeln: Pfeil sprang bei jeder Position (Demo 2×/s, GPS 1×/s). Jetzt: fester Pfeil, Kamera gleitet 60×/s weich nach (Position, Richtung, Höhe getrennt geglättet)
- CarPlay: immer Folgekamera (flach, Fahrtrichtung oben), auch ohne Route; Pfeil in der Mitte der freien Fläche (Safe Area, also neben der Abbiegekarte von iOS); Zoom-Knöpfe ändern die Höhe; nur die Routen-Vorschau zeigt die ganze Strecke
- iPhone-Navigation: Pfeil im unteren Drittel, Kompass aus
- CarPlay-Entfernungen in km ab 1 km (vorher „14.602 m“), Kompass und (i) im Auto aus
- `bash tools/mac_check.sh`: Build + Tests, dann iPhone- und CarPlay-Screenshots (CarPlay-Zustand „frei“ mit simulierter Fahrt durch Idstein), Übersicht `docs/store/uebersicht.png`; alte Bilder werden vorher gelöscht
- Codex-Prompt für einen neuen Neon-Pfeil (Abschnitt 4b)

**Tatsächlich geprüft:** `mac_check.sh` auf dem Mac: BUILD SUCCEEDED, 27/27 Tests; 5 iPhone- und 3 CarPlay-Bilder aus dem Simulator angesehen (km korrekt, Pfeil mittig ohne Route, neben der Abbiegekarte mit Route).

**Ungetestet:** Glätte der Bewegung nur über Einzelbilder beurteilt, nicht als Video; auf dem echten iPhone im Auto noch nicht gefahren.

## GM-024 – Neon City nach dem Foto des Nutzers

**Ziel:** Karte auf iPhone und CarPlay wie die Vorlage: mittelgrau, helle Häuser, weiße Straßen mit dunklem Rand, Straßennamen auf der Straße.

**Dateien:** `tools/maplibre/build_style.py`, `App/MapStyles/style-neon-city.json`, `tools/prototype/js/map.js`, `tools/mac_build.sh`, `tools/mac_screens.sh`, `docs/store/iphone-69/*`

**Geändert:**
- Palette: Boden `#3B3C3E`, Häuser `#5B5C5F`, Straßen `#ECECEC`/`#DCDCDC` mit Rand `#151617`, Wasser `#5D6870`; dunkle „Stadtblöcke“ entfernt
- Straßennamen (Großbuchstaben, dunkel, entlang der Straße, ab Zoom 15) mit Schrift von OpenFreeMap (Noto Sans Bold)
- Prototyp gespiegelt (gleiche Werte)
- `bash tools/mac_screens.sh freigabe`: öffnet am Mac die Einstellung „Bedienungshilfen“ und zeigt `sshd-keygen-wrapper` im Finder

**Tatsächlich geprüft:** Stil mit MapLibre GL JS gerendert und mit dem Foto verglichen; Mac-Build BUILD SUCCEEDED, 27/27 Tests; neue iPhone-Store-Screenshots angesehen.

**Ungetestet:** Kartensymbole (Einkaufskorb, Kreuz …) aus dem Foto fehlen noch in der App. CarPlay-Screenshots hängen an der Freigabe am Mac.

## GM-023 – Nutzer-Feedback: keine Gedankenstriche, runde Ecken, Pfeil wie Prototyp, Pixel scharf, CarPlay-Bilder

**Ziel:** Rückmeldungen zur ersten echten App umsetzen.

**Dateien:** `App/{ContentView,NeonMapView,CarPlaySceneDelegate,AppModel,SpeechService,SettingsScreen,ScreenshotMode}.swift`, `App/en.lproj/Localizable.strings`, `tools/prototype/{js/tilejob.js,js/app.js,js/map.js,js/phone.js,index.html,style.css}`, `tools/mac_build.sh`, `tools/mac_screens.sh`, `docs/APPSTORE_TEXTE.md`, `docs/store/iphone-69/*`, `docs/previews/*`

**Geändert:**
- Keine Gedankenstriche mehr in sichtbaren Texten (App, Prototyp, Store-Texte)
- Runde Ecken (16/10 pt) statt eckiger Kästen in der App
- Positionspfeil exakt wie `player-neon.svg` (Prototyp), aufrecht statt flach auf der geneigten Karte, mit Schatten
- Kamera folgt der Fahrposition (auch Demo-Fahrt), Höhe nach Tempo (Stadt nah, Autobahn weit); CarPlay flach von oben
- „∞“ ersetzt durch Zeichen 282 „Ende aller Streckenverbote“; in CarPlay ohne Limit kein Schild
- Ansagen mit der besten installierten deutschen Stimme (Premium/Erweitert, wenn geladen)
- Prototyp Pixel Quest: Detail-Kachel im Kunstpixel-Raster ohne Glättung hochgerechnet (vorher unscharf), „danach …“ überlappt den Tacho nicht mehr
- Store-Screenshot der Navigation mitten auf der Strecke; Statusleiste 9:41; iOS-Tastatur-Einführung aus
- CarPlay-Screenshot-Lauf (`bash tools/mac_screens.sh carplay`) über AppleScript

**Tatsächlich geprüft:** Mac-Build signiert + unsigniert BUILD SUCCEEDED, `swift test` 27/27; 5 iPhone-Store-Screenshots (1320 × 2868) aus der echten App angesehen; Prototyp `shots.py` ohne Fehler, Pixel-Navigation angesehen.

**Ungetestet:** CarPlay-Screenshots: AppleScript scheitert mit Zeitüberschreitung (−1712), macOS will die Freigabe „Bedienungshilfen“ am Mac. Premium-Stimme nur, wenn auf dem Gerät geladen.

## GM-021 – Release vorbereitet: Store-Screenshots automatisch, Archiv/Upload, Startbildschirm

**Ziel:** App fertig für die Einreichung machen, soweit es ohne Mac geht; Screenshots und Archiv mit je einem Befehl.

**Dateien:** `App/ScreenshotMode.swift` (neu), `App/ContentView.swift`, `App/Assets.xcassets/LaunchBackground.colorset` (neu), `project.yml`, `tools/mac_build.sh`, `tools/mac_screens.sh` (neu), `tools/mac_archive.sh` (neu), `docs/VEROEFFENTLICHUNG.md`; vorher zusammengeführt: Cloud-GM-020 (Navigation/CarPlay in Swift, Datenschutz-Manifest, Store-Texte) mit lokalem GM-020 (Signieren)

**Geändert:**
- Screenshot-Modus: Start mit `-EZShot karte|suche|vorschau|navigation|einstellungen` stellt die App in diesen Zustand (Navigation als Demo-Fahrt Idstein → Römerberg Frankfurt). Ohne das Startargument keine Wirkung
- `bash tools/mac_screens.sh`: Simulator „iPhone 16+ Pro Max“ (1320 × 2868), Standort-Erlaubnis vorab, Standort Bahnhof Idstein, Deutsch, Statusleiste 9:41; Bilder kommen als base64 über die Build-Ausgabe zurück (Gate bleibt unverändert) → `docs/store/iphone-69/`
- `bash tools/mac_archive.sh` (Probe-Export) und `--upload` (Hochladen nur auf Ansage); prüft App-Icon, Datenschutz-Manifest und dass die CarPlay-Berechtigung nicht im Store-Build steckt
- Startbildschirm in `#1C1C1D` statt weißem Blitz

**Tatsächlich geprüft:** `bash -n` für alle drei Skripte; Auspacken der Bilder mit einem Test-PNG; Merge ohne Konflikte. Mac nicht erreichbar (Mullvad VPN blockiert Tailscale: „Local network sharing: block“).

**Ungetestet:** Alles auf dem Mac: Build mit Cloud-GM-020, Screenshot-Lauf, Archiv. Cloud-GM-020 (Navigation, CarPlay-Vorlagen, Sprachausgabe) ist noch nie kompiliert worden.

## GM-020 – Auf dem Weg in den App Store: iPhone-Navigation und CarPlay in Swift, Navi-Logik getestet, Pflichten für die Veröffentlichung

**Ziel:** Aus der Karten-App eine veröffentlichbare Navi-App machen (Version 1.0: Neon City, ganz Deutschland, iPhone + CarPlay).

**Dateien:** `Core/Sources/EzMapsCore/{NavigationSession,Formatting}.swift` (neu), `Core/Sources/EzMapsCore/{Route,PhotonClient,HTTPClient,ValhallaClient}.swift`, `Core/Tests/EzMapsCoreTests/NavigationTests.swift` (neu), `Core/Tests/EzMapsCoreTests/RoutingTests.swift`, `App/{AppConfig,AppModel,LocationService,SpeechService,SettingsScreen}.swift` (neu), `App/{ContentView,NeonMapView,CarPlaySceneDelegate}.swift`, `App/PrivacyInfo.xcprivacy` (neu), `App/en.lproj/Localizable.strings`, `App/MapStyles/style-neon-city.json` (neu erzeugt), `tools/maplibre/build_style.py`, `tools/prototype/js/app.js`, `project.yml`, `docs/{VEROEFFENTLICHUNG,APPSTORE_TEXTE}.md` (neu), `docs/legal/index.md` (neu), `docs/TODO_PROTOTYP_REVIEW.md`, `CLAUDE.md`

**Geändert:**
- Core `NavigationSession`: setzt GPS-Positionen auf die Route (Fenster um die aktuelle Stelle, nach Tunnel die ganze Route), ignoriert kleine Rücksprünge, Restweg/-zeit, Straße, Tempolimit, „danach“-Hinweis, Ankunft (25 m), Neuberechnung über `RerouteMonitor`; Ansagen mit Schwellen je Tempo (Stadt 400/150/30 m, Land 800/300/60, Autobahn 2000/800/120)
- Fehler gefunden und behoben (per Test): die „Jetzt …“-Ansage kam nie, weil eine schon gesprochene „nah“-Stufe die Suche beendete; ein Sprung nach vorn (> 400 m, z. B. nach Tunnel) galt als Abweichung
- Core `Formatting` (Entfernung, Minuten, Uhrzeit, Ansage-Entfernung), `Route.coordinate(at:)`/`heading(at:)`, `NavigationSession.setSpeedLimits`, `Place` speicherbar; User-Agent für die öffentlichen Dienste; Core baut und testet jetzt auch unter Linux (`FoundationNetworking`)
- App iPhone: Startkarte mit „Wohin?“, Suche (Photon, Zuletzt-Ziele), Routen-Vorschau (bis 3 Routen, Linien auf der Karte, Ausschnitt eingepasst), Navigation (Abbiegehinweis, danach-Hinweis, Tempolimit-Schild inkl. ∞, Ankunftszeit, Rest, Ende, Zentrieren, „Musik leiser“), Ankunft, Einstellungen (Ansagen, Ducking, Tempolimit, Autobahn/Maut meiden, Demo-Fahrt, Datenschutz, Lizenzen, Version, Sicherheitshinweis)
- Standort: nur „Beim Verwenden“; während der Navigation genauer und im Hintergrund (`CLBackgroundActivitySession`, blaue Anzeige)
- Ansagen: `AVSpeechSynthesizer` Deutsch, Audio `.voicePrompt` mit `.duckOthers` (oder unterbrechen), Sitzung danach freigeben
- Demo-Fahrt: fährt die Route automatisch ab (für Ausprobieren und die App-Prüfung)
- CarPlay: „Ziele“ (Suchen + Zuletzt), `CPSearchTemplate`, Routen-Vorschau mit `CPTrip`/`CPRouteChoice`, Navigation mit `CPNavigationSession` und `CPManeuver` (Abbiegekarte zeichnet iOS), Restzeit, Zoom-/Zentrieren-Knöpfe, Route und Tempolimit im Kartenfenster; Zustand gemeinsam mit dem iPhone
- Kartenhinweis jetzt „© OpenMapTiles · © OpenStreetMap-Mitwirkende“ (OpenFreeMap verlangt beide), auch in der Stil-JSON
- App Store: `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption = NO`, Version 1.0.0, Server-Adressen in `project.yml` umstellbar; Fahrplan `docs/VEROEFFENTLICHUNG.md`, Texte/Prüfer-Hinweise `docs/APPSTORE_TEXTE.md`, Vorlage Impressum + Datenschutz `docs/legal/index.md` (Platzhalter für persönliche Angaben)
- Prototyp: Ansage-Logik wie in Core (Schwellen je Tempo, engste Stufe, kein „auf“ ohne Straßenname)

**Tatsächlich geprüft:** `swift test` für Core unter Linux (Swift 6.0.3): **27 Tests, 0 Fehler** (davon 12 neu). Alle Swift-Dateien mit `swiftc -parse` ohne Syntaxfehler. Stil-JSON neu erzeugt (nur Attribution geändert). Prototyp-Ablauf (Suche → Route Frankfurt → Navigation → Tempolimit 50 → Falsch abbiegen) in Chromium ohne Fehler. Text-Längen der App-Store-Texte nachgezählt.

**Ungetestet:** **Die App (SwiftUI, MapLibre, CarPlay, CoreLocation, AVFoundation) ist nicht gebaut** – das geht nur auf dem Mac. MapLibre-Namen (`MLNShapeSource`, `MLNPolylineFeature`, `setVisibleCoordinateBounds`), CarPlay-Vorlagen und das Laden von `PrivacyInfo.xcprivacy` ins Paket dort prüfen. Nichts im Simulator oder Auto ausprobiert.

## GM-019 – Erster Mac-Build über das EzMaps-Gate: alles grün

**Ziel:** GM-017/GM-018 auf dem Mac bauen und testen.

**Dateien:** `CHANGELOG.md`, `docs/TODO_PROTOTYP_REVIEW.md` (kein Code geändert)

**Geändert:**
- Mac-Gate für EzMaps vom Nutzer eingerichtet (`~/bin/ezmaps-gate.sh`, eigener Schlüssel); `ssh mac-ezmaps ping` → „ok“, `ls` → „Nicht erlaubt“
- Aufgabenliste: Core-Bausteine als gebaut und getestet vermerkt

**Tatsächlich geprüft:** `bash tools/mac_run.sh` mit Commit `03937c1` auf dem Mac (2026-10-17 20:08): `xcodegen generate` ok, `xcodebuild` für den iOS-Simulator (unsigniert, mit MapLibre 6.31.0) **BUILD SUCCEEDED**, `swift test` **15 Tests, 0 Fehler** (MapStyle 3, Polyline 2, Valhalla 5, Photon 2, Neuberechnung 3).

**Ungetestet:** App nicht im Simulator gestartet (Gate kann nur bauen) – Karte, OSM-Hinweis und CarPlay-Fenster muss der Nutzer in Xcode/Simulator ansehen. `ValhallaClient`/`PhotonClient`/`RerouteMonitor` sind noch nicht an die Oberfläche angeschlossen und nur gegen Attrappen getestet, nicht gegen die echten Server.

## GM-018 – Mac-Build vorbereitet, Swift-Code vorgeprüft

**Ziel:** Alles so vorbereiten, dass nach der einmaligen Mac-Einrichtung ein einziger Befehl baut und testet.

**Dateien:** `tools/mac_run.sh` (neu), `docs/MAC_EINRICHTEN.md` (neu), `project.yml`, `Core/Sources/EzMapsCore/ValhallaClient.swift`, `CHANGELOG.md`

**Geändert:**
- `bash tools/mac_run.sh`: prüft den Zugang (`ping`), leert den Projektordner, schickt den letzten Commit per `git archive` (nur App/, Core/, project.yml, Build-Skript – keine Schrift, keine Geheimnisse, LF-Zeilenenden) und baut; `bash tools/mac_run.sh log` holt das Log
- `docs/MAC_EINRICHTEN.md`: Gate-Skript und `authorized_keys`-Zeile zum Einfügen auf dem Mac, Test-Befehle, Fehlertabelle
- MapLibre fest auf `6.31.0` (stabil; der Hauptzweig der Distribution zeigt schon auf 7.0-Vorabversionen)
- Vorbeugend nach `LESSONS_SWIFT.md`: gemischte Wörterbuch-/Array-Literale mit ausdrücklichem Typ; `speed_limit`-Text ohne mehrdeutige Typableitung

**Tatsächlich geprüft:**
- MapLibre-API-Namen in den Headern von `MapLibre.xcframework` 6.31.0 nachgesehen: `MLNMapView`, `initWithFrame:styleURL:`, `setCenterCoordinate:zoomLevel:animated:`, `logoView`, `attributionButtonPosition`, `MLNOrnamentPositionTopRight`, `isPitchEnabled` vorhanden
- Swift-Syntax aller 16 Dateien mit tree-sitter: keine Fehler (ersetzt keinen Build)
- `bash -n` für beide Skripte; `mac_run.sh` meldet fehlenden Zugang sauber; Archiv-Inhalt geprüft (keine privaten Dateien)

**Ungetestet:** Kein Swift-Build, kein `swift test` – Mac-Gate für EzMaps noch nicht eingerichtet. Erwartet: 15 Tests (3 MapStyle, 2 Polyline, 5 Valhalla, 2 Photon, 3 Neuberechnung).

## GM-017 – Swift: MapLibre-Karte „Neon City“, Valhalla, Photon, Neuberechnung (ungetestet)

**Ziel:** Erste echte Swift-Bausteine nach dem Prototyp: Karte mit MapLibre Native, Routing/Suche/Tempolimits in `Core/`, automatische Neuberechnung.

**Dateien:** `project.yml`, `App/NeonMapView.swift` (neu), `App/ContentView.swift`, `App/CarPlaySceneDelegate.swift`, `App/MapStyles/style-neon-city.json` (neu, erzeugt), `tools/maplibre/build_style.py` (neu), `Core/Sources/EzMapsCore/{Coordinate,Polyline,HTTPClient,Route,ValhallaClient,PhotonClient,RerouteMonitor}.swift` (neu), `Core/Tests/EzMapsCoreTests/RoutingTests.swift` (neu), `tools/mac_build.sh` (neu), `CLAUDE.md`, `.gitignore`, `docs/TODO_PROTOTYP_REVIEW.md`

**Geändert:**
- MapLibre Native per SPM (`maplibre-gl-native-distribution`, ab 6.0.0)
- Stil „Neon City“ als MapLibre-JSON, erzeugt aus `tools/prototype/js/map.js` (NEON-Farben, Straßenbreiten in Metern ×0,75×1,5, Mindestbreiten MIN_PX, Stadtblöcke 46 m); Quelle OpenFreeMap; keine Text-Ebenen (keine Glyphen nötig). Relief fehlt noch (OpenFreeMap liefert keine Höhendaten)
- iPhone: Vollbild-Karte, „© OpenStreetMap-Mitwirkende“ immer sichtbar; CarPlay: Kartenfenster mit derselben Karte, flach (kein Neigen), OSM-Hinweis
- Core: `ValhallaClient` (Route + Alternativen, Manöver wie im Prototyp, Neuberechnung mit Ausweich-Versuch, Tempolimits über `trace_attributes` inkl. „unlimited“), `PhotonClient` (Suche, deutsche Kategorien, Dubletten < 400 m), `Polyline` (Genauigkeit 5/6), `SpeedLimits.fill` (Spiegel von `fillLimits`), `RerouteMonitor` (> 30 m Abstand → neu berechnen, 8 s Sperrzeit)
- Netzwerk über Protokoll `HTTPClient`; Tests mit Attrappe, laufen ohne Internet
- `tools/mac_build.sh` für das neue Mac-Gate (Anleitung `App/MAC_ZUGANG_NEUE_APP.md`, liegt nur lokal – enthält Team-/Key-IDs, Repo ist öffentlich); eigener Schlüssel `~/.ssh/ezmaps_mac` auf dem PC erzeugt; `CLAUDE.md` mit neuem Build-Weg

**Tatsächlich geprüft:** Nur der Stil: `gl-style-validate` (MapLibre-Style-Spec) ohne Fehler, Darstellung mit MapLibre GL JS im Browser (Idstein, Frankfurt, Deutschland) angesehen – entspricht dem Prototyp.

**Ungetestet:** **Kein Swift-Code gebaut, `swift test` nicht gelaufen** – der Mac ist für EzMaps noch nicht eingerichtet (neuer Schlüssel wird abgewiesen, Gate fehlt). MapLibre-API-Namen (`MLNMapView`, `attributionButtonPosition`) und SPM-Version auf dem Mac prüfen.

## GM-016 – Deutschland-Funktionen im Prototyp geprüft und repariert (Chromium + WebKit)

**Ziel:** GM-015 (Kacheln, Suche, Routing, Tempolimits, Neuberechnung) in Chrome- und Safari-Engine prüfen und Fehler beheben.

**Dateien:** `tools/prototype/js/{app,phone,carplay,valhalla,tiles,tileworker}.js`, `tools/prototype/js/tilejob.js` (neu), `tools/prototype/check_germany.py` (neu), `.gitignore`, `docs/previews/*`

**Geändert:**
- Tempolimit zeigte „10“, wo OSM kein `maxspeed` hat (Ersatzwert kam aus der geschätzten Fahrgeschwindigkeit). Jetzt: Lücken mit dem letzten bekannten Limit füllen, sonst kein Schild statt einer falschen Zahl
- „Falsch abbiegen“ scheiterte kurz nach dem Start (Valhalla: „No path“, weil die gesperrte Kreuzung der einzige Weg war). Jetzt drei Versuche: Abbiegung sperren → „geradeaus weitergefahren“ → ohne Sperre
- Tacho war leer (Kommentar hatte im gleichen Commit-Block die Code-Zeile verschluckt) – behoben, iPhone und CarPlay
- Straßen ohne Namen hießen „STRASSE“ – jetzt kein Platzhalter mehr, auch nicht in „danach …“
- WebKit-Build ohne `OffscreenCanvas` im Worker: Deutschland-Kacheln und Detail-Kachel blieben leer. Neues gemeinsames Modul `tilejob.js`; fehlt `OffscreenCanvas`, zeichnet der Haupt-Thread
- `check_germany.py`: automatischer Ablauf (Zoom Deutschland ↔ Idstein, vier Stile in Frankfurt, Suche „Römerberg Frankfurt“, Route, Los, Tempolimit, Falsch abbiegen, CarPlay)

**Tatsächlich geprüft:** `check_germany.py` in Chromium und WebKit (Playwright, Windows): Kacheln laden beim Zoomen, alle vier Stile außerhalb Idsteins, 3 Routen nach Frankfurt (42/44/50 min), Tempolimit 50 auf iPhone und CarPlay, Neuberechnung liefert neue Route. Einzige Konsolenmeldung: der erwartete 400er des ersten Neuberechnungs-Versuchs. `shots.py` mit Pricedown ohne Fehler, Bilder angesehen.

**Ungetestet:** Echtes Safari auf macOS/iOS (nur WebKit-Engine unter Windows getestet). Öffentliche Server (OpenFreeMap, Valhalla FOSSGIS, Photon) können ausfallen oder drosseln.

## GM-015 – Ganz Deutschland: Karte lädt automatisch im Stil, Suche, Routing, echte Tempolimits, Neuberechnung

**Ziel:** Die Karte soll nicht mehr nur Idstein zeigen, sondern ganz Deutschland – automatisch im gewählten Stil. Dazu Suche, Routing und Tempolimits überall.

**Dateien:** `tools/prototype/js/{geo,mvt,vtscene,tiles,valhalla}.js` (neu), `tools/prototype/js/{app,map,phone,carplay,tileworker}.js`, `tools/prototype/{index.html,style.css}`, `docs/KARTENDATEN.md` (neu), `docs/TODO_PROTOTYP_REVIEW.md`

**Geändert:**
- Karte: Vektorkacheln von OpenFreeMap (OSM, OpenMapTiles-Schema, kostenlos) werden je nach Ausschnitt und Zoom nachgeladen, in 3 Hintergrund-Workern gelesen (eigener Protobuf-Leser) und mit denselben Stil-Funktionen gezeichnet – Neon, Wild West, Pixel Quest und Toy Town funktionieren überall. Zoomstufe und Schärfe passen sich an (von Straßendetail bis ganz Deutschland), grobe Kacheln füllen Lücken, bis feine da sind
- Idstein bleibt die genaue Karte (Relief, Nebel des Krieges) und läuft am Rand weich in die Kacheln über
- Straßen und Flüsse behalten aus der Ferne eine Mindestbreite; Rauszoomen bis ganz Deutschland, Maßstab bis 500 km; aus großer Höhe keine Ortssymbole
- Kartensymbole (Autohaus, Werkstatt, Tankstelle …) kommen außerhalb von Idstein aus den Kacheln
- Suche: lokale Treffer sofort, dazu Treffer aus ganz Deutschland über Photon (deutsche Bezeichnungen, Dubletten entfernt)
- Routing: in Idstein weiter das eigene Routing (Nebel des Krieges), sonst Valhalla (FOSSGIS) mit 2 Alternativen, deutschen Straßennamen, Kreisverkehr-Ausfahrten, Auf-/Ausfahrten; „Autobahn meiden“/„Maut meiden“ werden übergeben
- Tempolimit-Schild zeigt echte OSM-Werte (Valhalla `trace_attributes`), „∞“ auf Autobahnen ohne Limit; ohne Daten wie bisher geschätzt
- Neuberechnung: Knopf „Falsch abbiegen“ in der Leiste simuliert eine verpasste Abbiegung – Ansage „Route wird neu berechnet“, neue Route ab der aktuellen Position
- `docs/KARTENDATEN.md`: welche Kachel-, Routing- und Suchdienste für Prototyp und App in Frage kommen (openstreetmap.org-Kacheln sind für Apps nicht erlaubt)

**Tatsächlich geprüft:** Playwright (Chromium, über den Proxy) ohne Skriptfehler: Karte am Idstein-Rand, Frankfurt, Ruhrgebiet und ganz Deutschland (iPhone + CarPlay); Frankfurt in allen vier Stilen; Suche „Römerberg Frankfurt“ → Route (49 km, 3 Routen) → Navigation mit Tempolimit 50 aus OSM → „Falsch abbiegen“ → neue Route. Bilder angesehen.

**Ungetestet:** Swift nicht angepasst (App braucht MapLibre + eigene Dienste, siehe `docs/KARTENDATEN.md`). Nur Chromium. Öffentliche Server (OpenFreeMap, Photon, Valhalla FOSSGIS) nur für den Prototyp gedacht. Lange Routen: Tempolimits nur für die ersten 150 km. `docs/previews/` nicht neu erzeugt.

## GM-014 – Branch `claude/sharp-knuth-8k97wf` in `main` übernommen

**Ziel:** Review-Arbeit (Teil 0–2, GM-009 bis GM-013, inkl. Cloud-Einträge) nach `main` bringen; Pricedown ins Repo legen, falls das Repo privat ist.

**Dateien:** `CHANGELOG.md`, `docs/previews/*` (neu erzeugt)

**Geändert:**
- `main` per Fast-Forward auf den Branch-Stand gebracht (keine Konflikte, `main` war bereits im Branch enthalten); alle Einträge GM-009 bis GM-013 bleiben erhalten
- Schrift **nicht** committet: Das Repo `jonas-ell/ezmaps` ist laut GitHub öffentlich (`visibility: public`). Pricedown hat nur eine Desktop-Lizenz und darf nicht öffentlich verteilt werden. `tools/prototype/fonts/` bleibt in `.gitignore`, `CLAUDE.md` und `README.md` unverändert
- Geprüft: Pricedown war nie im Git-Verlauf

**Tatsächlich geprüft:** `python tools/prototype/shots.py` auf `main` ohne Konsolenfehler, 22 Bilder erzeugt und angesehen; Sichtbarkeit über die GitHub-API ohne Anmeldung abgefragt (`private: false`).

**Ungetestet:** Teil 3 der Aufgabenliste (Ideen) noch offen – soll erst im Prototyp gezeigt und vom Nutzer freigegeben werden.

## GM-013 – Review Teil 2: Verbesserungen

**Ziel:** Punkte 2.1–2.9 aus `docs/TODO_PROTOTYP_REVIEW.md`.

**Dateien:** `tools/prototype/js/{phone,carplay,app,route}.js`, `tools/prototype/style.css`, `docs/TODO_PROTOTYP_REVIEW.md`, `docs/previews/*`

**Geändert:**
- 2.1 Unten keine zweite Entfernung mehr, sondern der Schritt danach („danach links abbiegen · Bahnhofstraße“), iPhone und CarPlay
- 2.2 Nur noch ein Balken, beschriftet („17 % der Strecke“)
- 2.3 Kein Clip-Knopf während der Fahrt (§ 23 Abs. 1a StVO); „Clip teilen“ im Ankunfts-Blatt, Hinweis auf Siri
- 2.4 Routen-Vorschau: Fahrzeit-Schild an jeder Linie (gewählte farbig), Tipp auf eine Linie wählt sie, Karte wird über dem tatsächlichen Blatt eingepasst, Ziel-Symbol liegt am Routen-Ende. Nebenbei behoben: Die Bedienebene fing alle Klicks ab – Ziehen und Tippen auf der Karte gingen vorher nicht
- 2.5 Eine Knopf-Form pro Stil (Neon eckig, Wild West leicht rund, Pixel fast eckig, Toy Town rund)
- 2.6 Tab Stile als 2×2-Raster, alle vier Stile auf einen Blick
- 2.7 CarPlay: Straßenname überall in normaler Schreibweise; Einblendung unten links nicht bedienbar (`pointer-events: none`) und frei von Systemteilen
- 2.8 Suche ohne Eingabe: Kategorie-Knöpfe (Tanken, Parken, Essen, Supermarkt) und „Zuletzt gesucht“
- 2.9 Profil: Routen-Optionen (Autobahn meiden – wirkt im Routing, Maut meiden), Zuhause/Arbeit bearbeiten (über die Suche), Standard-Stil

**Tatsächlich geprüft:** `shots.py` ohne Konsolenfehler, Bilder angesehen; zusätzlich Kategorie „Essen“, Vorschau mit drei Routen und Schildern (CarPlay), Profil.

**Ungetestet:** „Autobahn meiden“ muss bei der Swift-Umsetzung in `Core/` gespiegelt werden. Prototyp nur in Chromium.

## GM-012 – Kartensymbole nach Vorlage (Autohaus, Werkstatt …) und Legende

**Ziel:** Orte wie Autohäuser, Werkstätten und Waschanlagen sollen auf der Neon-Karte als kleine Symbole wie in der Vorlage erscheinen.

**Dateien:** `tools/prototype/js/map.js`, `tools/prototype/js/phone.js`, `tools/prototype/js/app.js`, `tools/prototype/style.css`, `docs/TODO_PROTOTYP_REVIEW.md`

**Geändert:**
- Eigener Symbolsatz (selbst gezeichnet, 24er-Raster, Path2D): Glyphe mit dunkler Kontur, meist weiß, einzelne farbig – Autohaus (türkis), Werkstatt, Waschanlage, Motorrad, Fahrrad, Tankstelle, Parken (blau), Supermarkt, Apotheke (grün), Essen, Café, Bar (grün), Kleidung (schwarz mit weißer Kontur), Friseur, Hotel, Bank
- Neon nutzt diese Symbole statt der Codex-Blips; Quelle sind jetzt Kartenpunkte **und** Suchorte (dort stehen Autohäuser, Werkstätten, Apotheken), doppelte werden zusammengelegt; Auto-Themen haben Vorrang beim Platzieren
- Zusammengeführt mit GM-011 des lokalen Claude: dessen Legende (Ebenen-Knopf, Hervorheben per Tippen), Maßstab und Relief bleiben; die Legende zeigt jetzt die neuen Symbole und Kategorien (inkl. Krankenhaus, Polizei); Essen bleibt in der Übersicht ausgeblendet, außer es ist hervorgehoben

**Tatsächlich geprüft:** Nach dem Zusammenführen Playwright (Chromium) ohne Skriptfehler; Bildschirmfotos angesehen: iPhone-Karte bei den Autohäusern, Legende offen, „Autohaus“ hervorgehoben, CarPlay-Karte.

**Ungetestet:** Swift nicht angepasst. Wild West, Pixel Quest und Toy Town zeichnen weiter die alten Blips (Legende zeigt dort trotzdem die Neon-Symbole). `docs/previews/` nicht neu erzeugt (Pricedown fehlt in der Cloud).
## GM-011 – Review Teil 0 zusammengeführt: Relief, weiße Symbole, Legende

**Ziel:** Teil 0 parallel vom lokalen Claude und vom Cloud-Claude bearbeitet – zusammenführen. Look-Entscheidungen des Cloud-Claude (GM-010, nach neueren Vorlagebildern) gelten; dazu die Teile, die nur hier gebaut wurden.

**Dateien:** `tools/prototype/js/{map,app,phone,carplay}.js`, `tools/prototype/style.css`, `tools/prototype/hillshade.py` (neu), `tools/prototype/data/hillshade.png` (neu), `docs/ASSETS_CODEX.md`, `docs/TODO_PROTOTYP_REVIEW.md`, `docs/previews/*`

**Geändert:**
- Übernommen aus GM-010: Palette, Stadtblöcke, breite Straßen in der Textur, iPhone-Zoom 0,3, CarPlay-Radar-Zoom
- 0.3 Hügel-Schattierung aus freien Höhendaten (Terrain Tiles/AWS: SRTM, EU-DEM © Copernicus); `hillshade.py` erzeugt `data/hillshade.png`; Quelle im Profil; Texturrand läuft weich aus
- 0.5 Neon-Symbole einfarbig weiß mit dunkler Kontur (eigener Glyphen-Satz), Essen in der Übersicht ausgeblendet; Codex-Prompt „NeonMono“ ergänzt
- 0.6 Legende über den Ebenen-Knopf (iPhone), Tippen hebt Symbole hervor; CarPlay bewusst ohne Legende (wenig Ablenkung)
- 0.7 Maßstab: eine Umsetzung (lokal) statt zwei
- Vektorstraßen (`drawRoads`) bleiben im Code, sind aber aus – Entscheidung GM-010: Straßen breit und mitwachsend

**Tatsächlich geprüft:** `shots.py` nach dem Zusammenführen ohne Konsolenfehler, 22 Bilder neu erzeugt und angesehen (Karte, Vorschau, Navigation, Stile, CarPlay).

**Ungetestet:** Prototyp nur in Chromium. Swift-Karte (0.9) erst nach Freigabe des Looks.

## GM-010 – Neon City sieht aus wie die Vorlage (dunkle Stadtübersicht), Maßstab

**Ziel:** Die Neon-Karte an die Vorlagebilder des Nutzers angleichen: fast schwarzes Gelände, Stadt als dunkelgraue Blöcke, breite hellgraue Straßen, Maßstab unten links.

**Dateien:** `tools/prototype/js/map.js`, `tools/prototype/js/app.js`, `tools/prototype/js/phone.js`, `tools/prototype/js/carplay.js`, `tools/prototype/style.css`, `docs/TODO_PROTOTYP_REVIEW.md`

**Geändert:**
- `NEON`-Palette: Land `#1c1c1d`, Wald/Feld/Park fast schwarz, bebaute Fläche `#2c2c2d`, Gebäude `#373738` mit feiner Kante, Wasser grau `#4b4e4d`, Straßen `#b0b0b0`/`#a3a3a3`/`#8e8e8e` ohne Rand und 1,5× breiter; Hintergrund und Dunst passend dunkel
- Neu `urbanBlocks()`: Bebaute Fläche wird automatisch aus Gebäuden und Wohnstraßen erzeugt (OSM hat in Idstein kaum `landuse=residential`), freies Gelände bleibt dunkel
- iPhone-Stöbern startet weiter rausgezoomt (0,3 statt 0,42), gilt für alle Stile; CarPlay behält den Radar-Zoom aus GM-008
- Maßstab („0 ── 250 m“) unten links über dem Ortsteil-Kasten auf iPhone und CarPlay, passt sich beim Zoomen an
- Aufgabenliste: 0.1, 0.2 (geändert: Straßen bleiben in Metern, weil sie in der Vorlage mitwachsen), 0.4, 0.7 abgehakt

**Tatsächlich geprüft:** Playwright (Chromium) ohne Skriptfehler; Bildschirmfotos von Karte (iPhone + CarPlay), Routen-Vorschau und Navigation angesehen. Die Detail-Kachel in der Navigation nutzt die neue Palette.

**Ungetestet:** Swift nicht angepasst (erst nach Freigabe, Punkt 0.9). `docs/previews/` nicht neu erzeugt (in der Cloud fehlt die Pricedown-Schrift). Wild West, Pixel Quest und Toy Town nur durch den weiteren Zoom betroffen, nicht angesehen.


## GM-009 – Review Teil 1: Fehler behoben

**Ziel:** Punkte 1.1–1.7 aus `docs/TODO_PROTOTYP_REVIEW.md`.

**Dateien:** `tools/prototype/js/{phone,carplay,app,map}.js`, `tools/prototype/style.css`, `tools/prototype/prep.py`, `tools/prototype/data/idstein.json`, `docs/TODO_PROTOTYP_REVIEW.md`, `docs/previews/*`

**Geändert:**
- 1.1 „© OpenStreetMap-Mitwirkende“ zentral auf jedem iPhone-Screen (über Tab-Leiste, über der Tastatur, in Blättern), in jeder Stil-Karte („© OpenStreetMap“), in den CarPlay-Listen und über dem CarPlay-Ankunftshinweis
- 1.2 Ursache: Leisten und Panels sind halbdurchsichtig, Symbole schienen durch. Jetzt werden Kartensymbole unter allen Bedienelementen und der Statusleiste gar nicht gezeichnet; Tab-Leiste (Neon) deckend, Statusleiste mit Verlauf, Karte und Stil-Karten isoliert
- 1.3 Fahrzeit in der Routen-Vorschau in lesbarer Textschrift statt Titelschrift mit Kontur
- 1.4 Spieler-Pfeil auf dem iPhone höher (Kamera-Anker 0,63), nicht mehr unter dem Straßenfeld; CarPlay geprüft (frei)
- 1.5 „Abbrechen“ nicht mehr abgeschnitten; alle Suchkategorien deutsch (z. B. „Buchhandlung“, „Tierarzt“, „Waschanlage“), Unbekanntes heißt „Ort“
- 1.6 Bei Ankunft verschwinden Abbiegekarte, Tacho, Tempolimit, Musik-Hinweis und untere Leiste; Karte zeigt Übersicht der gefahrenen Strecke (iPhone und CarPlay)
- 1.7 Versionsanzeige im Profil liest die neueste GM-Nummer aus `CHANGELOG.md`

**Tatsächlich geprüft:** `shots.py` ohne Konsolenfehler; alle 22 Bilder angesehen (OSM-Hinweis überall, keine Symbole über Leisten, Fahrzeit lesbar, Pfeil frei, Ankunft ohne Navi-Teile).

**Ungetestet:** Prototyp nur in Chromium. Keine Swift-Änderungen.

## GM-008b – Aufgabenliste: Karten-Look „Neon City“ nach Vorlage

**Ziel:** Festhalten, warum die Neon-Karte nicht wie die Vorlage (dunkle Open-World-Stadtübersicht) aussieht und was der lokale Claude ändern soll.

**Dateien:** `docs/TODO_PROTOTYP_REVIEW.md`

**Geändert:**
- Neuer Teil 0 (vor den Fehlern): Vergleich heute ↔ Vorlage (Land, Gebäude, Straßenbreiten, Wasser, Relief, Zoom, Symbole) und die Aufgaben 0.1–0.9: neue Palette, Straßen in Bildschirm-Pixeln, Hügel-Schattierung, weiterer Zoom, weiße Symbole, Legende, Maßstab, Vergleichsbild, danach Swift.

**Tatsächlich geprüft:** Bildschirmfoto des Nutzers (CarPlay-Karte) mit dem Vorlagebild verglichen, die Neon-Farben in `tools/prototype/js/map.js` nachgeschlagen.

**Ungetestet:** Nichts am Code geändert, die Farbwerte in der Liste sind Schätzungen aus dem Vorlagebild.
_(Nummer parallel zu GM-008 vergeben, deshalb „b“.)_

## GM-008 – CarPlay-Karte flach von oben wie ein Spiel-Radar

**Ziel:** CarPlay-Ansicht nach Nutzervorlage: flach, Fahrtrichtung oben, große Symbole.

**Dateien:** `tools/prototype/js/carplay.js`, `tools/prototype/js/app.js`

**Geändert:**
- CarPlay-Navigation: keine 3D-Neigung mehr, 1,8 px/m, Pfeil leicht rechts der Mitte
- CarPlay-Karte (ohne Route): näher (1,1 px/m), Symbole deutlich größer

**Tatsächlich geprüft:** Bildschirmfotos CarPlay-Karte und -Navigation angesehen, keine Konsolenfehler.

**Ungetestet:** Prototyp nur in Chromium; `docs/previews` noch nicht neu erzeugt.

## GM-007 – Suche repariert, Steuerung per Pfeiltasten überall

**Ziel:** In die Suche tippen können; überall mit Pfeiltasten navigieren wie mit Knopf-/Pfeilsteuerung im Auto.

**Dateien:** `tools/prototype/js/keys.js` (neu), `tools/prototype/js/{app,phone,carplay,icons}.js`, `tools/prototype/{style.css,index.html}`, `docs/previews/*`

**Geändert:**
- Fehler: Ein Tipp auf die Bildschirm-Tastatur nahm dem Suchfeld den Fokus, danach kam von der echten Tastatur nichts mehr an. Jetzt bleibt der Cursor in der Suche immer im Feld
- Pfeiltasten springen räumlich zum nächsten Knopf/Listeneintrag (blaue Markierung, bei CarPlay weiß), Enter wählt, Esc geht zurück, Tab wechselt iPhone ↔ CarPlay, +/− zoomt; offene Dialoge/Blätter fangen den Fokus
- CarPlay: Kartentaste „Verschieben“ wie `CPMapTemplate.showPanningInterface` – vier Pfeilknöpfe, Pfeiltasten bewegen die Karte, „Fertig“/Esc beendet

**Tatsächlich geprüft:** Playwright: Einstieg, Stilwahl, Suche (Tippen + Bildschirmtasten gemischt), Auswahl per Pfeil/Enter, Zurück per Esc, CarPlay-Ziele per Tastatur bis zur Routen-Vorschau, Verschieben per Pfeiltasten; keine Konsolenfehler.

**Ungetestet:** In der echten App kommt die Fokus-Steuerung im Auto von iOS (Focus Engine) – hier nur nachgebildet. Prototyp nur in Chromium.
## GM-007b – Aufgabenliste aus dem Prototyp-Review

**Ziel:** Gefundene Fehler, Verbesserungen und Ideen zum Prototyp als Aufgabenliste für den lokalen Claude festhalten.

**Dateien:** `docs/TODO_PROTOTYP_REVIEW.md` (neu)

**Geändert:**
- Neue Aufgabenliste in drei Teilen: Fehler (u. a. OSM-Hinweis fehlt in Entdecken/Stile, Symbole über der Oberfläche, unlesbare Fahrzeit, verdeckter Spieler-Pfeil), Verbesserungen, Ideen. Am Ende steht, was auf dem Gerät zu testen ist.

**Tatsächlich geprüft:** Die 22 Bildschirmfotos aus `docs/previews/` (Stand GM-006) angesehen, die genannten Code-Stellen nachgeschlagen.

**Ungetestet:** Nichts am Code geändert. Die vermutete Ursache für die Symbole über der Oberfläche (3D-Kamera per CSS) ist nicht bestätigt.
_(Nummer parallel zu GM-007 vergeben, deshalb „b“.)_


## GM-006 – Codex-Assets und App-Icon eingebaut, Navi-Zoom wie Apple Maps

**Ziel:** Echte Assets statt Platzhalter im Prototyp, App-Icon in der App, deutlich näherer Zoom während der Fahrt.

**Dateien:** `App/Assets.xcassets/*` (neu), `project.yml`, `tools/prototype/js/assets.js` (neu), `tools/prototype/js/tileworker.js` (neu), `tools/prototype/js/{icons,map,app,phone,carplay}.js`, `tools/prototype/{index.html,style.css,serve.py,shots.py}`, `README.md`, `docs/previews/*`, `Assets/Generated/**` (von Codex, seit GM-005 im Repo)

**Geändert:**
- App: Asset-Katalog mit `AppIcon` (Standard, Dark, Tinted, je 1024 × 1024), `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
- Prototyp nutzt Codex-Assets: UI-Icons je Stil (Neon/Western/Pixel), Abbiege-Pfeile je Stil, CarPlay-Vorlagenbilder für Systemknöpfe, Kartensymbole, Ziel- und Freunde-Symbole, Spieler (Neon/Western), Abzeichen, App-Icon (Start + CarPlay-Dock). Toy Town nutzt vorerst Neon-Icons; Pixel-Spieler bleibt der Pfeil nach Nutzervorlage (Codex lieferte noch das Auto)
- Navigation: Kamera nah und steil wie Apple Maps (iPhone 3,4 px/m, 58°; CarPlay 4,6 px/m, 60°, Pfeil unten); Route, Symbole, Spieler wachsen mit
- Scharfe Detail-Kachel (900 × 900 m, 4 px/m) wird während der Fahrt in einem Web Worker gezeichnet (keine Ruckler), grobe Karte bleibt für die Ferne
- Server liefert jetzt die Repo-Wurzel aus (Assets erreichbar); Adresse `http://localhost:8765/tools/prototype/`

**Tatsächlich geprüft:** Playwright-Durchlauf ohne Konsolenfehler, 22 Bildschirmfotos angesehen (Assets sichtbar, Detail-Kachel scharf in Neon, Wild West, Toy Town).

**Ungetestet:** Swift-Build mit dem neuen Asset-Katalog (Dark/Tinted-Varianten brauchen Xcode 16). Prototyp nur in Chromium.

## GM-005 – Klickbarer Prototyp (iPhone + CarPlay), Stil „Toy Town“, Swift-Lektionen

**Ziel:** Die ganze App mit CarPlay im Browser 1:1 durchklicken, bevor auf dem Mac gebaut wird.

**Dateien:** `tools/prototype/*` (neu: `index.html`, `style.css`, `js/app.js`, `js/map.js`, `js/route.js`, `js/phone.js`, `js/carplay.js`, `js/icons.js`, `prep.py`, `serve.py`, `shots.py`, `data/idstein.json`), `docs/previews/*` (neu erzeugt), `docs/LESSONS_SWIFT.md`, `CLAUDE.md`, `README.md`, `docs/ASSETS_CODEX.md`, `Core/Sources/EzMapsCore/MapStyle.swift`, `App/en.lproj/Localizable.strings`, `.gitignore`; entfernt: `tools/preview/` (alter Standbild-Renderer) und alle alten Vorschau-PNGs

**Geändert:**
- Prototyp: iPhone 16 (393 × 852 pt) und CarPlay (800×480 / 1280×480 / 960×540 umschaltbar) mit gemeinsamem Zustand
- iPhone: Start → Standort-Dialog → Stilwahl → Karte (ziehen/zoomen) → Suche mit QWERTZ-Tastatur (323 echte Orte + Straßen) → Routen-Vorschau (Schnellste/Kürzeste/Neues entdecken) → Navigation mit simulierter Fahrt, Sprachansagen, „Musik leiser“-Anzeige → Ankunft; Tabs Entdecken (Nebel des Krieges je Ortsteil), Stile (Live-Vorschau mit Pfeil und Route), Profil (Datenschutz-Schalter); Freunde nur nach Zustimmung
- CarPlay: Kartenvorlage mit Leiste und Tasten, Zielliste, Kategorien, Stil-Liste, Routen-Vorschau, Navigation (Systemkarte + eigene Einblendung), Ankunfts-Hinweis
- Routing im Browser (Dijkstra, Abbiegungen, Ankunftszeit); Start nie auf Zufahrten
- Neuer Stil **Toy Town** (Spielteppich): Asphalt mit Mittellinie, Zebrastreifen, Comic-Häuser schräg mit Fenstern, Tupfen-Bäume, Spielzeugauto; `MapStyle.toyTown`
- Pixel Quest: Spieler ist jetzt der Pixel-Pfeil nach Vorlage des Nutzers
- Swift-Lektionen aus Mimic Sounds als `docs/LESSONS_SWIFT.md`, Arbeitsregeln in `CLAUDE.md`

**Tatsächlich geprüft:** Automatischer Durchlauf mit Playwright (alle Screens, Stilwechsel, Fahrt bis Ankunft, CarPlay-Ziele und -Vorschau) ohne Konsolenfehler; 22 Bildschirmfotos angesehen.

**Ungetestet:** Swift-Code nicht gebaut (neuer Fall `toyTown` – einziger `switch` in `MapStyle.swift` nachgezogen). Prototyp nur in Chromium getestet, nicht in Safari.

## GM-004 – Drei Stile, iPhone-Entwürfe in 1:1, Icon-Prompts

**Ziel:** Stil-Vorschauen mit Navigationspfeil und Route, iPhone-Entwürfe in echten Maßen, Wild West mit roten Akzenten, neuer Pixel-Stil.

**Dateien:** `tools/preview/render.html`, `tools/preview/ui.html`, `tools/preview/shoot_ui.py`, `tools/preview/shotlib.py`, `docs/previews/*`, `docs/ASSETS_CODEX.md`, `Core/Sources/EzMapsCore/MapStyle.swift`, `App/en.lproj/Localizable.strings`

**Geändert:**
- Renderer mit drei Stilen: Neon City (grau/lila), Wild West (Papierkarte, Tinten-Bäume, rote Route, rotes X als Ziel), Pixel Quest (Retro-Rollenspiel-Oberwelt: Pixel-Häuser je eigene Dachfarbe, Bäume, Wasser mit Sandufer, goldene Fußspuren-Route, Pixel-Auto, Schatztruhe als Ziel)
- `MapStyle.pixel8Bit` → `MapStyle.pixelQuest` (`pixel-quest`)
- UI-Entwürfe in iPhone-16-Maßen (393 × 852 pt @3x): Dynamic Island, Statusleiste, Home-Indikator, Safe Areas, Tab-Leiste 83 pt, Geräterahmen in den Übersichten
- Stil-Auswahl zeigt Navigationsansicht mit Pfeil und Route je Stil; Navigation und Routen-Vorschau in allen drei Stilen; CarPlay-Navigation in allen drei Stilen
- Codex-Prompts für alle UI-Icons, Abbiege-Pfeile, Blips, Spieler, CarPlay-Vorlagen, Abzeichen – je Stil

**Tatsächlich geprüft:** Alle Bilder auf Windows gerendert und angesehen.

**Ungetestet:** Swift-Code nicht gebaut (Umbenennung `pixelQuest` betrifft nur `MapStyle` und Strings). Systemschrift in den Entwürfen ist Inter statt SF Pro.

## GM-003 – Spiel-Look nach Vorlage, Pricedown, UI-Entwürfe iPhone + CarPlay

**Ziel:** Karte an die Vorlage-Screenshots anpassen (graue Open-World-Karte, lila GPS-Linie) und die App-Oberfläche zeigen.

**Dateien:** `project.yml`, `tools/preview/render.html`, `tools/preview/prep.py`, `tools/preview/ui.html`, `tools/preview/shoot_ui.py`, `docs/previews/*`, `docs/ASSETS_CODEX.md`, `.gitignore`

**Geändert:**
- Bundle-ID jetzt `com.game.ezmaps`
- Kartenstil: Grautöne mit Relief-Textur, Straßen ohne Leuchten, flache lila Route mit dunkler Kante, freistehende Blips, Straßenname-Box, „↑ Distanz“ mit grünem (Fortschritt) und gelbem (Restzeit) Balken
- Pricedown als Überschrift-Schrift (nur lokal, nicht im Repo – App-Lizenz nötig)
- Renderer-Optionen: `hud=none`, `route=0`, `fog=1` (Nebel des Krieges), freie Kamera (`w,h,scale,tilt,cx,cy`)
- UI-Entwürfe: iPhone (Start, Suche, Routen-Vorschau, Navigation, Entdecken, Stile), CarPlay (Karte, Ziel-Liste, Routen-Vorschau, Navigation)

**Tatsächlich geprüft:** Alle Bilder auf Windows gerendert und angesehen.

**Ungetestet:** Swift-Code weiterhin nicht gebaut. CarPlay-Systemteile in den Entwürfen sind nur nachgezeichnet – das echte Aussehen bestimmt iOS.

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
