# Veröffentlichung im App Store – Fahrplan (Stand GM-020)

Ziel **Version 1.0**: Navigation mit der Karte „Neon City“ für ganz Deutschland, iPhone + CarPlay, Deutsch.
Nicht in 1.0: weitere Kartenstile, Nebel des Krieges / Entdecken, Freunde, In-App-Käufe (kommt mit 1.1+).

Legende: **[N]** = nur der Nutzer kann das (Konto, Unterschrift, persönliche Daten) · **[C]** = Claude (Code/Doku) · **[M]** = Mac-Build/Gerät

## 1. Blocker – ohne das keine Veröffentlichung

| # | Aufgabe | Wer | Stand |
|---|---|---|---|
| 1.1 | Apple Developer Program (99 €/Jahr) aktiv, Team-ID bekannt | N | prüfen |
| 1.2 | **CarPlay-Navigation beantragen**: developer.apple.com/contact/carplay → „Navigation“. Antwort dauert oft Wochen. Ohne Freigabe: in `App/EzMaps.entitlements` den Eintrag `com.apple.developer.carplay-maps` für den Store-Build entfernen und erst iPhone-only veröffentlichen | N | offen |
| 1.3 | **Bundle-ID festlegen** – nach dem ersten Upload nicht mehr änderbar. Jetzt `com.game.ezmaps` (Domain „game“ gehört uns nicht). Empfehlung: eigene umgekehrte Domain, z. B. `de.<nachname>.ezmaps`; in `project.yml` (`bundleIdPrefix`, `PRODUCT_BUNDLE_IDENTIFIER`) ändern | N entscheidet, C ändert | offen |
| 1.4 | App-Eintrag in App Store Connect anlegen (Name „EzMaps: Game Maps“ muss frei sein) | N | offen |
| 1.5 | **Impressum + Datenschutzerklärung**: Platzhalter in `docs/legal/index.md` ausfüllen (Name, Anschrift, E-Mail), rechtlich prüfen lassen; GitHub → Settings → Pages → Branch `main`, Ordner `/docs` einschalten | N | Vorlage da (GM-020) |
| 1.6 | Signieren: Zertifikat + Provisioning-Profil (automatisch in Xcode), Archiv bauen, über Xcode/Transporter hochladen | N + M | offen |
| 1.7 | Erster Simulator- und Gerätetest des iPhone-Ablaufs (GM-020 ist nur syntaktisch geprüft) | M | offen |

## 2. Server – die öffentlichen Dienste sind nur begrenzt nutzbar

| Dienst | Regeln (Stand Okt. 2026) | Für 1.0 |
|---|---|---|
| Kacheln: OpenFreeMap | kommerziell erlaubt, keine Grenzen für Anzeige; Hinweis OpenMapTiles + OpenStreetMap Pflicht; eindeutiger User-Agent bei Offline-Downloads | ok (Hinweis ist eingebaut, GM-020) |
| Suche: Photon (komoot) | „fair“ nutzen, starke Nutzung wird gedrosselt, keine Verfügbarkeitszusage | ok für den Start mit wenigen Nutzern; eigener Photon-Server ab ~1000 Nutzern |
| Routing: Valhalla FOSSGIS | Demo-Server mit Fair-Use und Ratenbegrenzung (Bedingungen bei fossgis.de) | **Risiko**: vor größerer Werbung eigenen Valhalla-Server (Deutschland-Daten, ~20–40 €/Monat) |

Umstellen ohne Codeänderung: `EZValhallaURL`, `EZPhotonURL` in `project.yml`. Die App schickt einen eindeutigen User-Agent
(`EzMaps/<Version> (iOS; github.com/jonas-ell/ezmaps)`).

## 3. Pflichten im Code (erledigt in GM-020, auf dem Mac prüfen)

- [x] `App/PrivacyInfo.xcprivacy` – kein Tracking; Standort + Suchverlauf für App-Funktion, nicht verknüpft; UserDefaults CA92.1 *(prüfen: liegt im gebauten App-Paket?)*
- [x] `ITSAppUsesNonExemptEncryption = NO`
- [x] Nur „Beim Verwenden“-Standort; Hintergrund nur während der Navigation (blaue Statusleisten-Anzeige)
- [x] Hinweis „© OpenMapTiles · © OpenStreetMap-Mitwirkende“ auf jedem Kartenbildschirm (iPhone + CarPlay), Lizenz-Link in den Einstellungen
- [x] Keine Blitzer, keine Spielnamen; Pricedown wird in der App **nicht** benutzt (nur Systemschrift)
- [x] Sicherheits-Hinweis in den Einstellungen; keine Bedienelemente, die während der Fahrt Tippen verlangen (außer Ende/Zentrieren)
- [x] Demo-Fahrt für die App-Prüfung (Einstellungen → Demo-Fahrt)
- [x] Englische Texte für alle Bedienelemente (Ansagen in 1.0 nur Deutsch)
- [ ] App-Icon in allen Varianten im Archiv (Asset-Katalog ist da – im Archiv prüfen)
- [x] Startbildschirm in Neon-Grundfarbe `#1C1C1D` (GM-021, Farbe `LaunchBackground`) – im Simulator ansehen

## 4. App Store Connect ausfüllen

Texte, Schlüsselwörter, Prüfer-Hinweise und Datenschutz-Antworten: **`docs/APPSTORE_TEXTE.md`**.

Screenshots (Pflicht): iPhone 6,9" (1320 × 2868) – 3 bis 10 Bilder aus dem Simulator „iPhone 16 Pro Max“:
Karte, Suche, Routen-Vorschau, Navigation mit Tempolimit, Einstellungen. CarPlay-Screenshots sind nicht Pflicht.

**Automatisch (GM-021):** `bash tools/mac_screens.sh` baut im Simulator, startet die App mit `-EZShot karte|suche|vorschau|navigation|einstellungen`
(Standort Bahnhof Idstein, Deutsch, Statusleiste 9:41) und legt die Bilder unter `docs/store/iphone-69/` ab – echte App, keine Montage (Regel 2.3.4).

## 4b. Archiv und Upload (vorbereitet in GM-021)

- `bash tools/mac_archive.sh` – Archiv bauen und signiert exportieren (Probe, **lädt nicht hoch**). Prüft dabei: App-Icon und `PrivacyInfo` im Paket, keine CarPlay-Berechtigung im Store-Build.
- `bash tools/mac_archive.sh --upload` – hochladen zu App Store Connect. **Nur auf ausdrückliche Ansage des Nutzers**, erst nach 1.3 (Bundle-ID) und 1.4 (App angelegt). Vor jedem Upload `CURRENT_PROJECT_VERSION` in `project.yml` erhöhen.

## 5. Ablauf bis zum Start

1. [M] Mac-Build GM-020, Fehler beheben, im Simulator durchklicken (Demo-Fahrt, CarPlay-Fenster)
2. [N] 1.2 beantragen, 1.3 entscheiden, 1.5 ausfüllen
3. [M] Auf eigenem iPhone im Auto testen (TestFlight intern)
4. [N] TestFlight extern (ein paar Freunde, 1–2 Wochen)
5. [N] Zur Prüfung einreichen – mit den Review Notes aus `docs/APPSTORE_TEXTE.md`
6. [C] Nach Freigabe: Version 1.1 (Wild West, Entdecken/Nebel, eigener Server)
