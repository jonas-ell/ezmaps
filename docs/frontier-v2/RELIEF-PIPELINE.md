# Geländeumsetzung und Grenzen

## Native-Stufe

Der mitgelieferte Style-Baustein nutzt einen `raster-dem`-Source und einen Hillshade-Layer. MapLibre unterstützt dafür Beleuchtungsrichtung, Beleuchtungsanker, Stärke und Farben. Die Vorlage verwendet konservative skalare Werte; zusätzliche neuere Methoden erst nach Prüfung der installierten iOS-SDK-Version aktivieren.

DEM-Encoding muss zur echten Quelle passen (`mapbox`/Terrain-RGB oder `terrarium`). Nicht anhand der Dateiendung raten. RGB-Luftbilder sind keine Höhenkacheln. Auflösung, Abdeckung, Attribution, Nutzung und Offline-Bedingungen der gewählten Quelle klären.

Die Höheninformation wird über den Landnutzungsfarben, aber unter Wasser, Straßen und Symbolen dargestellt. Nicht einfach überall Wald oder Fels über das Relief malen. Bei fehlender Höhendatenabdeckung das Problem erkennen und dokumentieren; keine Berge erfinden.

## Genauere kartografische Rasterstufe

Falls Native-Hillshade den gewünschten gedruckten Reliefcharakter nicht erreicht, kann eine vorberechnete Basis aus echten Daten verwendet werden:

1. DEM und Landbedeckung im selben Zielraster mit korrekt berechneter metrischer Pixelweite vorbereiten. Nachbarn und Wasserflächen einbeziehen.
2. Relief aus DEM erzeugen, mit nordwestlicher Hauptbeleuchtung und schwacher Füllbeleuchtung. Schatten oliv, Highlights kreidig. Mehrere räumliche Maßstäbe nur kontrolliert mischen.
3. Wald/Wiese/Fels nach realen Masken einfärben und die transparenten Materialmuster schwach einmischen. Maßstab der Körnung an Zoomlevel koppeln.
4. Wasser nach dem Relief deckend zeichnen. Glatte Ufer nur entsprechend tatsächlicher Geometrie; keine künstlich runden Seen.
5. Mit ausreichendem Nachbarrand rendern, erst danach auf die finale Tilegröße zuschneiden. Farbabgleich, Metatiling und Kachelränder prüfen. Kein unabhängig normalisierter Kontrast pro Kachel.
6. Diese Basis als Rasterkachelquelle laden. Straßen, Namen, Route, Spieler und POIs bleiben darüber dynamische Vektoren. Wenn die Basis bereits vollständiges Relief enthält, Native-Hillshade deaktivieren.

`Tools/render_relief.py` demonstriert ausschließlich Schritt 2 auf einem endlichen Höhenarray. Voraussetzungen: NumPy und Pillow; Input `.npy`, Höhen in Metern, bekannte lokale quadratische Pixelweite. Es schreibt eine transparente PNG-Schattierung. Es implementiert weder Projektion noch Tile-Schnitt, Datenabruf, Nodata-Behandlung oder einen Server. Der Code muss für eine geografische Produktionspipeline ergänzt werden. Bei Web-Mercator die maßstabsabhängige lokale Meterweite berücksichtigen.

## Datenlücken

Dieses ZIP enthält keine echte globale Höhen-/Landbedeckungsdatenbank, kein Routing und keine Zugangsdaten. Die beiden Zielbilder sind visuelle Referenzen mit erfundener Landschaft. Der endgültige Grad der Übereinstimmung kann erst anhand einer gerenderten echten Region beurteilt werden.

## Geprüfte Primärdokumentation (29.10.2026)

- https://maplibre.org/maplibre-style-spec/layers/#hillshade
- https://maplibre.org/maplibre-style-spec/sources/#raster-dem
- https://maplibre.org/maplibre-style-spec/sprite/

Die konkreten Parameter und Source-Formate der installierten SDK-Version erneut prüfen, bevor die App gebaut wird.
