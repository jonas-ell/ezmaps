# EzMaps-Autopilot – Plan für den lokalen Claude (GM-099)

Ziel: Ein Programm, das Claude Code immer wieder selbst startet („sich selbst promptet“), damit die App laufend besser wird.
Jede Entscheidung trifft eine **harte Jury** aus mehreren unabhängigen Claude-Prüfern.
Vorrang hat alles, was Apple bei der App-Prüfung oder bei CarPlay bemängeln könnte.

Gebaut und ausgeführt wird es vom **lokalen Claude** auf dem Windows-PC. Der Mac wird nur über das Gate genutzt.

---

## 1. Grundregeln (gelten für jede Runde, nie aufweichen)

1. CLAUDE.md gilt vollständig. Dazu gehören:
   - Deutsch
   - CHANGELOG-Eintrag
   - LESSONS_SWIFT lesen
   - keine Geheimnisse
   - keine Spielnamen
   - OSM-Hinweis
   - keine Blitzer
   - Kartenstil nur über `build_style.py`
   - Mac nur über `mac-ezmaps`, nie `id_ed25519`
2. **Nie automatisch:**
   - zu App Store Connect hochladen (`mac_archive.sh --upload`)
   - Preise oder Produkte ändern
   - Rechtstexte ändern
   - den CarPlay-Antrag stellen
   - Stile oder Funktionen löschen
   - einen force-push machen
   - Dateien in `Assets/Generated/` (Nutzer-Grafiken) löschen
   - `tools/prototype/fonts/` oder Pricedown anfassen
   - Sachen in `docs/legal/` ändern
3. **Nur Vorschlag, nie direkt nach main:**
   - neue Designs
   - neue Stile
   - größere Umbauten
   Dafür gibt es einen eigenen Branch `vorschlag-…` mit Vorher/Nachher-Bildern, wie bisher. Der Nutzer gibt frei.
4. Der Autopilot darf seinen eigenen Code (`tools/autopilot/`), die Jury-Regeln und die Prüfliste **nicht selbst ändern**. Änderungen daran sind immer Nutzer-Entscheidungen.
5. **Not-Aus:**
   - Liegt eine Datei `tools/autopilot/STOP` vor (nicht committet, `.gitignore`), hört die Schleife nach der laufenden Runde auf.
   - Dazu kommen Grenzen pro Tag: Runden, Kosten in Dollar und Stunden.

---

## 2. Aufbau des Programms

Sprache: Python 3, nur die Standardbibliothek plus `pyyaml`. Ordner `tools/autopilot/`:

| Datei | Aufgabe |
|---|---|
| `autopilot.py` | Hauptschleife. Befehle: `audit`, `run`, `run --dry`, `status`, `jury-test` |
| `claude_call.py` | Startet `claude -p "<prompt>" --output-format json --model … --allowedTools …` mit Zeitlimit. Liest `result`, `total_cost_usd` und `session_id`. Antwort muss JSON nach Schema sein, sonst bis zu 2 neue Versuche. |
| `jury.py` | Ruft die Juroren getrennt auf (keiner sieht die anderen) und zählt nach den Regeln in Abschnitt 4 |
| `checks.py` | Prüfungen ohne KI: `cd Core && swift test`, `check_style.py`, Mac-Build über das Gate, `mac_check.sh` (Bilder iPhone und CarPlay), grep-Regeln aus Abschnitt 6 |
| `backlog.py` | Liste der Aufgaben `.autopilot/backlog.json` (nicht committet) mit id, Titel, Art, Beweis, Dateien, Status, Versuche |
| `config.yaml` | Grenzen, Modelle, Jury-Größe, Mehrheiten, erlaubte Werkzeuge je Rolle |
| `prompts/*.md` | Rollen-Texte: finder, planer, bauer, juror-apple, juror-carplay, juror-technik, juror-fahrer, juror-recht |
| `tests/` | `unittest` für die Jury-Zählung, die Backlog-Reihenfolge, die GM-Nummer und das STOP-Verhalten |

**Arbeitsweise:**
- Jede Runde arbeitet in einem eigenen `git worktree` auf dem Branch `autopilot/<id>`. main wird nur beim Mergen angefasst.
- Protokoll: `.autopilot/logs/<datum>/<runde>/`. Dort liegen alle Prompts, Antworten, Stimmen, Diffs, Testausgaben und Bilder.
- **Tagesbericht** `docs/autopilot/bericht-<datum>.md` (committet):
  - was gemacht wurde
  - was die Jury abgelehnt hat und warum
  - was der Nutzer entscheiden muss

