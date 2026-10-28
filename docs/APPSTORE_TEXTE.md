# App-Store-Texte (Entwurf, GM-020)

Keine Spielnamen, keine Spielmarken, keine „wie in …“-Vergleiche (Markenrecht, App-Review-Regel 4.1 / 5.2).
Keine Blitzer-Hinweise. Screenshots nur aus der echten App (Simulator oder Gerät), nicht aus dem Prototyp.

## Deutsch (Hauptsprache)

- **Name (max. 30):** EzMaps: Game Maps
- **Untertitel (max. 30):** Navi im Open-World-Look
- **Werbetext (max. 170):** Deine Stadt sieht aus wie eine Spielwelt: dunkle Karte, Neon-Route, klare Ansagen. Echte Navigation für ganz Europa, auf dem iPhone und in CarPlay.
- **Schlüsselwörter (max. 100, Komma ohne Leerzeichen):** navi,navigation,carplay,karte,route,stadtplan,tempolimit,neon,spiel,openstreetmap,auto,ansage
- **Beschreibung:**

  EzMaps macht aus deiner Umgebung eine Open-World-Karte und navigiert dich trotzdem zuverlässig ans Ziel.

  • Karte „Neon City“: dunkles Land, helle Straßen, lila Route
  • Suche nach Adressen, Orten und Geschäften in ganz Europa
  • Bis zu drei Routen zur Auswahl, Autobahn oder Maut meiden
  • Abbiegehinweise mit Sprachansagen, Musik wird dabei nur leiser
  • Tempolimit-Anzeige aus OpenStreetMap
  • Automatische Neuberechnung, wenn du anders fährst
  • CarPlay: Ziele, Suche, Routen-Vorschau und Navigation im Auto
  • Kein Konto, keine Werbung, kein Tracking

  Kartendaten © OpenStreetMap-Mitwirkende. Bitte achte immer auf den Verkehr; Verkehrszeichen gehen vor.

## Englisch

- **Name:** EzMaps: Game Maps
- **Subtitle:** Navigation, open-world style
- **Promotional text:** Your city looks like a game world: dark map, neon route, clear voice guidance. Real navigation across Europe, on iPhone and in CarPlay.
- **Keywords:** navigation,carplay,map,route,directions,speed limit,neon,game,openstreetmap,car,drive
- **Description:** wie oben, übersetzt (Hinweis: Ansagen sind in Version 1.0 auf Deutsch).

## Hinweise für die App-Prüfung (App Review Notes)

> EzMaps is a turn-by-turn navigation app for cars (iPhone and CarPlay). No account is needed.
> To test without driving: open Settings (gear icon) → enable "Demo drive", then search a destination (e.g. "Frankfurt Römerberg"),
> tap "Go". The route is driven automatically with voice guidance. In CarPlay (Simulator: I/O → External Displays → CarPlay),
> tap "Destinations" → "Search". Map data © OpenStreetMap contributors; tiles OpenFreeMap; routing Valhalla; search Photon.
> Location is only used for map display and navigation (background location only while navigating).

## Fragen in App Store Connect

- **Datenschutz („App-Datenschutz“):** Gesammelt: *Genauer Standort* und *Suchverlauf* – Zweck *App-Funktionalität*, **nicht** mit der Identität verknüpft, **kein** Tracking. (Passt zu `App/PrivacyInfo.xcprivacy`.)
- **Altersfreigabe:** 4+ (keine der Kategorien zutreffend)
- **Kategorie:** Navigation (Neben: Reisen)
- **Export-Compliance:** nur HTTPS → `ITSAppUsesNonExemptEncryption = NO` (steht in `project.yml`)
- **Datenschutz-URL / Support-URL:** `https://jonas-ell.github.io/ezmaps/legal/` (nach Aktivieren von GitHub Pages)
