# Changelog

Neue Einträge oben. Nummernreihe: `GM-xxx`.

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