---

## 3. Eine Runde

```
0. STOP-Datei? Tagesgrenzen? → sonst Ende
1. git pull main; Ausgangsstand grün? (Core-Tests, Stil, Mac-Build). Wenn rot: einzige Aufgabe = rot reparieren
2. Aufgabe wählen: höchste Stufe zuerst (Abschnitt 5), bei gleicher Stufe die älteste
3. PLANER (claude -p, nur lesen) → Plan: Ursache, Änderung, betroffene Dateien, Risiko, wie geprüft wird
4. JURY über den Plan → abgelehnt: Begründungen an den Planer, höchstens 2 neue Pläne, dann Aufgabe „blockiert“
5. BAUER (claude -p im Worktree, darf ändern) → setzt genau den Plan um, CHANGELOG-Entwurf
6. PRÜFUNGEN ohne KI (checks.py) → rot: Fehlertext an den Bauer, höchstens 2 Versuche, sonst verwerfen
7. JURY über das Ergebnis: Diff + Testausgabe + Vorher/Nachher-Bilder (iPhone UND CarPlay) + Plan
8. angenommen → GM-Nummer frisch aus origin/main (höchste + 1), CHANGELOG, Commit, Merge nach main, Push
   abgelehnt  → Begründungen an den Bauer, 1 Versuch; danach verwerfen und als „abgelehnt“ mit Gründen loggen
9. Tagesbericht ergänzen; nächste Runde
```

Der **Finder** läuft getrennt davon (`autopilot.py audit`, zum Beispiel einmal pro Tag oder wenn das Backlog leer ist). Er sammelt neue Aufgaben aus:
- der Prüfliste (Abschnitt 6)
- Build-Warnungen
- Testfehlern
- Absturzprotokollen aus dem Simulator
- den Prüfbildern (`docs/store/…`, Claude sieht die Bilder)
- der Datei `docs/autopilot/WUENSCHE.md` (Nutzer schreibt dort Wünsche hinein)

Jede neue Aufgabe braucht einen **Beweis**: Datei und Zeile, Logzeile oder Bild. Aufgaben ohne Beweis werden verworfen.

---

## 4. Die harte Jury

**Fünf Juroren**, jeder ein eigener `claude -p`-Aufruf mit eigenem Rollentext, ohne Zugriff auf die Stimmen der anderen:

| Juror | prüft |
|---|---|
| **Apple-Prüfer** | App Review Guidelines: 2.1, 2.3, 2.5, 3.1, 4.1, 4.2, 5.1, 5.2 |
| **CarPlay-Prüfer** | CarPlay Developer Guide (Navigation), Fahrsicherheit, Vorlagen-Grenzen |
| **Technik** | Korrektheit, Abstürze, Nebenläufigkeit, Leistung, LESSONS_SWIFT, Tests, keine Nebenwirkungen |
| **Fahrer** | sieht die Bilder: lesbar bei Sonne und Nacht, nichts verdeckt, weniger Ablenkung, Bedienung mit einer Hand |
| **Recht** | Spielnamen und Spiel-Look (geistiges Eigentum), Lizenzen von Schriften, Grafiken und Daten, OSM-Hinweis, StVO, DSGVO |

**Antwort jedes Jurors, nur dieses JSON:**
```json
{"stimme": "JA" | "NEIN", "veto": true | false, "schwere": "blocker" | "hoch" | "mittel" | "niedrig",
 "gruende": ["… mit Datei:Zeile oder Bildname …"], "bedingungen": ["…"]}
```

**Regeln (fest im Code, mit Tests):**
- **Im Zweifel NEIN.** Jeder Rollentext beginnt mit: „Du bist absichtlich streng. Ohne Beweis stimmst du NEIN.“
- Ein ungültiges JSON, eine Zeitüberschreitung oder ein Grund ohne Beweis zählt als **NEIN**.
- **Veto:** Ein einziges `veto: true` mit Schwere `blocker` lehnt ab, egal wie die anderen stimmen.
- **Mehrheiten:**
  - Normale Änderung: **4 von 5 JA**.
  - **5 von 5 JA**, wenn CarPlay, Käufe/StoreKit, Standort/Datenschutz, Rechtliches oder Hintergrund-Modi betroffen sind. Das erkennt `jury.py` an den Pfaden (`CarPlay*`, `Purchase*`, `PrivacyInfo`, `project.yml`, `Info`, `docs/legal`) und an der Aufgaben-Art.
