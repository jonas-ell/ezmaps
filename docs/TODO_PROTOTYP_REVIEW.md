# Aufgaben aus dem Prototyp-Review (Stand GM-006)

Für den lokalen Claude. Grundlage: Durchsicht aller Bildschirmfotos in `docs/previews/` (iPhone, CarPlay, alle vier Stile).

**Vorgehen**
- Regeln aus `CLAUDE.md` beachten: Antworten auf Deutsch, Design zuerst im Prototyp (`tools/prototype/`), Routen- und Nebel-Logik in `tools/prototype/js/` und `Core/` gemeinsam ändern, vor Swift-Änderungen `docs/LESSONS_SWIFT.md` lesen.
- Teil 0 zuerst (Karten-Look), dann Teil 1, dann Teil 2. Teil 3 sind Ideen: erst im Prototyp zeigen und vom Nutzer freigeben lassen.
- Nach jedem Block: `python tools/prototype/shots.py` laufen lassen, die Bilder in `docs/previews/` ansehen, im `CHANGELOG.md` einen `GM-xxx`-Eintrag schreiben, committen und pushen. Erledigte Punkte hier abhaken (`[x]`).
- Am Ende dieser Datei steht, was danach auf dem Gerät zu testen ist.

## Teil 0 – Karten-Look „Neon City“ an die Vorlage angleichen (wichtigster Punkt)

Der Nutzer sagt: Die Karte sieht „null“ wie die Vorlage aus. Die Vorlage ist eine dunkle Open-World-Pausenkarte (Stadtübersicht von oben): fast schwarzes Land, dünne hellgraue Straßen, helles Wasser, weiße einfarbige Symbole, Legende rechts, Ortsname-Kasten unten links, Maßstab. **Recht:** Nur den Look nachbauen. Keine Spielnamen, keine Spiel-Symbole 1:1 kopieren, alle Symbole selbst zeichnen.

Was vor GM-010 anders war (Farben in `js/map.js:96`, `NEON`, Zeichnen in `drawClassic`, `js/map.js:107`):

| | Vor GM-010 | Vorlage |
|---|---|---|
| Land | mittelgrau `#3d3e40` | fast schwarz, ca. `#1d1e1f`–`#232425`, leichtes Rauschen |
| Gebäude | `#252628`, dunkler als das Land → schwarze Flecken überall, sie dominieren | in der Übersicht kaum sichtbar (Land + 3–5 % Helligkeit), erst nah deutlicher |
| Straßen | dick, Breite in Metern → beim Zoomen sehr fett, Kreisel als dicke weiße Ringe | dünn und gleichmäßig in **Bildschirm-Pixeln** (Nebenstraße ca. 1–1,5 pt, Hauptstraße 2 pt, Schnellstraße 3 pt, heller); Rangfolge über Helligkeit, nicht über Dicke |
| Wasser | dunkelblau `#24313f`, kaum zu sehen | hell blaugrau (ca. `#8fa3b0`), das hellste Element der Karte; Bäche als feine helle Linien |
| Relief | nur Textur-Overlay | Hügel-Schattierung im freien Gelände; Idstein liegt im Taunus, das lohnt sich |
| Zoom beim Stöbern | sehr nah (`browse.scale` 0,42 / 0,55 in `js/app.js:17`) | ganze Stadt auf einen Blick |
| Symbole | bunt (grünes Besteck, blaues P) | einfarbig weiß mit dunkler Kontur, klein (ca. 14 pt), alle gleich; Farbe nur für Ziel, Route und Spieler |

