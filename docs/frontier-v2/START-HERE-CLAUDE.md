# ezmaps Frontier V2 — verbindlicher Gestaltungsauftrag

## Ziel und maßgebliche Referenzen

Setze den neuen Kartenstil für die bestehende iPhone-/CarPlay-App um. Öffne zuerst beide Bilder:

1. `Reference/01-terrain-target.png`: maßgebliche Landschaftsgestaltung ohne UI.
2. `Reference/02-navigation-target.png`: dieselbe gestalterische Richtung mit Navigation.

Diese beiden Bilder sind das akzeptierte visuelle Ziel. Das ältere Frontier-Expedition-Paket V1 wurde wegen zu flacher, schematischer Flächen und großer POI-Plaketten verworfen. Es darf nicht als visuelle Basis dienen. Die V2-Piktogramme greifen einzelne eigene Grundsymbole auf, haben aber keine V1-Plaketten mehr.

Die Bilder sind KI-erzeugte Konzeptillustrationen mit erfundener Geografie, keine gerenderten MapLibre-Ergebnisse. Reproduziere ihren **Stil auf echten geografischen Daten**. Berge, Gewässer und Straßen müssen ihren tatsächlichen Orten folgen. Das Bild darf nicht als weltweit wiederholte Karte, als Satelliten-Layer oder als georeferenziertes Hintergrundbild ausgegeben werden. Eine pixelidentische Darstellung beliebiger Orte ist damit nicht vorgegeben oder garantiert.

## Was der Nutzer sehen will

- Gelände ist der wichtigste Bildbestandteil: zusammenhängende Bergrücken, eingeschnittene Täler, Licht auf nordwestlichen Hängen, Schatten auf südöstlichen Hängen.
- Gedruckte oliv-/khakifarbene Feldkarte, matte warme Farben, feine unregelmäßige Körnung.
- Wald wirkt wie eine zusammenhängende dichte Oberfläche. Keine großen aufgeklebten Baumobjekte, keine sichtbaren regelmäßigen Muster.
- Felsige Hänge sind warm kreidig; Wasser ist blasses graublaues Wasser mit dunklerem organischem Ufer.
- Straßen sind schmale sandfarbene Linien. Sie begleiten die Landschaft; sie dürfen sie in der Übersicht nicht dominieren.
- Siedlungen bestehen aus kleinen echten unregelmäßigen Gebäudegrundrissen. Keine künstlich angelegten Reihen gleicher Rechtecke.
- POIs sind kleine helle Zeichen mit dunkler Kontur. Keine achteckigen Rahmen, keine bunten großen Plaketten.
- Route in gedämpftem Amber, cremefarbener Spieler, wenige Kartenzeichen, dunkle ruhige Navigationspanels.

## Lieferumfang dieses Pakets

39 Produktionsassets: 20 POIs, 8 Marker, 6 HUD-Zeichen und 5 Materialtexturen. 34 SVG-Quellen; alle 39 als PNG @1x/@2x/@3x und 1024²-Master. Die neuen IDs beginnen mit `fv2-`. Der Sprite-Atlas enthält dieselben IDs bei 1× und 2×. Manifeste und `MapLibre/asset-registry.json` legen Dateinamen und Basisgrößen fest.

Die fünf Texturen sind transparente periodische Material-Overlays. Sie liefern Körnung und Vegetationsstruktur, **keine Berghöhen und keine Waldgrenzen**. Der Wald-Layer muss aus echter Landbedeckung stammen. Das Relief muss aus tatsächlichen Höhendaten abgeleitet werden.

## Zuerst die vorhandene App untersuchen

Finde die MapLibre-Version, Kartenquelle, Style-Initialisierung, CarPlay-Scene, aktuelle Routing-/GPS-Layer, Kartennamen/Glyphs, POI-Daten und die Kamerasteuerung. Ermittle die echten Source-Layer-Namen und Filterattribute des Kartenproviders. Erfinde weder diese Felder noch einen API-Key oder eine Höhenquelle.

Prüfe, ob ein geeigneter DEM-Dienst mit geklärter Nutzung bereits vorhanden ist. Ohne DEM entsteht der akzeptierte Look nicht. Wenn die Quelle fehlt, benenne genau diese Abhängigkeit; liefere nicht stillschweigend erneut eine flache Karte als fertig aus.

## Umsetzungsreihenfolge

### 1. Landschaft ohne UI

Baue zuerst einen realen Testausschnitt, der Hang, Wald, Fluss und Ort enthält. Kein beliebiger Innenstadt-Ausschnitt als einziger Beleg. Verwende `MapLibre/palette.json` und die Parameter in `Docs/ART-DIRECTION.md` als Ausgangspunkt.

Farben und Landnutzung unter das Relief legen. Hillshade darüber, sodass auch der Wald den Hängen folgt. Wasser danach deckend zeichnen, damit Seeflächen keine durchscheinenden Bergrücken zeigen. Gebäude und Straßen kommen darüber. Feintextur bleibt schwächer als die Reliefschattierung.

