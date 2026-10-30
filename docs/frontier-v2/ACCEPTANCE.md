# Visuelle Abnahme statt bloßer Asset-Integration

## Referenzvergleich

Vergleiche gerenderte App-Ansichten mit den Zielbildern bei ähnlichem Maßstab und identischer Displaygröße. Erwartet wird die gleiche grafische Sprache, nicht identische Geografie.

| Prüfung | Bestanden, wenn … |
|---|---|
| Gelände | Hänge/Täler bereits ohne Straßen erkennbar sind und echten Höhen folgen |
| Wald | Bewuchs zusammenhängend wirkt, Hänge darunter lesbar bleiben, keine Stickerbäume |
| Straßen | die Übersicht von der Landschaft geprägt ist, die aktive Route aber sofort erkennbar bleibt |
| Wasser | Ufer natürlich und Wasser ruhig erscheinen; kein Relief im See durchscheint |
| Symbole | 24–32px-Zeichen über Wald, Fels und Wasser erkennbar bleiben |
| Textur | keine periodischen Nähte, diagonalen Streifen oder großen Flecken auffallen |
| Maßstab | näherer Zoom mehr Orientierung bietet und nicht nur Material vergrößert |
| Navigation | nächste Abbiegung, Spieler und Routenkontinuität sofort erkennbar sind |
| Rotation | Marker-Kurs und Kamera korrekt zusammenspielen; Relieflicht nicht springt |

## Zu liefernde Implementierungsnachweise

1. Reale Hügellandschaft mit Wald, Fluss, Ort: ohne UI und mit Navigation.
2. Innenstadt: Labels und Kreuzungen dürfen nicht in der Textur verschwinden.
3. Flaches Gelände: keine künstlichen Berge; der Stil bleibt über Farbe und Materialien erkennbar.
4. CarPlay-Simulator und iPhone: tatsächliche Ansichten, nicht die Konzept-PNGs als Screenshot ausgegeben.
5. Stilwechsel, @2x/@3x-Skalierung, Kursdrehung, Pan/Recenter, Zielflaggenanker, POI-Kollisionen.

Die Vorschauzahlen und Freundespositionen sind keine Datenquelle. Assets nicht als SDF einfärben. Die 1024-Master bleiben außerhalb des laufenden Kartensprites. Die Beispieldatenkonfiguration muss echte Providerwerte erhalten.