- Den Juroren wird **nicht** gezeigt, was der Bauer über seine eigene Arbeit sagt. Sie sehen nur:
  - Aufgabe
  - Plan
  - Diff
  - Prüfausgaben
  - Bilder
- **Bei wichtigen Entscheidungen zwei Durchläufe:** Bei Stufe A (Abschnitt 5) wird die Jury zweimal mit neuer Reihenfolge der Unterlagen befragt. Beide Male muss die Mehrheit stehen.
- **Modell:** Die Juroren nehmen das stärkste verfügbare Claude-Modell. Der Bauer darf ein günstigeres nehmen (`config.yaml`).

---

## 5. Reihenfolge der Aufgaben (Stufen)

| Stufe | Art |
|---|---|
| **A** | Alles, was zur **Ablehnung durch Apple** führen kann (App oder CarPlay), Abstürze, Datenverlust, Lizenzverstöße |
| **B** | Echte Fehler in Navigation, Ansagen, Suche, Käufen, CarPlay-Ablauf |
| **C** | Leistung (Ruckeln, Akku, Speicher), Barrierefreiheit (VoiceOver, große Schrift), Englisch-Texte |
| **D** | Feinschliff und kleine Verbesserungen an bestehenden Stilen |
| **E** | Neue Ideen → nur als Vorschlag-Branch, nie automatisch nach main |

Die Stufen A bis C dürfen nach Jury-Mehrheit nach main. D ist erst erlaubt, wenn A bis C leer sind. E geht nie nach main.

---

## 6. Prüfliste App Store + CarPlay (Startinhalt des Backlogs)

Erste Aufgabe des Autopilots: `docs/APPSTORE_PRUEFLISTE.md` aus dieser Liste anlegen. Danach jeden Punkt mit Beweis als ✅, ⚠️ oder ❌ markieren. Jedes ⚠️ und ❌ wird eine Aufgabe.

### 6.1 Schon gefundene Verdachtsfälle (Cloud-Prüfung, main bei GM-097) – zuerst prüfen

1. **Pricedown im App-Store-Archiv:**
   - `tools/mac_archive.sh` baut über `tools/mac_build.sh`, und das kopiert `~/EzMapsPrivate/Fonts/pricedown.otf` nach `App/Fonts/`, wenn die Datei auf dem Mac liegt.
   - `project.yml` führt `Pricedown.otf` in `UIAppFonts`.
   - Die Lizenz gilt nur für den Desktop. Im App-Store-Build wäre das ein Lizenzverstoß (Stufe A).
   - Erwartung: Das Archiv nimmt nie Pricedown mit, und `UIAppFonts` nennt nur Schriften, die im Bundle sind.
2. **CarPlay-Grundfenster mit Zusatzanzeigen:**
   - `CarPlaySceneDelegate.swift` legt eigene Views auf die Karte: Test-Uhr `trialLabel`, Tempo-Schild `limitLabel` und den Hinweis-Text.
   - Apple verlangt, dass das Grundfenster nur die Karte zeigt. Bedienelemente und Hinweise gehören in die Vorlagen.
   - Prüfen und Lösung wählen: Tempolimit und Testzeit über Vorlagen (`CPNavigationSession`, `CPMapTemplate`-Leisten, `CPInformationTemplate`) oder weglassen. Der OSM-Hinweis darf als Teil der Karte bleiben (Jury Recht + CarPlay).
3. **Öffentliche Server:**
   - Valhalla (FOSSGIS), Photon (komoot) und OpenFreeMap sind kostenlos, haben aber Nutzungsregeln.
   - Prüfen, was eine verkaufte App darf (`docs/VEROEFFENTLICHUNG.md`).
   - Wenn ein Server bei der Prüfung ausfällt oder sperrt, lehnt Apple wegen 2.1 ab.