`MapLibre/layers.template.json` enthält diese Ebenenfolge mit ausdrücklich unaufgelösten Source-Rollen. `Tools/assemble_style.py` bindet sie nach Ausfüllen der echten Quellen in `source-config.example.json`. Die Vorlage ist kein fertiger Style für einen bestimmten Provider. Der Builder verweigert eine Ausgabe ohne konfigurierte Raster-DEM-Quelle.

Bewahre korrekte Brücken-, Tunnel- und Verkehrswege-Reihenfolge aus dem vorhandenen Providerstil. Die kompakte Vorlage enthält nur die grundsätzliche Straßenhierarchie; ergänze die tatsächlichen Sonderfälle. Flüsse dürfen durch Brücken nicht unterbrochen werden. Straßen und berechnete Routen dürfen nicht auf erfundene Wege gelegt werden.

### 2. Relief visuell abstimmen

Start: map-relative Beleuchtung aus 315°, olivbrauner Schatten, warm kreidiges Highlight, kein neutrales graues oder schwarzes Relief. Die Stärke zoomabhängig reduzieren, wenn man nahe an Straßen heranzoomt. Zuerst bei flacher Kartenneigung abstimmen, damit der gedruckte Kartencharakter erhalten bleibt.

Die einfache Native-Hillshade-Stufe ist ein erster Renderer, kein Nachweis einer exakten Übereinstimmung mit der Illustration. Falls sie bei echter Testgeografie zu glatt wirkt, folge `Docs/RELIEF-PIPELINE.md`: daraus können vorberechnete kartografische Rasterkacheln entstehen. `Tools/render_relief.py` ist ein geprüfter Array-Prototyp für farbiges Relief, kein fertiger Tile-Server. Nicht gleichzeitig starkes Native-Hillshade und vorgerendertes Relief stapeln.

### 3. Beschriftungen und Symbole

Bestehende echte Orts-/Straßennamen verwenden. Gut lesbare Schrift mit dunklem Halo; Ortsnamen in der Übersicht leicht gesperrt, Straßennamen klein und klar. Das Symbol-SVG ist Bearbeitungsquelle, MapLibre bekommt PNG/Atlas. Die Assets sind mehrfarbige Originalgrafiken, kein SDF; keine globale Template-Tönung anwenden.

POIs ungefähr 22–32 logische Pixel, Spieler 44–56, Freunde 28–36. Auf dem echten Display prüfen. Die Leinwand enthält transparenten Rand. Sehr kleine Punkte bei geringer Dichte bevorzugen; Kollisionen und Prioritäten aktiv nutzen. Im Fahrmodus nur wichtige oder routennahe POIs zeigen.

Die Flagge nutzt Bottom-Anchor, der Pfeil Center-Anchor. Fahrzeuge und Richtungspunkte zeigen im Asset nach Norden. Bei `icon-rotation-alignment: map` Kurs nicht zusätzlich um die Kameradrehung korrigieren. Der große offene Fadenkreuz-Overlay bleibt fest im sichtbaren Kartenbereich und erscheint nur beim Verschieben.

### 4. Navigation und CarPlay

Die Route kommt aus dem bestehenden Router und bleibt ein eigener Vektor-Layer über dem Gelände. Spieler/GPS, ETA und Manövertext stammen aus echten App-Daten. Die Zahlen in der Referenz sind nur Vorschautext.

Für Navigation Materialtextur zurücknehmen, Route und nächste Abbiegung hervorheben, Umgebung nicht vollständig entfernen. Die Kamera rückt den Spieler unterhalb der sichtbaren Mitte; oberen Manöverbereich und unteren ETA-Bereich berücksichtigen. Beim manuellen Pan Follow deaktivieren, Fadenkreuz anzeigen; Recenter stellt Follow wieder her.

Die Referenz ist keine Bestätigung, dass beliebige UI-Overlays in jedem CarPlay-Template erlaubt oder möglich sind. Nutze die vorhandenen unterstützten Templates und APIs, prüfe die im Projekt eingesetzte SDK-Version. Die Karte selbst soll dennoch dieselbe Landschaftsgestaltung behalten.

## Sichtbare Abnahme

Erstelle aus der laufenden App drei Ansichten derselben echten Region: Landschaftsübersicht, Ortsnähe und aktive Navigation. Zusätzlich einen flachen Bereich prüfen: dort dürfen keine erfundenen Berge entstehen. Vergleiche mit den beiden Zielbildern nach `Docs/ACCEPTANCE.md`.

Nicht mit einer Dateizählung oder bloß gültigem JSON abschließen. Liefere tatsächliche Renderer-Screenshots, Projektänderungen und ausgeführte Tests. Prüfe iPhone, CarPlay-Simulator, Stilwechsel, Zoom, Drehung, PNG-Skalierung und sichtbare Überlappungen. Kennzeichne fehlende Hardwaretests ehrlich.

Beginne mit dem Kartenuntergrund und arbeite bis zu einem sichtbaren, überprüfbaren Ergebnis weiter. Gib nur dann Rückfragen zurück, wenn im Projekt tatsächlich eine notwendige Quelle oder Zugangsinformation fehlt.