Aufgaben:
- [x] **0.1 Neue Palette für `NEON`:** Land fast schwarz, Wohn-/Gewerbe-/Parkflächen nur minimal heller, Gebäude knapp über dem Land, Wasser hell. Wald und Park nicht grün, sondern neutral mit leichtem Relief.
- [x] **0.2 (geändert in GM-010)** Nach den weiteren Vorlagebildern sind die Straßen dort *breit* und wachsen mit dem Zoom – darum bleiben sie in Metern, aber 1,5× breiter, hellgrau, ohne Rand. Ursprünglich geplant: **Straßenbreiten in Bildschirm-Pixeln** statt in Metern, damit sie beim Zoomen dünn bleiben. Weil die Karte als Textur in Metern gezeichnet wird: Straßen entweder in der Überlagerung (`mv-over`) als Vektor zeichnen oder je Zoomstufe eine passende Textur erzeugen. Kreisel ohne dicken Ring.
- [x] **0.3 Hügel-Schattierung:** Höhendaten (z. B. SRTM / Copernicus DEM 30 m, freie Lizenz, Quelle in der App nennen) in `prep.py` zu einem Graustufen-Bild für Idstein verarbeiten und mit `multiply`/`overlay` schwach über das Land legen.
- [x] **0.4 Zoom beim Stöbern weiter raus**, sodass Idstein ganz auf den Bildschirm passt (iPhone; CarPlay bleibt beim Radar-Zoom aus GM-008). Das Hineinzoomen bleibt möglich.
- [x] _(GM-012: eigener Glyphen-Satz mit Autohaus, Werkstatt, Waschanlage …)_ **0.5 Symbole einfarbig weiß** mit dunkler Kontur in einem eigenen, schlichten Glyphen-Satz (Neon-Assets aus `Assets/Generated` anpassen oder neue Codex-Prompts in `docs/ASSETS_CODEX.md`). In der Übersicht weniger Symbole zeigen (nicht jedes Restaurant).
- [x] **0.6 Legende rechts** _(iPhone umgesetzt; CarPlay bewusst ohne Legende – Apple verlangt dort wenig Ablenkung)_ (iPhone: ausklappbar über den Ebenen-Knopf; CarPlay nur, wenn Apple-Vorgaben es erlauben): Liste der Symbole, weißer Text auf schwarzen Kästen, Tippen hebt die Symbole auf der Karte hervor. Eigene deutsche Begriffe (Tanken, Parken, Essen, Supermarkt, Apotheke …).
- [x] **0.7 Maßstab** unten links über dem Ortsnamen-Kasten (z. B. „0 ─── 500 m“).
- [ ] **0.8 Vergleich:** _(GM-010: Vergleichsbild erstellt und dem Nutzer gezeigt – Freigabe offen)_ Nach der Umstellung ein Bildschirmfoto der Stadtübersicht neben die Vorlage legen und dem Nutzer zeigen, bevor die anderen Stile angepasst werden. Wild West, Pixel Quest und Toy Town nicht verändern, außer bei 0.2 und 0.4, falls die gemeinsam gelten.
- [ ] **0.9 Swift:** Wenn der Nutzer den Look freigibt, dieselben Werte in die Swift-Karte übernehmen (`Core/Sources/EzMapsCore/MapStyle.swift` und den Kartenstil der App).

## Teil 1 – Fehler

- [x] **1.1 „© OpenStreetMap-Mitwirkende“ auf jedem Screen sichtbar machen (rechtlich Pflicht).** Der Hinweis fehlt im Tab Entdecken (`09-entdecken.png`) und im Tab Stile (`10-stile.png`), auch nicht in den Stil-Karten. Bei der Ankunft (`08-ankunft.png`) liegt das Blatt darüber. Heute gibt es `.attrib` nur in Karte und Navigation (`js/phone.js:103`, `:168`). Er soll auch über Blättern sichtbar bleiben (z. B. im Blatt selbst oder darüber). CarPlay ebenfalls prüfen.
- [x] **1.2 Kartensymbole liegen über der Oberfläche.** P- und Besteck-Symbole erscheinen über Statusleiste, Tab-Leiste („Stile“, „Profil“), Zoom-Knopf und dem Knopf „Los“ (`04-karte.png`, `05-suche.png`, `06-routen-vorschau.png`). Im Tab Stile liegt die „230 m“-Einblendung der 4. Karte über dem Tab „Karte“, und Symbole ragen über den Kartenrand hinaus (`10-stile.png`). Vermutete Ursache: Die 3D-Kamera per CSS (`js/map.js`, `.mv-tex`/`.mv-over`) erzeugt eigene Stapel-Ebenen, die `z-index` von `.ui`, `.tabs` und `.status` in `style.css` unterlaufen. Lösung z. B.: `.map` mit `isolation: isolate` / `overflow: hidden` / eigenem `z-index: 0`, Stil-Karten mit `overflow: hidden` und `isolation: isolate`.
- [x] **1.3 Die Fahrzeit der gewählten Route ist unlesbar.** In der Routen-Vorschau wird sie als schwarzer Klecks gezeichnet (Titelschrift `head` auf weißem Grund, `js/phone.js:150`). Sie braucht eine lesbare Schrift und Farbe auf dem hellen Grund.
- [x] **1.4 Der Spieler-Pfeil ist verdeckt.** Das Straßenfeld „WIESBADENER STRASSE“ (`.navinfo` / `.streetbox`) liegt in der Navigation auf dem Pfeil (`07-navigation*.png`). Entweder das Feld verschieben oder den Pfeil in der Kamera höher setzen. iPhone und CarPlay prüfen.
- [x] **1.5 Suche:** „Abbrechen“ ist rechts abgeschnitten (`05-suche.png`). Die Kategorie „Books“ ist Englisch und soll „Buchhandlung“ heißen; alle Kategorie-Namen auf deutsche Begriffe prüfen (Zuordnung in `tools/prototype/prep.py` bzw. `data/idstein.json`).
- [x] **1.6 Die Navigation scheint bei der Ankunft durch.** Hinter dem Blatt sind noch „0 m“, „28 km/h“, das Tempolimit 30 und „Musik leiser“ zu sehen (`08-ankunft.png`). Bei der Ankunft sollen Tacho, Tempolimit, Musik-Hinweis und untere Leiste verschwinden. Die Karte soll aus dem Navi-Zoom auf eine Übersicht der gefahrenen Strecke wechseln.
- [x] **1.7 Die Versionsanzeige im Profil ist veraltet.** Dort steht „Prototyp GM-005“ (`js/phone.js:203`). Die Nummer soll aus einer Stelle kommen und immer zur neuesten GM-Nummer passen.