4. **App-Prüfer sitzt in den USA:**
   - Suche, Routing und Karte müssen dort funktionieren, oder die Hinweise für den Prüfer müssen das genau erklären: Demo-Route, die man ohne Fahrt starten kann.
5. **Spiel-Ähnlichkeit (4.1/5.2):**
   - Pixel Quest (Blockwelt mit Villager-Häusern) und Neon City (Pricedown-artig) sind Risiken.
   - Juror Recht bewertet Bilder und Store-Texte.
   - Kein Spielname in Texten, Schlüsselwörtern oder Bildern.

### 6.2 App Review (Auszug, jeweils mit Beweis prüfen)

- **2.1:**
  - kein Absturz beim Start, bei Stilwechsel, Suche, Routenstart, Ankunft, CarPlay-Verbinden und -Trennen
  - keine Platzhalter („bald“, „Test“, leere Listen ohne Erklärung)
  - alle Links funktionieren
  - Test-Käufe (`EZTEST`, `DEBUG`) nie im Release
- **2.3:** Store-Bilder zeigen die echte App, Texte versprechen nichts, was fehlt.
- **2.5.4:**
  - Hintergrund-Modi: `location` nur für Navigation, `audio` nur für Ansagen.
  - Beides muss im Prüfer-Hinweis begründet sein. Kein Hintergrund-Audio ohne Ansage.
- **3.1.1 / 3.1.2:**
  - Käufe nur über StoreKit, Knopf „Wiederherstellen“ sichtbar
  - auf der Paywall: Abo-Laufzeit, Preis, Leistung und Links zu Nutzungsbedingungen (EULA) und Datenschutz
  - kein Kauf und keine Kaufaufforderung in CarPlay
- **4.2:** Die App bietet mehr als eine Webseite. Das ist erfüllt, trotzdem mit Beweis eintragen.
- **5.1.1:**
  - Zwecktexte für den Standort sind verständlich und richtig.
  - Der Standort wird erst gefragt, wenn er gebraucht wird.
  - `PrivacyInfo.xcprivacy` deckt alle Required-Reason-APIs ab (UserDefaults, Systemlaufzeit, Dateidatum, Speicherplatz). Code mit grep gegenprüfen.
- **5.1.2:** Datenschutz-Angaben in App Store Connect nennen den Standort und die Suchtexte, die an Routing-, Such- und Karten-Server gehen.
- **5.2:** Lizenzen aller Schriften, Grafiken (Codex, Nutzer) und Daten stehen im Repo (`docs/legal/`), OSM-Hinweis immer sichtbar.
- **Fahrsicherheit:** keine Blitzer, keine Eingaben während der Fahrt außer per Sprache oder Vorlage, Warnhinweis beim ersten Start.

### 6.3 CarPlay (Navigation)

- Berechtigung `com.apple.developer.carplay-maps`:
  - Stand der Signierung prüfen (heute nur Simulator).
  - Der App-Store-Build darf ohne erteilte Berechtigung nicht abstürzen.
- **Grundfenster nur Karte** (siehe 6.1 Nr. 2), alles andere über Vorlagen.
- Vorlagen-Grenzen:
  - Tiefe des Vorlagen-Stapels höchstens 5
  - Knöpfe in `CPMapTemplate` (mapButtons, Leisten) innerhalb der Grenzen
  - Listenlängen über `CPListTemplate.maximumItemCount`
- Startet aus CarPlay, auch wenn die App auf dem iPhone nie geöffnet oder das iPhone gesperrt ist. Fehlt die Standort-Erlaubnis, kommt ein klarer Hinweis in CarPlay („Bitte auf dem iPhone erlauben“), kein Hängen.
- Verbinden, Trennen und erneutes Verbinden während einer Navigation: kein Absturz, keine doppelten Ansagen.
- Tag und Nacht: Die Karte richtet sich nach dem Erscheinungsbild von CarPlay und blendet nachts nicht.
- Bildschirmgrößen: 800×480 bis Breitbild (1920×720), Rechtslenker, sichere Bereiche (`safeArea` der Vorlage).
- Ansagen:
  - `AVAudioSession` im Modus `.voicePrompt`
  - andere Musik wird nur leiser, die Sitzung wird danach freigegeben
