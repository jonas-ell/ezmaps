# Kartendaten, Routing und Suche für ganz Deutschland

Stand GM-015. Alles beruht auf OpenStreetMap (ODbL) – Hinweis „© OpenStreetMap-Mitwirkende“ immer sichtbar.

## Warum nicht die Kacheln von openstreetmap.org?

Die Server von openstreetmap.org sind für die Bearbeitung der Karte gedacht. Ihre Nutzungsregeln (Tile Usage Policy)
verbieten starke Nutzung durch Apps. Außerdem liefern sie fertige Bilder im OSM-Look, unsere Stile brauchen aber Rohdaten (Vektorkacheln).

## Kacheln – Möglichkeiten

| Anbieter | Art | Kosten | Einsatz |
|---|---|---|---|
| **OpenFreeMap** (tiles.openfreemap.org) | Vektorkacheln, OpenMapTiles-Schema, ganze Welt | kostenlos, kein Schlüssel, Spenden | **Prototyp (jetzt)**; für die App möglich, aber ohne Zusage für Verfügbarkeit |
| **Eigene PMTiles-Datei** (Protomaps / Planetiler) | eine Datei mit ganz Deutschland (ca. 2–4 GB), auf Cloudflare R2 / S3 | ein paar Euro im Monat | **Empfehlung für die App**: volle Kontrolle, auch offline auf dem Gerät nutzbar |
| MapTiler Cloud | Vektorkacheln + Hosting | Gratis-Stufe, danach monatlich | wenn wir nichts selbst betreiben wollen |
| Stadia Maps | Vektorkacheln + Hosting | Gratis-Stufe für kleine Apps | wie MapTiler |
| VersaTiles | freie Vektorkacheln, Projekt aus Deutschland | kostenlos / selbst hosten | Alternative zu OpenFreeMap |

In der App zeichnet **MapLibre Native** die Kacheln mit unseren Stil-JSONs (Neon, Wild West). Toy Town und Pixel Quest brauchen
eigene Ebenen (Metal) oder vorab gezeichnete Rasterkacheln – im Prototyp zeichnet `js/map.js` alle vier Stile aus denselben Daten.

## Routing

| Dienst | Kosten | Einsatz |
|---|---|---|
| **Valhalla FOSSGIS** (valhalla1.openstreetmap.de) | kostenlos, nur faire Nutzung | **Prototyp (jetzt)** – nicht für die fertige App |
| Eigener Valhalla-Server (Deutschland) | ein Server ca. 20–40 €/Monat | **Empfehlung**; liefert auch Tempolimits (`trace_attributes`) |
| Valhalla auf dem Gerät | einmalig Daten laden | offline, später |
| GraphHopper / OSRM | selbst hosten oder gemietet | Alternativen |

Tempolimits kommen aus OSM `maxspeed` über Valhalla `trace_attributes` (`edge.speed_limit`; „unlimited“ = Autobahn ohne Limit).

## Suche

| Dienst | Kosten | Einsatz |
|---|---|---|
| **Photon** (photon.komoot.io) | kostenlos, faire Nutzung | **Prototyp (jetzt)** |
| Eigener Photon-Server | Server | Empfehlung für die App |
| Apple MapKit (`MKLocalSearch`) | kostenlos in iOS | gute Alternative in der App (Adressen, Geschäfte) |
| Nominatim (openstreetmap.org) | – | **nicht** für Apps erlaubt (Nutzungsregeln) |

## Prototyp – wie es zusammenhängt

- `js/tiles.js` wählt je Ansicht Zoomstufe und Schärfe, lädt Kacheln von OpenFreeMap über 3 Hintergrund-Worker
- `js/mvt.js` liest die Vektorkacheln (Protobuf), `js/vtscene.js` macht daraus dieselbe Szene wie `data/idstein.json`
- `js/map.js` zeichnet die Szene im aktuellen Stil; beim Stilwechsel werden die Kacheln neu gezeichnet
- `js/valhalla.js`: Routen, Alternativen, Tempolimits, Neuberechnung (Knopf „Falsch abbiegen“ oben)
- Idstein bleibt die genaue Karte mit Relief und Nebel des Krieges; außerhalb übernehmen die Kacheln
