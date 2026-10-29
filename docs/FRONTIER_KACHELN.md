# Frontier: gemalte Kartenkacheln

Ziel: Frontier sieht aus wie eine gemalte Geländekarte (Zielbilder in `docs/frontier-v2/`). Linien, Flächen und Relief in MapLibre schaffen das nicht und ruckeln (GM-072). Deshalb wird die Landschaft vorher als Bild berechnet. Die App zeigt nur noch Bildkacheln, darüber wie bisher Straßen, Namen und Route als Vektoren.

## Bausteine

| Baustein | Stand |
|---|---|
| Höhen: Copernicus DEM GLO-30 (30 m) | `tools/terrain/fetch_data.py`, Ordner `C:\Users\jonas\EzMapsData\dem` |
| Bodenbedeckung: ESA WorldCover 2021 (10 m) | gleiches Skript, Ordner `EzMapsData\worldcover` |
| Rechen-Skript | `tools/terrain/render_tiles.py` (Platzhalter-Materialien, bis Codex liefert) |
| Gemalte Materialien | **fehlen** – Prompts unten, Ablage `tools/terrain/materials/<name>.png` |
| Speicher im Netz | **fehlt** – Cloudflare-Konto des Nutzers (R2-Bucket + öffentliche Domain) |
| App | Frontier-Stil auf Rasterquelle umstellen, sobald Kacheln online sind |

Datenordner liegt außerhalb von OneDrive und Repo (mehrere GB).

## Befehle

```
python tools/terrain/fetch_data.py test                        # nur Taunus
python tools/terrain/fetch_data.py germany                     # ganz Deutschland
python tools/terrain/render_tiles.py preview                   # docs/frontier-v2/kacheln-z11/12/14.jpg
python tools/terrain/render_tiles.py tiles 6 14                # Deutschland, Zoom 6–14 → EzMapsData/tiles
python tools/terrain/render_tiles.py tiles 10 14 7.8,49.9,8.8,50.5   # nur ein Ausschnitt
```

Kacheln: 512 × 512 px, JPEG. Über Zoom 14 vergrößert die App die Kacheln. Die Daten haben 30 m und 10 m Auflösung, mehr Schärfe gibt es dort nicht.

## Quellenhinweise (Pflicht, in der App unter der Karte bei Frontier)

- Höhen: „© DLR e.V. 2010–2014 und © Airbus Defence and Space GmbH 2014–2018, bereitgestellt unter COPERNICUS von der Europäischen Union und der ESA“ (Copernicus DEM GLO-30, Lizenz erlaubt kommerzielle Nutzung mit Hinweis)
- Bodenbedeckung: „© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium“ (CC BY 4.0)
- Weiterhin: „© OpenMapTiles · © OpenStreetMap-Mitwirkende“ für Straßen und Namen

## Codex-Prompts für die Materialien

Gemeinsamer Teil (vor jeden Prompt setzen):

> Erstelle eine **nahtlos kachelbare** quadratische Textur, 1024 × 1024 px, PNG ohne Transparenz. Senkrechte Draufsicht aus etwa 1–2 km Höhe, wie ein Ausschnitt einer **handgemalten Geländekarte** (Gouache/Öl, matte warme Farben, feine unregelmäßige Pinselstruktur). **Kein Licht und keine Schatten aus einer Richtung** – das Relief wird später berechnet und darübergelegt. Keine Objekte, keine Straßen, keine Schrift, keine Ränder, keine Vignette. Die Kanten müssen links/rechts und oben/unten exakt ineinander übergehen (bitte mit 2 × 2 nebeneinandergelegt prüfen). Keine sichtbaren Wiederholungen innerhalb der Kachel, keine großen Einzelflecken. Eigene Gestaltung, nichts aus Spielen übernehmen. Liefere zusätzlich eine Vorschau mit 3 × 3 Kacheln.

1. **forest.png** – dichter Mischwald von oben: viele kleine runde Baumkronen in Oliv- bis Tannengrün (Grundton #4F6230, Spitzlichter #8C9A55, Tiefen #2E3A1B), Kronen gleichmäßig dicht, keine Lichtungen, kein Boden sichtbar.
2. **meadow.png** – Wiese und Weide: weiche Flecken aus Grün und Khaki (Grundton #86924E, Flecken #6E8040 und #B0A66E), feines Gras-Korn, sehr ruhig.
3. **field.png** – Ackerland: zarte Feld-Streifen in Sand- und Ockertönen (Grundton #ADA36A, Streifen #C2B57A und #8F8A55), Streifen leicht schräg und unregelmäßig breit, keine harten Linien.
4. **rock.png** – kahler Fels und Geröll: kreidig warm (Grundton #B7AD85, helle Kanten #D5CAA6, Risse #8A8060), körnig, ohne Höhenwirkung.
5. **shrub.png** – Buschland und Heide: lockere dunkle Büsche auf Khaki (Grundton #707840, Büsche #4E5A2C).
6. **wet.png** – Feuchtwiese und Moor: grünlich-graue Flächen mit kleinen dunklen Wasserflecken (Grundton #627654, Wasser #556B66).
7. **built.png** – Siedlungsfläche von weitem: warmes Grau-Beige mit sehr feinen dunklen Punkten und Gärtengrün (Grundton #968C68), keine einzelnen Häuser erkennbar.
8. **water.png** – ruhiges Wasser: blasses Graublau (Grundton #86A6AC), kaum Struktur, ganz leichte waagerechte Pinselzüge, keine Wellenzeichen.
9. **snow.png** – Schnee und Eis: gebrochenes Weiß (Grundton #ECECE4) mit kühlen grauen Schlieren.

Abgabe: Dateien in `tools/terrain/materials/` (Namen wie oben), dazu die 3 × 3-Vorschauen in `tools/terrain/materials/vorschau/`.

## Nächste Schritte

1. Codex liefert die 9 Materialien → `render_tiles.py preview` neu, mit den Zielbildern vergleichen.
2. Nutzer legt ein Cloudflare-Konto an: R2-Bucket `ezmaps-tiles`, öffentlicher Zugriff über eine eigene Subdomain oder `r2.dev`. Zugangsschlüssel nie ins Repo.
3. Kacheln für Deutschland rechnen (Zoom 6–14) und hochladen.
4. `build_style.py` Frontier: Rasterquelle statt Hintergrund, Relief und Flächen. Straßen, Gebäude, Namen, Route bleiben Vektoren.