- Abbiegehinweise: `CPManeuver` mit Symbol und Textvarianten, Restzeit und Entfernung werden laufend aktualisiert, Neuberechnung angezeigt.
- Suche über `CPSearchTemplate` und Sprache, kein freies Tippen während der Fahrt.
- Kein Kauf, kein Shop, keine Werbung, kein Video, keine langen Texte in CarPlay.
- Optional, später, nur als Vorschlag: Dashboard- und Kombiinstrument-Szene.

### 6.4 Feste Prüfregeln ohne KI (checks.py)

- grep: kein Spielname (Liste in `config.yaml`) in `App/`, `docs/store/`, App-Texten oder `en.lproj`.
- `UIAppFonts` ⊆ Schriften im Bundle; kein `Pricedown` im Archiv-Weg.
- `UIBackgroundModes` nur `location` und `audio`.
- `#if DEBUG || EZTEST` um jeden Test-Kauf-Code.
- Keine Blitzer-Begriffe (`blitzer`, `speed camera`, `radar` als Warnung).
- Jede neue `UserDefaults`-, `systemUptime`- oder Datei-Datum-Nutzung → passender Eintrag in `PrivacyInfo.xcprivacy`.
- Neue Strings haben einen englischen Eintrag.

---

## 7. Mac und Bilder

- Bauen und Prüfen wie bisher: `ssh mac-ezmaps clean && git archive HEAD | ssh mac-ezmaps extract && ssh mac-ezmaps build`, danach `bash tools/mac_check.sh` (iPhone- und CarPlay-Bilder).
- Für die Jury braucht jede UI-Änderung **Vorher/Nachher-Bilder vom selben Bildschirm**, iPhone und CarPlay.
- Wenn das Gate dafür einen neuen Befehl braucht (zum Beispiel CarPlay trennen/verbinden, UI-Tests): Der Nutzer muss das Gate auf dem Mac erweitern. Der Autopilot schreibt das als Nutzer-Entscheidung in den Bericht und baut keinen Umweg.
- Es läuft immer nur ein Mac-Lauf zur Zeit (Sperrdatei `.autopilot/mac.lock`).

---

## 8. Zusammenarbeit mit Cloud-Claude und Nutzer

- **GM-Nummer** erst beim Mergen vergeben: höchste Nummer auf `origin/main` + 1. So gibt es keine doppelten Nummern mehr. Der Cloud-Zweig hatte zuletzt eigene GM-084 bis GM-091 neben denen von main.
- Der Cloud-Zweig `claude/sharp-knuth-8k97wf` ist **nicht** in main. Erste Stufe-D-Aufgabe: ihn sichten, die Jury entscheidet je Teil:
  - `MotionSmoother` gegen Ruckeln (Core, getestet)
  - Mindest-Zoom gegen den Rand über dem Nordpol
  - Demo „Ödland-Terminal“ (`tools/prototype/oedland.html`)
  - die zweite Würfel-Erde `CubeEarthView`: **nicht übernehmen**, main hat `WorldCubeView`
- `docs/autopilot/WUENSCHE.md`: Der Nutzer schreibt Wünsche hinein. Sie werden Aufgaben der passenden Stufe.
- Fragen an den Nutzer sammelt der Tagesbericht unter „Du entscheidest“. Der Autopilot wartet dort nicht, sondern macht mit der nächsten Aufgabe weiter.

---

## 9. Einführung in Schritten (nicht alles auf einmal)

1. **M1 Gerüst:**
   - `claude_call.py`, `config.yaml`, STOP, Grenzen, Protokoll
   - `jury.py` mit Tests für alle Regeln aus Abschnitt 4 (gefälschte Antworten, keine echten Aufrufe)
2. **M2 Prüfung:**
   - `autopilot.py audit` legt `docs/APPSTORE_PRUEFLISTE.md` an und füllt das Backlog
   - **ändert keinen Code**
   - Ergebnis dem Nutzer zeigen
3. **M3 Probelauf:** `run --dry` macht 3 Runden komplett, aber **ohne Merge nach main** (nur Branches `autopilot/…`). Der Nutzer sieht Diffs, Stimmen und Bilder an.
4. **M4 Echtbetrieb:** Merge nach main erst, wenn der Nutzer nach M3 „los“ sagt. Anfangs höchstens 5 Runden pro Tag.
5. **M5:** Grenzen nach Erfahrung anpassen. Das entscheidet nur der Nutzer.
