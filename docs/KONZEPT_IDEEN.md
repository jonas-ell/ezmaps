# EzMaps – Gesamtblick und Verbesserungsideen (GM-040)

Stand: Oktober 2026. Grundlage: Swift-App (`App/`, `Core/`, Stand GM-028), Prototyp (`tools/prototype/`), CHANGELOG bis GM-039, `docs/TODO_PROTOTYP_REVIEW.md`, Konkurrenz-Recherche (GM-037).

## 0. Ehrlicher Ist-Stand

| Bereich | Prototyp | Swift-App |
|---|---|---|
| Karte | 5 Stile, ganz Deutschland | nur Neon City |
| Navigation, Ansagen, Neuberechnung, Tempolimit | ja | ja (GM-020/028) |
| CarPlay | Vorschau | ja, Entitlement bei Apple noch nicht beantragt |
| Glas-Design, Onboarding, Shop, Plus, Einzelkauf | ja (GM-029 bis GM-039) | **nein** |
| StoreKit | – | **nein** |
| Aufdecken / Nebel / Entdecken | teilweise | **nein** |

**Das größte Problem ist das Konzept, nicht das Design:** Das Geschäftsmodell verkauft 4 Kauf-Stile, die Swift-App hat aber genau einen Stil. Gleichzeitig warten 11 Aufträge (GM-029 bis GM-039). Diese Aufträge werden ständig umgeschrieben, die Preise zum Beispiel dreimal. Vorschlag: Ab jetzt zuerst ausliefern, dann ausbauen.

---

## 1. Konzept und Strategie (wichtigste zuerst)

### 1.1 Version 1.0 klein halten: Klassik gratis + Neon City + Plus
- Wild West, Pixel Quest und Toy Town **nicht** zum Start, sondern als „neuer Stil“ alle 6 bis 8 Wochen nach dem Start
- Das löst drei Probleme auf einmal:
  - Die App kommt viel früher raus.
  - Apple will für ein Abo dauerhaften Nutzen sehen (Richtlinie 3.1.2). Regelmäßig neue Stile liefern genau den.
  - Jeder neue Stil ist ein Anlass für Werbung und Social Media, und Push-Nachrichten dürfen wir dafür nur mit Erlaubnis schicken.
- Paywall zum Start: Plus, also Neon und alle künftigen Stile, oder Neon einzeln

### 1.2 Der echte Unterschied zur Konkurrenz ist „Stadt aufdecken“, nicht der Skin
- MapSkins, Mappr und die anderen verkaufen nur Optik. Optik lässt sich leicht kopieren, und die Konkurrenz nutzt teils rechtlich riskante Spielnamen.
- EzMaps hat eine Spielidee: Straßen aufdecken, Prozent je Ortsteil, Stufen wie „Idstein-Kenner“, Missionen. Daraus entsteht eine Gewohnheit, man fährt öfter, weil die Karte wächst.
- Vorschlag: **Aufdecken kommt in die 1.0, mindestens die einfache Version**: gefahrene Straßen leuchten, „+12 % neue Straßen“ bei der Ankunft (Screen ist fertig in `onboarding.html`).
- App-Store-Satz: „Navi, das deine Stadt zur Spielwelt macht“ statt „Karte im Spiel-Look“

### 1.3 Reverse Trial statt nur „Stil testen“
- Neue Nutzer fahren die **ersten 3 Tage automatisch mit Neon City**. Danach geht es zurück zu Klassik, mit dem Hinweis „Neon behalten?“.
- Dahinter steckt Verlustangst: Was man schon hatte, will man behalten. Das wirkt meist stärker als 10 Minuten Testzeit.
- Das 10-Minuten-Testen (GM-033) bleibt für die anderen Stile.
- Regel wie bisher: Ein Stil läuft nie während einer Fahrt ab.

### 1.4 Paywall zum richtigen Zeitpunkt
1. Am Ende des Onboardings eine weiche Paywall mit „Später“-Knopf und Hinweis auf die Gratis-Woche
2. **Nach der ersten Ankunft**: gute Laune, die Karte ist gerade aufgeleuchtet
3. Wenn die Probezeit endet (siehe 1.3)
4. Nie während der Fahrt, nie in CarPlay (Apple-Vorgabe und Sicherheit)

### 1.5 Wachstum über Videos (TikTok, Reels, Shorts)
- Die Neon-Karte in CarPlay ist das stärkste Werbebild der App
- **„Fahrt-Replay“**: Nach der Ankunft wird die Strecke als 10-Sekunden-Video im Stil exportiert, mit Kameraflug und aufleuchtenden Straßen, im Hochformat 9:16 und mit kleinem „EzMaps“-Wasserzeichen. Jedes geteilte Video ist Gratis-Werbung.
- Ausbau des Fotomodus (TODO 5.8)

### 1.6 Server und Kosten ehrlich einplanen
- Routing (FOSSGIS-Valhalla) und Suche (komoot Photon) sind Fair-Use-Server (`docs/VEROEFFENTLICHUNG.md`). Bei einem viralen Video mit 10.000 neuen Nutzern sperren sie uns.
- Vor jeder Werbung einen eigenen Server aufsetzen, etwa Hetzner mit 64 GB RAM für Deutschland, Valhalla und Photon zusammen ungefähr 40 bis 60 € im Monat
- Das Abo bezahlt diese Kosten, ein Einmalkauf auf Dauer nicht. Auch das spricht für Plus.

