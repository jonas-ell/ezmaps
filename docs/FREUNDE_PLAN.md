# Plan: Freunde auf der Karte („Crew“)

Stand GM-046. Entscheidung des Nutzers: iCloud (CloudKit), Live-Gefühl über Weiterrechnen. Ein eigener Echtzeit-Server ist nur eine spätere Option (Abschnitt 9).
Gebaut wird **nach dem CarPlay-Antrag**, als erstes großes Update (1.1).

## 1. Was der Nutzer am Ende kann

1. **Crew gründen:** Name eingeben („Wochenend-Crew“), fertig. Kein Konto, kein Passwort.
2. **Einladen:** Link teilen (WhatsApp, iMessage, AirDrop). Wer EzMaps hat und den Link antippt, ist in der Crew. Höchstens 8 Leute pro Crew.
3. **Live teilen:** Ein Schalter auf der Karte. Er ist immer aus, bis man ihn einschaltet. Er geht von selbst aus am Ende der Navigation, nach 15 Minuten ohne Bewegung und spätestens nach 4 Stunden.
4. **Freunde sehen:** Freunde, die gerade teilen, fahren als farbige Symbole mit Namen über die Karte, flüssig, auch in CarPlay. Tippen öffnet „Route zu Max“.
5. **Ohne Live-Standort:** In der Crew-Liste sieht man den Fortschritt („Max hat Idstein zu 60 % entdeckt“), auch wenn niemand live teilt.
6. **Raus:** Crew verlassen, Mitglied entfernen (nur Gründer), Crew auflösen. Danach ist die eigene Position sofort gelöscht.

## 2. Schutz vor Missbrauch und Datenschutz (zuerst festgelegt, gilt für alles)

- Teilen ist **immer freiwillig und sichtbar**: Solange man teilt, steht oben ein lila Band „Du teilst live mit Wochenend-Crew · Aus“. Auch in CarPlay ist es als kleines Symbol zu sehen.
- **Keine Verlaufsdaten:** Pro Person gibt es genau einen Positions-Eintrag, der überschrieben wird. Beim Ausschalten wird er gelöscht. Es entsteht keine Spur.
- Positionen liegen nur in der iCloud der Crew. **Wir als Entwickler können sie nicht lesen**: Sie liegen in privaten bzw. geteilten Datenbanken, nicht in der öffentlichen.
- Kein Teilen im Hintergrund, außer während einer Fahrt, für die der Standort ohnehin läuft.
- Datenschutzerklärung (`docs/legal/index.md`), App-Store-Datenschutzangaben und `PrivacyInfo.xcprivacy` werden vor der Veröffentlichung ergänzt (Phase 7).

## 3. Technik im Überblick

```
iPhone A (Gründer)                       iCloud (Container iCloud.<Bundle-ID>)             iPhone B (eingeladen)
  privat: Zone „Crew-<id>“  ── CKShare ──►  geteilt mit B (Lesen + Schreiben)  ◄──  geteilte Datenbank
    Member A, Member B                                                               schreibt Position B
    Position A, Position B                                                           liest alle 3 s Änderungen
```

- **Eine Crew = eine eigene Zone** in der privaten Datenbank des Gründers, als Ganzes geteilt (Zonen-Freigabe, ab iOS 15).
- Eingeladene greifen über ihre **geteilte Datenbank** zu und dürfen schreiben (Berechtigung „readWrite“).
- **Abholen:** Während man die Karte offen hat oder fährt, fragt die App alle 3 Sekunden „was ist neu seit dem letzten Mal“ (`CKFetchRecordZoneChangesOperation` mit Änderungsmarke). Das liefert nur geänderte Einträge, also wenig Daten.
- **Senden:** Die eigene Position geht höchstens alle 3 Sekunden raus, und nur, wenn man sich mehr als 15 m bewegt oder die Richtung um mehr als 20° geändert hat. Im Stand höchstens alle 60 Sekunden ein „noch da“.
- **Weiterrechnen:** Zwischen zwei Updates fährt das Symbol mit Tempo und Richtung weiter und gleitet sanft auf jede neue echte Position (Abschnitt 5).
- Stille Benachrichtigungen von iCloud nur als Zusatz, um nach dem App-Start schnell den aktuellen Stand zu haben. Nicht für die Live-Anzeige.

### Datensätze

| Typ | Felder | Hinweis |
|---|---|---|
| `Crew` | `name`, `createdAt` | einer pro Zone |
| `Member` | `userRef`, `displayName`, `color` (eine von 8), `emoji`, `joinedAt`, `explorePercent`, `exploreArea` | einer pro Person, Fortschritt für Abschnitt 1.5 |
| `Position` | `memberRef`, `lat`, `lon`, `heading`, `speed`, `accuracy`, `sentAt`, `sharingUntil` | einer pro Person, wird überschrieben, beim Ausschalten gelöscht |

Koordinaten werden auf 5 Nachkommastellen (ca. 1 m) gerundet.

## 4. Abhängigkeiten vor dem Start (Phase 0)

