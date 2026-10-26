# Changelog

Neue Einträge oben. Nummernreihe: `GM-xxx`.

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