### 1.7 Verkehrslage fehlt, die größte Schwäche als Navi
- Ohne Live-Verkehr ist die Ankunftszeit im Berufsverkehr falsch, und um Staus wird nicht herumgeführt
- Möglichkeiten:
  - (a) Klar sagen: „ohne Live-Verkehr“, für Stadt und Freizeit
  - (b) Verkehrsdaten zukaufen, z. B. TomTom oder HERE. Das kostet pro Abfrage, also nur für Plus.
  - (c) Erst einmal Baustellen und Sperrungen der Autobahn GmbH (gratis, GM-029/033) gut machen
- Empfehlung: (a) und (c) zum Start, (b) prüfen, wenn es zahlende Nutzer gibt

### 1.8 Messen statt raten
- Ohne Zahlen wissen wir nicht, ob 2,50 € oder 3,33 € pro Monat besser läuft
- Datenschutzfreundliche, anonyme Zählung wie TelemetryDeck (ohne Werbe-ID) für:
  - Onboarding fertig
  - Paywall gesehen
  - Gratis-Woche gestartet
  - Abo nach der Woche behalten
  - erste Fahrt
  - Fahrten pro Woche
- Danach Preise mit StoreKit-Angeboten und Store-Produktseiten-Tests (A/B) testen
- Datenschutz-Angaben im App Store und `PrivacyInfo.xcprivacy` entsprechend anpassen

---

## 2. Produkt-Ideen

### Fahren
- **Fahrspur-Pfeile** (TODO 3.2): Bei großen Kreuzungen helfen sie am meisten. In CarPlay geht das über `CPManeuver` mit Spurbild.
- **Zu-schnell-Hinweis**: Das Tempolimit-Schild wird rot und blinkt einmal, wenn man mehr als 5 km/h darüber fährt. Optional ein leiser Ton. **Kein Blitzer**, nur das Schild.
- **Tankstellen mit Preis** (Tankerkönig, gratis mit Schlüssel) und **Ladesäulen** (Open Charge Map): Schnellziel „Tanken“ zeigt die günstigste Tankstelle an der Route
- **Live-Aktivität und Dynamic Island**: nächstes Abbiegen und Ankunftszeit auf dem Sperrbildschirm
- **Apple Watch**: Vibration vor dem Abbiegen, einfache Pfeil-Anzeige
- **Zwischenstopp** („Tanken auf dem Weg“) mit einem Tipp, ohne Planungs-Ansicht
- **Nachtmodus** für die hellen Stile (TODO 3.3), automatisch nach Sonnenuntergang

### Spielgefühl (eigene Inhalte, keine Spielnamen)
- **Ortsteil-Fortschritt** mit Abzeichen (TODO 3.4), z. B. „Altstadt 100 %“ mit goldenem Rand auf der Karte
- **Wochenmissionen**: „Fahre 3 neue Straßen“, „Entdecke einen neuen Ortsteil“. Die Route „Neues entdecken“ führt hin.
- **Eigene Sounds je Stil**: Ankunfts-Ton und kurzer Klang bei einer neuen Straße, selbst komponiert, bei jeder Musik abschaltbar
- **Fahrzeug-Skins für den Positionspfeil**, als Plus-Vorteil oder einzeln: Sportwagen, Pick-up, Pixel-Auto, Spielzeugauto. Das ist nur Optik, man muss also kein Fahrzeug wählen. Die Fahrzeugwahl im Onboarding bleibt gestrichen.
- **Wochenrückblick als teilbares Bild** (TODO 3.5)
- **Freunde ohne Live-Standort** (TODO 3.6): Nur der Fortschritt wird verglichen.

### Bedienung
- **Siri und Kurzbefehle**: „Hey Siri, EzMaps nach Hause“ (TODO 5.7)
- **Widgets**: Zuhause/Arbeit mit Fahrzeit, „Dein Auto“, Wochen-Fortschritt
- **Links aus anderen Apps** (Adresse teilen → in EzMaps öffnen)
- **Stil in CarPlay wechseln** (eine Taste in der Kartenleiste)
- **Englisch** von Anfang an (`App/en.lproj` gibt es schon): Österreich, Schweiz und Touristen sind auch Kunden. Später andere Länder, die Karten sind ja OSM.

---

## 3. Technik und Ablauf

1. **Reihenfolge für den lokalen Claude** (Vorschlag):
   1. Klassik-Stil in Swift
   2. StoreKit (GM-038/039 nur mit Neon)
   3. Glas-Grundbausteine (GM-032/036)
   4. Onboarding
   5. Ankunft mit Aufdecken
   6. eigene Server
   7. Veröffentlichung
   - Alles andere danach.
2. **Aufträge zusammenfassen**: Für GM-029 bis GM-039 eine Datei `docs/STAND_SPEC.md` mit den *aktuell gültigen* Werten (Preise, Farben, Screens). Dann muss der lokale Claude keine überholten Angaben aus alten Einträgen heraussuchen.
3. **Bild-Tests**: Snapshot-Tests der SwiftUI-Screens gegen die Prototyp-Bilder, damit „sieht schief aus“ früh auffällt
4. **Absturzberichte**: Xcode Organizer reicht zum Start, keine Fremd-Bibliothek nötig
5. **Akku**: Messen, wie viel eine Stunde Navigation mit 30 Bildern/s in CarPlay verbraucht (GM-028). Im Stand ggf. auf 10 Bilder/s gehen.

---

## 4. Top 5 – wenn nur Zeit für fünf Sachen ist
1. Version 1.0 = Klassik + Neon + Plus + einfaches Aufdecken (1.1, 1.2)
2. Reverse Trial: 3 Tage Neon für alle Neuen (1.3)
3. Eigene Server vor jeder Werbung (1.6)
4. Fahrt-Replay-Video zum Teilen (1.5)
5. Anonyme Zählung, um die Preise zu prüfen (1.8)