1. **[Nutzer] Bundle-ID festlegen** (`docs/VEROEFFENTLICHUNG.md` 1.3). Der iCloud-Container heißt danach `iCloud.<Bundle-ID>` und **kann nie wieder gelöscht oder umbenannt werden**. Deshalb zuerst die Bundle-ID, dann der Container.
2. **[Claude] iCloud im Projekt einschalten:** Berechtigungen `com.apple.developer.icloud-services = CloudKit` und `com.apple.developer.icloud-container-identifiers`, `CKSharingSupported = YES` in der Info.plist. Das automatische Signieren auf dem Mac legt Container und Profil an (`-allowProvisioningUpdates`). Klappt das nicht, legt der Nutzer den Container einmal im Entwicklerkonto an.
3. **[Nutzer] Zweites iPhone mit anderer Apple-ID** für den echten Test (Freund, Familie). Der Simulator kann CloudKit-Freigaben zwischen zwei Personen nicht vernünftig testen.

## 5. Weiterrechnen (Kern des Live-Gefühls)

In `Core/` (getestet, Mirror in `tools/prototype/js/friends.js`):

- `FriendTrack` hält die letzte echte Position (Ort, Richtung, Tempo, Zeit).
- `predicted(at: t)`: von der letzten Position mit Tempo und Richtung geradeaus weiter, **höchstens 6 Sekunden** (danach bleibt das Symbol stehen statt ins Feld zu fahren). Unter 3 km/h kein Weiterrechnen.
- Kommt eine neue echte Position, springt das Symbol nicht: Über 0,8 Sekunden wird vom gezeigten Ort zum neuen Weg übergeblendet. Die Richtung dreht über den kürzeren Winkel.
- Ist eine Position älter als 60 Sekunden, wird das Symbol grau („vor 2 Min“). Nach 10 Minuten oder nach `sharingUntil` verschwindet es.
- Optional später: auf die nächste Straße einrasten (Route bzw. Kartenlinien). In Phase 1 bewusst noch nicht.

Tests (Core): geradeaus fahren, Kurve, Stillstand, Sprung nach Funkloch, Uhrzeit-Versatz zwischen Geräten (`sentAt` aus der Zukunft wird auf „jetzt“ gekappt), Grau- und Ausblend-Grenzen, Sende-Drossel (15 m / 20° / 3 s / 60 s).

## 6. Ablauf in Phasen

Jede Phase endet mit Changelog-Eintrag, Commit, Push, Mac-Prüflauf (`bash tools/mac_check.sh`) und Screenshots.

### Phase 1 – Prototyp (Design zuerst, wie im Projekt vereinbart)
- `tools/prototype/`: Crew-Bildschirm (gründen, einladen, Mitglieder, verlassen), Schalter „Live teilen“ mit lila Band, Freunde-Symbole mit Namen, die mit dem Weiterrechnen flüssig fahren (zwei simulierte Freunde mit 3 s Takt und zufälligem Funkloch), CarPlay-Ansicht mit Freunden.
- Freunde-Symbol nach Codex-Auftrag (`docs/ASSETS_CODEX.md`, neuer Abschnitt 10: Kreis in Crew-Farbe, weißer Rand, Initiale oder Emoji, kleiner Richtungs-Keil).
- Bilder an den Nutzer, Freigabe abwarten.

### Phase 2 – Kernlogik in `Core/`
- `Friends.swift`: `CrewMember`, `FriendPosition`, `FriendTrack` (Weiterrechnen), `SendThrottle`, `SharingSession` (Ablauf und Auto-Aus: Navi-Ende, 15 min Stillstand, 4 h).
- Tests `FriendsTests.swift`. Läuft auch in der Cloud (`cd Core && swift test`).

### Phase 3 – iCloud-Anbindung
- `App/FriendsService.swift` hinter einem Protokoll `FriendsBackend`, damit es zwei Umsetzungen gibt:
  - `CloudKitFriendsBackend` (echt): Crew-Zone anlegen, `CKShare` erzeugen, Freigabe annehmen, Position schreiben/löschen, Änderungen abholen, Fehler behandeln (kein iCloud-Konto, Netz weg, `requestRateLimited` → Takt verdoppeln, `zoneNotFound` → Crew wurde aufgelöst).
  - `DemoFriendsBackend` (für Screenshots und Simulator): zwei erfundene Freunde, die durch Idstein fahren.
- **Einladung annehmen:** Das Antippen des Links landet in `windowScene(_:userDidAcceptCloudKitShareWith:)`. Dafür bekommt die iPhone-Szene einen kleinen Szenen-Delegaten (`UIApplicationDelegateAdaptor` + Szenen-Konfiguration). Die CarPlay-Szene bleibt unverändert.
- Takt nur, wenn nötig: Abholen alle 3 s, solange Karte sichtbar oder Fahrt läuft und mindestens ein anderer teilt, sonst alle 60 s. Im Hintergrund ohne Fahrt gar nicht.

