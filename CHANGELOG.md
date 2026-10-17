# Changelog

Neue Einträge oben. Nummernreihe: `GM-xxx`.

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