## Teil 2 – Verbesserungen

- [x] **2.1 Keine doppelte Entfernung in der Navigation.** „700 m“ steht oben in der Abbiegekarte und unten noch einmal. Unten soll stattdessen der Schritt danach stehen („danach links · Bahnhofstraße“), oder die Zeile fällt weg.
- [x] **2.2 Die zwei Balken unten links sind unklar.** Grün und gelb sind nicht beschriftet. Entweder kurz beschriften (z. B. „Strecke“ / „Zeit“) oder auf einen Balken reduzieren.
- [x] **2.3 Video-Clip-Knopf (`clip`) während der Fahrt.** Ihn zu tippen ist Handy-Bedienung am Steuer (§ 23 Abs. 1a StVO). Während der Fahrt ausblenden; den Clip nach der Fahrt im Ankunfts-Blatt anbieten, optional per Sprachbefehl.
- [x] **2.4 Routen-Vorschau.** Alle drei Routen (Schnellste/Kürzeste/Neues entdecken) gleichzeitig zeichnen, gewählte farbig, Alternativen grau, Fahrzeit als kleines Schild an jeder Linie. Ein Tipp auf eine Linie wählt sie aus. Die Karte so einpassen, dass die ganze Route über dem Blatt zu sehen ist (heute ist unten viel leerer Platz). Prüfen, dass der Ziel-Punkt am Routen-Ende liegt.
- [x] **2.5 Einheitliche Knopf-Form.** „Ende“ ist rund, alle anderen Knöpfe sind eckig. Pro Stil eine Form festlegen (Neon eckig, Toy Town rund usw.).
- [x] **2.6 Tab Stile.** Toy Town ist abgeschnitten und kaum auffindbar. Ein 2×2-Raster oder kleinere Karten, sodass alle vier Stile auf einen Blick passen.
- [x] **2.7 CarPlay: einheitliche Schreibweise.** Der Straßenname steht oben normal und unten in Großbuchstaben. Das soll einheitlich sein. Die Einblendung unten links darf nicht mit Systemteilen kollidieren und muss nicht bedienbar sein (Apple-Vorgaben für Navigations-Apps).
- [x] **2.8 Suche ohne Eingabe.** „Zuletzt gesucht“ und Kategorie-Knöpfe (Tanken, Parken, Essen, Supermarkt) zeigen.
- [x] **2.9 Profil ergänzen.** Routen-Optionen (Autobahn meiden, Maut meiden), „Zuhause / Arbeit bearbeiten“, Standard-Stil.

## Teil 3 – Ideen (erst im Prototyp zeigen, Nutzer fragen)

- [ ] **3.1 Ankunft als Belohnung.** Gefahrene Strecke aufdecken, neue Straßen kurz aufleuchten lassen, „+3 % Altstadt“. Nur im Stand, nichts davon während der Fahrt.
- [ ] **3.2 Fahrspur-Hinweise.** Spurpfeile aus OSM `turn:lanes` in der Abbiegekarte (iPhone + CarPlay). Dafür `prep.py` erweitern; die Logik in `js/route.js` und `Core/` gemeinsam.
- [ ] **3.3 Automatischer Nachtmodus** für die hellen Stile Wild West und Toy Town.
- [ ] **3.4 Ortsteil-Missionen im Tab Entdecken**, z. B. „Fahre 2 neue Straßen in Idstein Ost“ mit Abzeichen als Belohnung; die Route „Neues entdecken“ führt dorthin.
- [ ] **3.5 Wochenrückblick als teilbares Bild** (km, aufgedeckte Fläche, Abzeichen) im Look des gewählten Stils.
- [ ] **3.6 Freunde datenschutzfreundlich:** statt Live-Standort nur Fortschritt („X hat Oberauroff zu 60 % entdeckt“).

## Danach auf dem Gerät testen

- Ist „© OpenStreetMap-Mitwirkende“ auf jedem Screen sichtbar (Karte, Suche, Vorschau, Navigation, Ankunft, Entdecken, Stile, Profil, CarPlay)?
- Liegen Kartensymbole nie über Statusleiste, Tab-Leiste oder Knöpfen?
- Ist die Fahrzeit in der Routen-Vorschau lesbar?
- Ist der Spieler-Pfeil in der Navigation ganz zu sehen, auf iPhone und CarPlay?
- Verschwinden Tacho, Tempolimit und „Musik leiser“ nach der Ankunft?
- Ist „Abbrechen“ in der Suche voll lesbar?
- Gibt es während der Fahrt keinen Clip-Knopf mehr?