### Phase 4 – Bildschirme iPhone
- Startkarte: Knopf „Crew“ (HUD-Symbol von Codex) → Crew-Blatt: Liste der Crews, Mitglieder mit Farbe, „teilt gerade“ oder „zuletzt vor …“, Fortschritt, Einladen (`ShareLink`), Verlassen/Auflösen.
- Schalter „Live teilen“ auf der Karte und in der Navigation, lila Band oben, Auswahl der Crew, wenn es mehrere gibt.
- Ohne iCloud-Konto: klare Meldung „Für die Crew brauchst du iCloud. Einstellungen → [Name] → iCloud“.
- Deutsch und Englisch (`en.lproj`), keine Gedankenstriche in sichtbaren Texten.

### Phase 5 – Karte und CarPlay
- `RouteOverlay`: eigene Quelle `ez-friends` mit Symbol-Ebene (Farbkreis, Name darunter in Barlow Condensed, Richtungs-Keil), 30-mal pro Sekunde aus dem Weiterrechnen aktualisiert. Nur die Quelle wird neu gesetzt, nicht die Ebene. Bei vielen Freunden Takt auf 15/s.
- Grau und kleiner bei alten Positionen, nie über dem eigenen Pfeil.
- CarPlay: dieselbe Ebene im Kartenfenster. Unter „Ziele“ ein Eintrag „Crew“ (`CPListTemplate`): Freunde mit Entfernung, Antippen → Routen-Vorschau zum Freund (aktuelle Position als Ziel). Keine Texteingabe, keine Bilder außer dem Symbol (CarPlay-Regeln).
- Kein Ton, keine Einblendung, wenn ein Freund losfährt (Ablenkung).

### Phase 6 – Prüfen
- **Automatisch (Mac):** Core-Tests, Build, Screenshots mit `DemoFriendsBackend`: Startkarte mit zwei Freunden, Crew-Blatt, Einladen, Band „Du teilst live“, Navigation mit Freund, CarPlay frei mit Freunden, CarPlay-Liste „Crew“. Neue Zustände in `ScreenshotMode` und `mac_build.sh`.
- **Fahrt-Simulation:** `tools/mac_drive.sh` mit zwei Demo-Freunden, Video ansehen: fahren die Symbole flüssig, keine Sprünge?
- **Echt (Nutzer + zweites iPhone):** Crew gründen, Link per WhatsApp schicken, annehmen, beide teilen, eine Runde fahren. Prüfen: Verzögerung (Ziel: Symbol höchstens 5 s hinter der echten Position, sichtbar flüssig), Akku pro Stunde Teilen, Auto-Aus nach Navi-Ende, Verlassen löscht Position, Funkloch (Flugmodus 30 s).
- **CloudKit-Konsole:** Schema von „Development“ nach „Production“ übertragen, bevor ein TestFlight- oder Store-Build hinausgeht. Sonst funktioniert es nur in Xcode-Builds. **[Nutzer]**, einmalig, Anleitung kommt mit.

### Phase 7 – Veröffentlichung
- Datenschutzerklärung: Abschnitt Crew (welche Daten, nur bei Apple iCloud, keine Speicherung durch uns, Löschung).
- App-Store-Datenschutzangaben: „Genauer Standort, für App-Funktionen“. Vorsichtshalber angeben, auch wenn wir die Daten nicht sehen.
- Hinweis für die App-Prüfung: Test-Crew mit Einladungslink und kurzer Anleitung, damit Apple die Funktion ohne zweites Gerät sieht (Demo-Freunde per Schalter in den Einstellungen nur im Prüf-Build).
- Store-Text und Screenshot „Fahr mit deiner Crew“.

## 7. Grenzen, ehrlich gesagt

- Verzögerung 2 bis 5 Sekunden. Das Weiterrechnen versteckt das beim Geradeausfahren. Beim Abbiegen hängt das Symbol kurz hinterher.
- Nur iPhone (iCloud). Android ginge nur mit einem anderen Weg (Abschnitt 9).
- Ohne iCloud-Konto keine Crew.
- iCloud bremst bei zu vielen Abfragen. Bei mehr als 8 Personen pro Crew wird es zäh, daher die Grenze.

## 8. Was ich nicht mache

- Keine Freundesliste aus Kontakten, kein Telefonbuch-Hochladen.
- Keine öffentliche Suche nach Personen, keine Karte „alle EzMaps-Fahrer“.
- Keine Spielnamen oder Spiel-Grafiken (wie überall).

## 9. Spätere Option: echt live

Falls 2 bis 5 Sekunden zu träge wirken: ein kleiner Weiterleitungs-Server in der EU (z. B. WebSocket auf einem 5-€-Server), der Positionen nur durchreicht und nichts speichert. Crew und Einladung bleiben in iCloud. Die App bekommt nur eine zweite Umsetzung von `FriendsBackend` für die Positionen. Der Rest bleibt gleich. Dafür bräuchte es: Server, Zugangsprüfung über ein Crew-Geheimnis aus iCloud, Datenschutz-Ergänzung, Betrieb und Überwachung.
