"""Erzeugt App/MapStyles/style-*.json (MapLibre-Stile) aus den Werten des Prototyps – GM-043: alle 5 Stile
(Klassik, Neon City, Wild West, Pixel Quest, Toy Town).

Quelle der Werte: tools/prototype/js/map.js – CLASSIC, NEON, WESTERN, PX (Pixel), TOY, WIDTH, MIN_PX, widen.
Die Prototyp-Texturen (Papier, Pixel-Raster, Spielteppich) gibt es in MapLibre nicht; die Stile übernehmen die Farben.
Mirror in tools/prototype/js/map.js – change both.

Straßenbreiten im Prototyp sind in Metern (wachsen mit dem Zoom), aber nie dünner als MIN_PX Bildpunkte.
MapLibre rechnet in Pixeln je Zoomstufe: px = Meter / (Meter pro Pixel). Bei 512-px-Kacheln und ~50,5° Breite
(Mitte Deutschland) gilt Meter pro Pixel = 40075016 · cos(50,5°) / (512 · 2^z) ≈ 49786 / 2^z.

Aufruf: python tools/maplibre/build_style.py
"""
import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "App" / "MapStyles"

# --- aus js/map.js (NEON) ---
# GM-024: nach Foto des Nutzers (CarPlay-Vorlage): mittelgrauer Boden, Häuser heller als der Boden,
# fast weiße Straßen mit dunklem Rand, Straßennamen dunkel auf der Straße
# GM-045: Übersicht (weit weg) nach zweitem Bild des Nutzers (Pausenkarte eines Open-World-Spiels): fast schwarzer Boden,
# dünne graue Straßen ohne Rand, farbige Symbole. Ab Zoom 14,5 (Fahrt, CarPlay) unverändert wie das Foto. Dazwischen fließend.
def zc(far, near, z0=12, z1=14.5):
    return ["interpolate", ["linear"], ["zoom"], z0, far, z1, near]
# GM-048: alle Zoomstufen nach den Pausenkarten-Bildern des Nutzers (Farben gemessen): Boden #181818, Häuser #363636,
# Straßen flach #969696 ohne hellen Rand (Rand = Bodenfarbe, wirkt wie die Lücke zwischen Straße und Häusern), Wasser hellgrau.
# Weit weg kleine Straßen dunkler (sonst unruhig, GM-047).
NEON = dict(land="#181818", residential="#1b1b1b", industrial="#1d1d1d", farm="#181818", park="#1c1d1c", forest="#1a1b1a",
            water="#6a6a6a", building="#363636", buildingEdge="#363636", urban="#181818", rail="#2c2c2c",
            casing="#181818", label="#141414", poi_suffix="-neon", poi_minzoom=13.5,
            place_color="#ffffff", place_halo="#000000", place_halo_width=1.8)
NEON.update(road=lambda r: zc("#a0a0a0" if r <= 1 else "#8a8a8a" if r <= 2 else "#6c6c6c" if r <= 4 else "#575757", "#969696"),
            widen=1.5, label_halo=None)
CLASSIC = dict(land="#f2efe9", residential="#ece7e0", industrial="#ebe3e8", farm="#eef0d6", park="#d4ebc8", forest="#c3dfb4",
               water="#aad3df", building="#ddd5cc", buildingEdge="#cbc0b5", rail="#a3a3a3", casing="#c9c1b6", label="#4a4a4a",
               road=lambda r: "#f7c56b" if r <= 1 else "#fde7a6" if r <= 3 else "#ffffff", widen=1.15, label_halo="#ffffff")
# GM-057: Wild West nach den Red-Dead-Karten des Nutzers (Zielbild Runde 3, Farben gemessen): helles Pfirsich-Papier,
# Straßen nur dünne dunkelbraune Linien, Wasser graugrün mit weichem Rand, Häuser kaum sichtbar, Schrift Old Standard TT (OFL).
WESTERN = dict(land="#e4c9a8", residential="#e4c9a8", industrial="#e0c4a2", farm="#e4c9a8", park="#dec5a2", forest="#dcc29e",
               water="#aaa392", building="#ddc19c", buildingEdge="#b89a74",  # GM-072: Häuser sichtbar
               # GM-072: Wohn-, Gewerbe-, Feld- und Parkflächen mit Papier (vorher harte helle Flecken), weit weg weniger Straßen
               pat=dict(land="ez-pat-paper-west", forest="ez-pat-forest-west", water="ez-pat-water-west", residential="ez-pat-paper-west",
                        industrial="ez-pat-paper-west", farm="ez-pat-paper-west", park="ez-pat-paper-west"),
               minzoom_shift={"secondary": 11, "tertiary": 12.5, "minor": 14, "service": 15.5}, rail_minzoom=11,
               # GM-072: Name neben der Linie (sonst Linie zwischen den Buchstaben = Punkte)
               road_label_offset=[0, -0.85], rail="#4a3b2c", casing="#4a3b2c", label="#4a3b2c",
               road=lambda r: "#4a3b2c", widen=1.0, ink_lines={0: 3.2, 1: 3.0, 2: 2.6, 3: 2.2, 4: 1.8, 5: 1.3, 6: 1.0, 7: 0.8},
               water_soft=True, rail_ticks=True, label_halo="#e4c9a8", label_halo_width=2,
               font="Old Standard TT Regular", label_scale=0.85, letter_spacing=0.18,
               poi_suffix="-west", poi_minzoom=13.5, place_spacing=0.2, place_color="#3a2d20", place_halo="#e4c9a8")
# GM-050: Pixel Quest und Toy Town wieder eigenständig wie im Prototyp (js/map.js drawPixel/drawToy, docs/previews/c4-*):
# eigene Muster (Bilder zeichnet die App: RouteOverlay.patternImages, Website: js/poi.js), eigene Schrift, eigene Symbole.
# Nutzer: „du kannst die Maps doch nicht alle im selben Stil machen“.
def building_layers(P, steps=(7, 10, 14)):
    """GM-059: je Höhenbereich eine eigene Ebene mit festem Muster – MapLibre auf dem iPhone zeichnete Muster-Ausdrücke
    lückenhaft (Gras schien durch die Häuser, Nutzer-Screenshot). Erste Ebene heißt „building“ (Prüfskripte)."""
    pats, out, lo = P["building_pattern"], [], None
    bounds = [None, *steps, None]
    h = ["coalesce", ["get", "render_height"], 0]
    for i, pat in enumerate(pats):
        f = ["all"]
        if bounds[i] is not None: f.append([">=", h, bounds[i]])
        if bounds[i + 1] is not None: f.append(["<", h, bounds[i + 1]])
        out.append(fill("building" if i == 0 else f"building-{i}", "building", P["building"], f if len(f) > 1 else None,
                        {"fill-outline-color": P["buildingEdge"]}, pattern=pat))
    return out


def by_height(values, steps=(7, 10, 14)):
    """Wert je Gebäude nach Höhe. Die Kacheln fassen gleich hohe Nachbarhäuser zu einem Objekt zusammen – nach ID
    verteilt bekam deshalb fast die ganze Stadt dieselbe Farbe (GM-050, im Browser gemessen)."""
    e = ["step", ["coalesce", ["get", "render_height"], 0], values[0]]
    for h, v in zip(steps, values[1:]): e += [h, v]
    return e
# GM-050: Pixel Quest als Blockwelt (Nutzer-Bilder „Minecraft-Karte im Auto“): Gras-Block-Textur, graue Steinstraßen,
# Häuser als Holz/Stein/Ziegel-Blöcke mit Block-Schatten, Blätterwald, Wasser-Textur, weiße Pixelschrift mit schwarzem Schatten.
# Alle Texturen selbst gezeichnet (StylePatterns), keine Spiel-Texturen.
PIXEL = dict(land="#5d9b37", residential="#5d9b37", industrial="#8a8a8a", farm="#b59a45", park="#5d9b37", forest="#2f6b22",
             water="#3f76e4", building="#8b6a3e", buildingEdge="#3b2a17", rail="#5a4632", casing="#3c3c3c", label="#ffffff",
             road=lambda r: "#8f8f8f", widen=1.2, label_halo="#000000",
             pat=dict(land="ez-pat-grass-px", residential="ez-pat-grass-px", forest="ez-pat-leaves-px", park="ez-pat-grass-px",
                      water="ez-pat-water-px", farm="ez-pat-farm-px", industrial="ez-pat-stone-px"),
             road_pattern="ez-pat-road-px", rail_pattern="ez-pat-rail-px",
             far_simple=True, minzoom_shift={"tertiary": 12, "minor": 13.5, "service": 15},
             building_pattern=["ez-pat-oak-px", "ez-pat-spruce-px", "ez-pat-brick-px", "ez-pat-cobble-px"],
             building_shadow=True, block_edges=("#2a1d0e", "#d2a868"),
             # GM-073: Nutzer „die Häuser-Kacheln dürfen nie zu sehen sein, immer ein hochgezogenes 3D-Modell“ – jedes Gebäude ist ein Block
             # (Höhe in 4-m-Schritten, mindestens 1 Block), Holz/Fichte/Ziegel/Bruchstein nach Höhe; Villager-Bilder raus (bis 3D-Modelle kommen)
             extrude=[(0, 8, "ez-pat-oak-px"), (8, 12, "ez-pat-spruce-px"), (12, 20, "ez-pat-brick-px"), (20, None, "ez-pat-tower-px")],  # GM-078: echte Höhen, Hochhäuser Glas
             roofs=[((0, 20), "ez-pat-roof-px"), ((20, None), "ez-pat-slab-px")], roof_alt=("ez-pat-roof2-px", 3),  # GM-081: jedes 3. Haus Schiefer
             road_pattern_near=True,
             poi_scale=1.6, poi_near=1.8,  # GM-079: Items größer (Nutzer: „das Chicken muss größer sein“)
             extrude_only=True, extrude_minzoom=15, extrude_far=(13, "#7a5a32"),  # GM-075: ruckelte – unter Zoom 15 einfarbig
             label_spacing=420, casing_add=(0.8, 0.8), water_line_pattern="ez-pat-water-px",
             zoom_patterns=["ez-pat-grass-px", "ez-pat-leaves-px", "ez-pat-farm-px", "ez-pat-stone-px"],  # GM-072: Blöcke wachsen beim Zoomen
             # GM-067: weit weg flach wie eine Karte im Spiel – Felder, Dächer, Industrie ohne Muster (Streifen und Krümel)
             far_flat=13.5, far_flat_ids=["farm", "industrial", "building", "building-1", "building-2", "building-3"], building_minzoom=13,
             font="Press Start 2P Regular", label_scale=0.5, text_transform="none", letter_spacing=0, label_halo_width=1.6,
             poi_suffix="-px", poi_minzoom=14, place_color="#ffffff", place_halo="#000000", place_halo_width=2, place_transform="none")
TOY = dict(land="#8dc63f", residential="#8dc63f", industrial="#cfd0d2", farm="#b9d86a", park="#7cc142", forest="#62b235",
           water="#4ab0ea", building=by_height(["#e3412f", "#ef7d2d", "#3d78c9", "#8b8f96"]),
           buildingEdge="#2f3640", rail="#2f3640", casing="#c9cbce", label="#ffffff",
           road=lambda r: "#66686c", widen=1.4, label_halo="#2f3640",
           # GM-073: echte Spielteppiche sind flach bedruckt – keine sich wiederholenden Kacheln mehr, Bäume einzeln am Waldrand
           tree_edges=dict(image="toy-tree", spacing=34, size=["interpolate", ["linear"], ["zoom"], 13, 0.35, 16, 0.6, 18, 0.9]),
           house_icons=dict(image=["step", ["coalesce", ["get", "render_height"], 0],
                                   ["match", ["%", ["to-number", ["id"], 0], 6], 0, "toy-house-1", 1, "toy-house-2", 2, "toy-house-3",
                                    3, "toy-house-4", 4, "toy-house-5", "toy-house-6"],
                                   10, ["match", ["%", ["to-number", ["id"], 0], 3], 0, "toy-shop", 1, "toy-school", "toy-police"],
                                   14, "toy-apartment"],
                            size=["interpolate", ["exponential", 1.6], ["zoom"], 15, 0.4, 17, 0.75, 19, 1.9, 20, 2.8]),  # GM-075: nah mitwachsen
           water_edge="#f2d48b", road_dash="#ffffff", building_ink="#2f3640",
           textile=("toy-tex-weave", 0.75),  # GM-071: Teppich-Flor über allem (Nutzer: „wirkliche Teppich-Grafiken mit Textil-Details“)
           font="Fredoka Bold", label_scale=1.05, text_transform="none", letter_spacing=0.02, label_halo_width=2,
           poi_suffix="-toy", poi_minzoom=14, place_color="#ffffff", place_halo="#2f3640", place_halo_width=2.4, place_transform="none")

# GM-068: Frontier (Paket ezmaps-frontier-v2, docs/frontier-v2): gedruckte Feldkarte mit echtem Relief aus Höhendaten,
# oliv/khaki, dichter Wald, blasses Wasser mit dunklem Ufer, schmale Sandstraßen, kleine helle Zeichen, Route Amber.
# Höhen: Terrain Tiles (AWS Open Data, Terrarium) – Quellen-Hinweis in der Attribution.
# GM-069: Nutzer „soll wie eine gemalte Open-World-Geländekarte aussehen“ – Grün satter, Wald tiefer, Wasser kühler, Relief kräftiger
FRONTIER = dict(land="#9C9A5E", residential="#9C9A5E", industrial="#B0A274", farm="#ADA36A", park="#86924E", forest="#4F6230",
                water="#86A6AC", building="#4A4630", buildingEdge="#4A4630", rail="#69613F", casing="#69613F", label="#F4E7C2",
                road=lambda r: "#D5C38C", widen=1.0, label_halo="#303121", label_halo_width=1.6,
                rock="#B7AD85", water_bank="#666F4A",
                # Breiten in px je Zoom 8/12/15/18 (ART-DIRECTION Maßstäbe), Rand je Seite 0,8 px
                road_px={0: (1.2, 2.0, 3.4, 6.5), 1: (1.1, 1.8, 3.1, 6.0), 2: (1.0, 1.5, 2.8, 5.5), 3: (0.7, 1.2, 2.3, 4.6),
                         4: (0.5, 1.0, 2.0, 4.0), 5: (0.4, 0.8, 1.5, 3.3), 6: (0.3, 0.6, 1.2, 2.6), 7: (0.2, 0.5, 1.0, 2.2)},
                # GM-075: ruckelte weiter – nur noch Wald-Körnung, kein Vollbild-Papierkorn (bis die gemalten Kacheln kommen)
                overlays=[],  # GM-076: auch Wald-Körnung raus (Ruckeln)
                relief=dict(tiles="https://elevation-tiles-prod.s3.amazonaws.com/terrarium/{z}/{x}/{y}.png", maxzoom=11, minzoom=8,  # GM-080: ganz weit weg ruckelte es  # GM-076: vorher 15 – jede Kachel neu laden und schattieren ruckelte extrem
                            attribution="Höhen: <a href=\"https://registry.opendata.aws/terrain-tiles/\">Terrain Tiles</a> (SRTM, EU-DEM u. a.)",
                            exaggeration=["interpolate", ["linear"], ["zoom"], 7, 1.0, 12, 1.0, 15, 0.8, 18, 0.45],  # Vorgabe 0,65–0,8: im Taunus zu flach
                            shadow="#232B14", highlight="#EADFB8", accent="#4E4A26"),
                overlay_opacity={"forest": ["interpolate", ["linear"], ["zoom"], 8, 1, 14, 0.95, 17, 0.6]},
                poi_scale=1.0, building_opacity=0.72,
                minzoom_shift={"minor": 12.5, "service": 14.5},
                font="Barlow Condensed SemiBold", label_scale=0.95, letter_spacing=0.06, text_transform="none",
                poi_suffix="-fv2", poi_minzoom=13, place_color="#F4E7C2", place_halo="#303121", place_halo_width=1.8, place_spacing=0.18)

WIDTH = {0: 16, 1: 13, 2: 12, 3: 10, 4: 9, 5: 7, 6: 6, 7: 3.5}       # Meter
MIN_PX = {0: 4.4, 1: 3.6, 2: 3, 3: 2.4, 4: 2, 5: 1.4, 6: 1.2, 7: 1}   # Bildpunkte
WIDEN, URBAN_REACH = 1.5, 46
CLASS_RANK = {"motorway": 0, "trunk": 1, "primary": 2, "secondary": 3, "tertiary": 4, "minor": 5, "service": 7}  # wie js/vtscene.js

MPP0 = 40075016 * math.cos(math.radians(50.5)) / 512


def meters(m, min_px=0.0, z0=4, z1=22):
    """Breite in Metern als MapLibre-Ausdruck, nie dünner als min_px."""
    stops = []
    for z in range(z0, z1 + 1):
        stops += [z, round(max(m * 2 ** z / MPP0, min_px), 3)]
    return ["interpolate", ["exponential", 2], ["zoom"], *stops]


def fill(id_, layer, color, flt=None, extra=None, pattern=None):
    l = {"id": id_, "type": "fill", "source": "openmaptiles", "source-layer": layer, "paint": {"fill-color": color, "fill-antialias": True}}
    if flt: l["filter"] = flt
    if extra: l["paint"].update(extra)
    if pattern: l["paint"]["fill-pattern"] = pattern  # GM-050
    return l


def line(id_, layer, color, width, flt=None, cap="round"):
    l = {"id": id_, "type": "line", "source": "openmaptiles", "source-layer": layer,
         "layout": {"line-cap": cap, "line-join": "round"}, "paint": {"line-color": color, "line-width": width}}
    if flt: l["filter"] = flt
    return l


def build(P, title):
    """Ebenen für eine Palette P (Mirror der Zeichenreihenfolge in js/map.js drawClassic)"""
    pat = P.get("pat", {})
    land = {"id": "land", "type": "background", "paint": {"background-color": P["land"]}}
    if pat.get("land"): land["paint"]["background-pattern"] = pat["land"]
    layers = [
        land,
        fill("farm", "landcover", P["farm"], ["==", ["get", "class"], "farmland"], pattern=pat.get("farm")),
        fill("forest", "landcover", P["forest"], ["==", ["get", "class"], "wood"], pattern=pat.get("forest")),
        fill("grass", "landcover", P["park"], ["==", ["get", "class"], "grass"], pattern=pat.get("park")),
        *([fill("rock", "landcover", P["rock"], ["in", ["get", "class"], ["literal", ["rock", "sand"]]])] if P.get("rock") else []),
        fill("park", "park", P["park"], pattern=pat.get("park")),
        fill("residential", "landuse", P["residential"], ["in", ["get", "class"], ["literal", ["residential", "suburb", "neighbourhood"]]], pattern=pat.get("residential")),
        fill("industrial", "landuse", P["industrial"], ["in", ["get", "class"], ["literal", ["industrial", "commercial", "retail", "railway", "garages"]]], pattern=pat.get("industrial")),
        fill("landuse-green", "landuse", P["park"], ["in", ["get", "class"], ["literal", ["cemetery", "pitch", "playground", "park", "zoo"]]], pattern=pat.get("park")),
        fill("water", "water", P["water"], ["!=", ["get", "class"], "swimming_pool"], pattern=pat.get("water")),
        line("river", "waterway", P["water"], meters(9, 1), ["in", ["get", "class"], ["literal", ["river", "canal"]]]),
        line("stream", "waterway", P["water"], meters(3, 0.6), ["!", ["in", ["get", "class"], ["literal", ["river", "canal"]]]]),
        # GM-050: Block-Schatten (Pixel Quest) – dunkle Kopie leicht versetzt, wirkt wie ein Block von oben
        *([fill("building-shadow", "building", "rgba(0,0,0,0.38)", None, {"fill-translate": ["interpolate", ["exponential", 2], ["zoom"], 14, ["literal", [1, 1]], 18, ["literal", [9, 9]]],
                                                                                    "fill-antialias": False})] if P.get("building_shadow") else []),
        *(building_layers(P) if isinstance(P.get("building_pattern"), list) else
          [fill("building", "building", P["building"], None, {"fill-outline-color": P["buildingEdge"]}, pattern=P.get("building_pattern"))]),
        line("rail", "transportation", P["rail"], meters(1.5, 1), ["in", ["get", "class"], ["literal", ["rail", "transit"]]], cap="butt"),
    ]
    # Straßen: erst alle dunklen Ränder, dann die hellen Flächen (so verschmelzen Kreuzungen sauber), große obenauf
    order = sorted(CLASS_RANK.items(), key=lambda kv: -kv[1])
    widen = P["widen"]
    thin = P.get("thin_minor", False)  # Wild West: kleine Straßen als dünne braune Linien ohne Rand
    ink = P.get("ink_lines")  # GM-057: Wild West – nur eine dünne Tintenlinie je Straße
    rpx = P.get("road_px")  # GM-068: Frontier – schmale Linien in festen px je Zoom, schmaler Rand
    if rpx: ink = rpx
    for cls, r in (order if rpx else []):
        a, b, c, d = rpx[r]
        layers.append(with_min(line(f"road-{cls}-casing", "transportation", P["casing"],
                                    ["interpolate", ["linear"], ["zoom"], 8, a + 0.8, 12, b + 1.2, 15, c + 1.6, 18, d + 1.6], road_filter(cls)), cls, P))
    for cls, r in (order if rpx else []):
        a, b, c, d = rpx[r]
        layers.append(with_min(line(f"road-{cls}", "transportation", P["road"](r),
                                    ["interpolate", ["linear"], ["zoom"], 8, a, 12, b, 15, c, 18, d], road_filter(cls)), cls, P))
    for cls, r in (order if not ink else []):
        if thin and r >= 5:
            continue
        casing = P.get("casing_minor", P["casing"]) if r >= 4 else P["casing"]
        ca, cp = P.get("casing_add", (3, 1.6))  # GM-072: Pixel Quest schmaler Rand
        layers.append(with_min(line(f"road-{cls}-casing", "transportation", casing, meters(WIDTH[r] * 0.75 * widen + ca, MIN_PX[r] + cp), road_filter(cls)), cls, P))
        if P.get("far_simple"): layers[-1]["paint"]["line-opacity"] = ["interpolate", ["linear"], ["zoom"], 12, 0, 14, 1]  # GM-059: weit weg ohne Rand
    for cls, r in (order if ink and not rpx else []):
        px = ink[r]
        layers.append(with_min(line(f"road-{cls}", "transportation", P["road"](r),
                                    ["interpolate", ["linear"], ["zoom"], 8, px * 0.3, 12, px * 0.6, 15, px, 18, px * 1.6], road_filter(cls)), cls, P))
    for cls, r in (order if not ink else []):
        w = meters(WIDTH[r] * 0.75 * widen * (0.42 if thin and r >= 5 else 1), MIN_PX[r] * (2.4 * 0.42 if thin and r >= 5 else 1))
        layers.append(with_min(line(f"road-{cls}", "transportation", P["road"](r), w, road_filter(cls)), cls, P))
        if P.get("road_pattern"):  # GM-050: Steinstraße (Pixel Quest); GM-081: 4×4-Pflaster erst nah
            rp = P["road_pattern"]
            layers[-1]["paint"]["line-pattern"] = ["step", ["zoom"], rp, 17.5, rp + "-4"] if P.get("road_pattern_near") else rp
    # GM-050: Toy Town – weiße Mittellinie auf größeren Straßen, Sandrand am Wasser, dunkle Kontur um die Häuser
    if P.get("road_dash"):
        for cls, r in order:
            if r <= 5:
                layers.append(with_min({**line(f"road-{cls}-dash", "transportation", P["road_dash"], meters(0.5, 0.8, 13), road_filter(cls), cap="butt"),
                                        "minzoom": 14}, cls) | {"minzoom": max(14, MINZOOM[cls])})
                layers[-1]["paint"]["line-dasharray"] = [3, 3]
    if P.get("water_soft"):  # GM-057: weicher Übergang ins Papier
        i = next(k for k, l in enumerate(layers) if l["id"] == "water")
        soft = line("water-soft", "water", P["water"], ["interpolate", ["linear"], ["zoom"], 5, 1.5, 12, 6, 16, 10], ["!=", ["get", "class"], "swimming_pool"])
        soft["paint"].update({"line-blur": ["interpolate", ["linear"], ["zoom"], 5, 0.5, 12, 4, 16, 8], "line-opacity": 0.7})  # GM-072: Küste weit weg scharf
        layers.insert(i, soft)
    rail_i = next(k for k, l in enumerate(layers) if l["id"] == "rail")
    if P.get("rail_ticks"):  # GM-057: Bahn mit Querstrichen (Wild West)
        t = line("rail-ticks", "transportation", P["rail"], 4, ["in", ["get", "class"], ["literal", ["rail", "transit"]]], cap="butt")
        t["paint"]["line-dasharray"] = [0.2, 2.2]
        t["minzoom"] = 13  # GM-059: Querstriche erst nah, fein
        layers.insert(rail_i + 1, t)
    if P.get("rail_minzoom"): layers[rail_i]["minzoom"] = P["rail_minzoom"]
    if P.get("rail_pattern"):  # GM-057: Schienen-Grafik (Pixel Quest)
        layers[rail_i]["paint"]["line-pattern"] = P["rail_pattern"]
        layers[rail_i]["minzoom"] = 13  # GM-058: weit weg nur Rauschen
        layers[rail_i]["paint"]["line-width"] = ["interpolate", ["linear"], ["zoom"], 13, 8, 17, 18]
    if P.get("water_edge"):
        i = next(k for k, l in enumerate(layers) if l["id"] == "water")
        layers.insert(i + 1, line("water-edge", "water", P["water_edge"], meters(2.5, 1.2), ["!=", ["get", "class"], "swimming_pool"]))
    if P.get("block_edges"):  # GM-060: Pixel Quest – Häuser wie Blöcke von oben: dunkle Außenkante, helle Innenkante
        i = max(k for k, l in enumerate(layers) if l["id"].startswith("building"))
        dark, light = P["block_edges"]
        w = lambda a, b: ["interpolate", ["exponential", 2], ["zoom"], 14, a, 18, b]
        hi = {**line("building-highlight", "building", light, w(0.6, 3)), "minzoom": 15}
        hi["paint"]["line-offset"] = w(0.8, 4)   # Ringe der Kacheln laufen im Uhrzeigersinn → positiv = innen
        hi["paint"]["line-opacity"] = 0.8
        hi["layout"]["line-join"] = "miter"
        edge = {**line("building-edge", "building", dark, w(0.8, 3.5)), "minzoom": 14}
        edge["layout"]["line-join"] = "miter"
        layers[i + 1:i + 1] = [hi, edge]
    sources_extra = {}
    if P.get("relief"):  # GM-068: Relief aus echten Höhen – unter Wasser, Gebäuden und Straßen, über Land und Wald
        rl = P["relief"]
        sources_extra["dem"] = {"type": "raster-dem", "tiles": [rl["tiles"]], "encoding": "terrarium", "tileSize": 256, "maxzoom": rl["maxzoom"],
                                "attribution": rl["attribution"]}
        k = next(n for n, l in enumerate(layers) if l["id"] == "water")
        if rl.get("broad"):
            sources_extra["dem-broad"] = {**sources_extra["dem"], "maxzoom": rl["broad"]["maxzoom"]}
            layers.insert(k, {"id": "relief-broad", "type": "hillshade", "source": "dem-broad",
                              "paint": {"hillshade-illumination-direction": 315, "hillshade-illumination-anchor": "map",
                                        "hillshade-exaggeration": rl["broad"]["exaggeration"], "hillshade-shadow-color": rl["shadow"],
                                        "hillshade-highlight-color": rl["highlight"], "hillshade-accent-color": rl["accent"]}})
            k += 1
        layers.insert(k, {"id": "relief", "type": "hillshade", "source": "dem", "minzoom": rl.get("minzoom", 0),  # GM-080
                          "paint": {"hillshade-illumination-direction": 315, "hillshade-illumination-anchor": "map",
                                    "hillshade-exaggeration": rl["exaggeration"], "hillshade-shadow-color": rl["shadow"],
                                    "hillshade-highlight-color": rl["highlight"], "hillshade-accent-color": rl["accent"]}})
    for lid, pname in P.get("overlays", []):  # GM-068: transparente Materialkörnung nur auf der passenden Fläche
        k = next((n for n, l in enumerate(layers) if l["id"] == lid), None)
        if k is None: continue
        t = json.loads(json.dumps(layers[k])); t["id"] = lid + "-tex"
        t["paint"] = {"fill-pattern": pname, "fill-opacity": P.get("overlay_opacity", {}).get(lid,
                      ["interpolate", ["linear"], ["zoom"], 8, 0.65, 13, 0.5, 17, 0.2] if lid != "water" else 0.35)}
        layers.insert(k + 1, t)
    if P.get("building_opacity"):
        for l in layers:
            if l["id"].startswith("building") and l["type"] == "fill": l["paint"]["fill-opacity"] = P["building_opacity"]
    if P.get("meadow"):
        layers.insert(1, {"id": "land-meadow", "type": "background", "paint": {"background-pattern": P["meadow"][0], "background-opacity": P["meadow"][1]}})
    if P.get("grain"):
        layers.insert(1, {"id": "land-grain", "type": "background", "paint": {"background-pattern": P["grain"][0], "background-opacity": P["grain"][1]}})
    if P.get("water_bank"):
        k = max(n for n, l in enumerate(layers) if l["id"].startswith("water"))
        layers.insert(k + 1, line("water-bank", "water", P["water_bank"], ["interpolate", ["linear"], ["zoom"], 8, 0.6, 14, 1.2, 18, 2], ["!=", ["get", "class"], "swimming_pool"]))
    if P.get("far_flat"):  # GM-067: Muster erst ab Zoom far_flat, darunter flache Kopie
        z = P["far_flat"]
        for lid in P.get("far_flat_ids", []):
            k = next((n for n, l in enumerate(layers) if l["id"] == lid), None)
            if k is None or "fill-pattern" not in layers[k]["paint"]: continue
            flat = json.loads(json.dumps(layers[k])); flat["id"] = lid + "-far"; flat["maxzoom"] = z
            del flat["paint"]["fill-pattern"]
            layers[k]["minzoom"] = max(layers[k].get("minzoom", 0), z)
            layers.insert(k, flat)
    if P.get("building_minzoom"):  # GM-067: weit weg keine Haus-Krümel
        for l in layers:
            if l.get("source-layer") == "building": l["minzoom"] = max(l.get("minzoom", 0), P["building_minzoom"])
    if P.get("building_ink"):
        i = next(k for k, l in enumerate(layers) if l["id"] == "building")
        layers.insert(i + 1, {**line("building-ink", "building", P["building_ink"], ["interpolate", ["linear"], ["zoom"], 14, 0.6, 18, 1.8]), "minzoom": 14})
    # Straßennamen auf der Straße (Großbuchstaben). GM-026: schon ab Zoom 13,5 – die Fahrkamera in CarPlay liegt um 14–15
    paint = {"text-color": P["label"]}
    if P.get("label_halo"):
        paint.update({"text-halo-color": P["label_halo"], "text-halo-width": P.get("label_halo_width", 1.2)})
    ls = P.get("label_scale", 1)
    layers.append({
        "id": "road-names", "type": "symbol", "source": "openmaptiles", "source-layer": "transportation_name", "minzoom": 13.5,
        "filter": ["in", ["get", "class"], ["literal", ["primary", "secondary", "tertiary", "minor", "trunk", "service"]]],
        "layout": {"symbol-placement": "line", "text-field": ["coalesce", ["get", "name:de"], ["get", "name"]],
                   # GM-028: Barlow Condensed (Neon/Klassik/Wild West); GM-050: Pixel Quest Press Start 2P, Toy Town Fredoka (OFL, eigene Glyphen)
                   "text-font": [P.get("font", "Barlow Condensed SemiBold")],
                   "text-size": ["interpolate", ["linear"], ["zoom"], 13.5, round(11 * ls, 2), 16, round(14 * ls, 2), 18, round(17 * ls, 2)],
                   "text-transform": P.get("text_transform", "uppercase"), "text-letter-spacing": P.get("letter_spacing", 0.12),
                   "text-max-angle": 30, "text-padding": 2, "symbol-spacing": P.get("label_spacing", 150),  # GM-063: Straßennamen öfter
                   **({"text-offset": P["road_label_offset"]} if P.get("road_label_offset") else {})},
        "paint": paint,
    })
    if P.get("house_icons"):  # GM-065: Haus-Bild auf jedem Gebäude (Toy Town: Spielzeughäuser, GM-067 Pixel Quest: Villager-Häuser)
        hi = P["house_icons"]
        layers.append({"id": "building-icons", "type": "symbol", "source": "openmaptiles", "source-layer": "building", "minzoom": hi.get("minzoom", 15),
                       "layout": {"icon-image": hi["image"], "icon-size": hi["size"], "icon-anchor": hi.get("anchor", "center"),
                                  "icon-padding": 0, "icon-allow-overlap": False}})
    if P.get("tree_edges"):  # GM-073: Bäume als einzelne Bilder entlang der Waldkante (Toy Town)
        te = P["tree_edges"]
        k = next(n for n, l in enumerate(layers) if l["id"] == "road-names")
        layers.insert(k, {"id": "forest-trees", "type": "symbol", "source": "openmaptiles", "source-layer": "landcover", "minzoom": 13,
                          "filter": ["==", ["get", "class"], "wood"],
                          "layout": {"symbol-placement": "line", "symbol-spacing": te["spacing"], "icon-image": te["image"], "icon-size": te["size"],
                                     "icon-rotation-alignment": "viewport", "icon-keep-upright": True, "icon-allow-overlap": True, "icon-anchor": "bottom"}})
    if P.get("textile"):  # GM-071: Stoff über Flächen, Straßen und Häusern, unter Schrift und Symbolen
        k = next(n for n, l in enumerate(layers) if l["id"] == "road-names")
        layers.insert(k, {"id": "textile", "type": "background", "minzoom": 12,
                          "paint": {"background-pattern": P["textile"][0], "background-opacity": P["textile"][1]}})
    if P.get("small_hide"):  # GM-072: kleine Gebäude ab Zoom z nur noch als Villager-Haus
        lim, z = P["small_hide"]
        keep = ["any", [">=", ["coalesce", ["get", "render_height"], 0], lim], ["<", ["zoom"], z]]
        for l in layers:
            if l.get("source-layer") == "building" and l["type"] in ("fill", "line"):
                l["filter"] = ["all", l["filter"], keep] if l.get("filter") else keep
    if P.get("water_line_pattern"):  # GM-072: Flüsse und Bäche mit der Wasser-Textur (vorher flach blau)
        for l in layers:
            if l["id"] in ("river", "stream"): l["paint"]["line-pattern"] = P["water_line_pattern"]
    zp = P.get("zoom_patterns", [])
    if zp:  # GM-072: Muster in 2×/4×/8× ab Zoom 16/17/18 – Blöcke bleiben in Weltgröße statt Bildschirmgröße
        zs = lambda n: ["step", ["zoom"], n, 16.5, n + "-2", 18, n + "-4"]  # GM-077: höchstens 4× (8× wirkte wie riesige Kacheln)
        for l in layers:
            for key in ("fill-pattern", "background-pattern"):
                if l.get("paint", {}).get(key) in zp: l["paint"][key] = zs(l["paint"][key])
    if P.get("extrude"):  # GM-070: Pixel Quest 3D
        h = ["coalesce", ["get", "render_height"], 0]
        k = next(n for n, l in enumerate(layers) if l["id"] == "road-names")
        if P.get("extrude_only"):  # GM-073: keine flachen Gebäude, Schatten oder Kanten mehr
            layers[:] = [l for l in layers if not (l.get("source-layer") == "building" and l["type"] in ("fill", "line"))]
            k = next(n for n, l in enumerate(layers) if l["id"] == "road-names")
        if P.get("extrude_far"):  # GM-075: weit weg ein einfarbiger Block-Layer (Muster-Extrusion ist teuer)
            z0, col = P["extrude_far"]
            layers.insert(k, {"id": "building-3d-far", "type": "fill-extrusion", "source": "openmaptiles", "source-layer": "building",
                              "minzoom": z0, "maxzoom": P.get("extrude_minzoom", 15),
                              "paint": {"fill-extrusion-color": col, "fill-extrusion-height": ["max", 4, ["*", ["ceil", ["/", h, 4]], 4]],
                                        "fill-extrusion-base": 0, "fill-extrusion-vertical-gradient": True}})
            k += 1
        for lo, hi_, pat_ in P["extrude"]:
            f = ["all", [">=", h, lo]] + ([["<", h, hi_]] if hi_ else [])
            if lo == 0:  # GM-075: kleine Häuser gemischt Eiche/Fichte (vorher alles gleich braun)
                f = ["all", ["<", h, hi_], ["!=", ["%", ["to-number", ["id"], 0], 3], 0]]
                layers.insert(k, {**json.loads(json.dumps({"id": "building-3d-spruce", "type": "fill-extrusion", "source": "openmaptiles", "source-layer": "building",
                              "minzoom": P.get("extrude_minzoom", 14.5), "filter": ["all", ["<", h, hi_], ["==", ["%", ["to-number", ["id"], 0], 3], 0]],
                              "paint": {"fill-extrusion-pattern": "ez-pat-spruce-px", "fill-extrusion-height": ["max", 4, ["*", ["ceil", ["/", h, 4]], 4]],
                                        "fill-extrusion-base": 0, "fill-extrusion-opacity": 1}}))})
                k += 1
            layers.insert(k, {"id": f"building-3d-{lo}", "type": "fill-extrusion", "source": "openmaptiles", "source-layer": "building",
                              "minzoom": P.get("extrude_minzoom", 14.5), "filter": f,
                              "paint": {"fill-extrusion-pattern": pat_,
                                        "fill-extrusion-height": ["max", 4, ["*", ["ceil", ["/", h, 4]], 4]],
                                        "fill-extrusion-base": ["coalesce", ["get", "render_min_height"], 0],
                                        "fill-extrusion-opacity": 1}})
            k += 1
    if P.get("roofs"):  # GM-078: Dach-Platte (1 m) oben auf jedem Block – Oberseite sieht anders aus als die Wand
        hb = ["max", 4, ["*", ["ceil", ["/", ["coalesce", ["get", "render_height"], 0], 4]], 4]]
        k = next(n for n, l in enumerate(layers) if l["id"] == "road-names")
        roofs = []
        for lim, pat_ in P["roofs"]:  # GM-081: Muster je Gebäude nur über eigene Ebenen (Ausdruck zeichnete fast nur eines)
            lo, hi_ = lim
            f = ["all", [">=", ["coalesce", ["get", "render_height"], 0], lo]] + ([["<", ["coalesce", ["get", "render_height"], 0], hi_]] if hi_ else [])
            if lo == 0 and P.get("roof_alt"):
                alt, n = P["roof_alt"]
                sel = ["==", ["%", ["floor", ["*", ["coalesce", ["get", "render_height"], 0], 1.7]], n], 0]  # ["id"] wirkte im Filter nicht
                roofs.append((f"{lo}-alt", f + [sel], alt))
                f = f + [["!", sel]]
            roofs.append((lo, f, pat_))
        for lo, f, pat_ in roofs:
            layers.insert(k, {"id": f"roof-{lo}", "type": "fill-extrusion", "source": "openmaptiles", "source-layer": "building",
                              "minzoom": P.get("extrude_minzoom", 14.5), "filter": f,
                              "paint": {"fill-extrusion-pattern": pat_, "fill-extrusion-base": hb, "fill-extrusion-height": ["+", hb, 1],
                                        "fill-extrusion-opacity": 1}})
            k += 1
    layers.append(poi_layer(P))
    layers.append(place_layer(P))  # GM-058: Orts- und Stadtnamen (vorher keine – beim Rauszoomen kein „Frankfurt“)
    return {
        "version": 8,
        "name": f"EzMaps {title}",
        "metadata": {"ezmaps:source": "tools/maplibre/build_style.py – Werte aus tools/prototype/js/map.js"},
        "sources": {**{"openmaptiles": {"type": "vector", "url": "https://tiles.openfreemap.org/planet",
                                     # GM-020: OpenFreeMap verlangt den Hinweis auf OpenMapTiles und OpenStreetMap
                                     "attribution": "<a href=\"https://openfreemap.org\">OpenFreeMap</a> · © <a href=\"https://www.openmaptiles.org/\">OpenMapTiles</a> · © <a href=\"https://www.openstreetmap.org/copyright\">OpenStreetMap-Mitwirkende</a>"}}, **sources_extra},
        # GM-028: Glyphen liegen in der App (Resources/Glyphs, erzeugt von build_glyphs.py) – asset:// = App-Bundle
        "glyphs": "asset://Glyphs/{fontstack}/{range}.pbf",
        "layers": layers,
    }


road_filter = lambda cls: ["all", ["==", ["get", "class"], cls], ["!=", ["get", "brunnel"], "tunnel"]]
# GM-027: kleine Straßen erst beim Heranzoomen – sonst wird die Übersicht (Routen-Vorschau) eine weiße Fläche
MINZOOM = {"motorway": 0, "trunk": 0, "primary": 7, "secondary": 9, "tertiary": 10.5, "minor": 12, "service": 14}
def with_min(l, cls, P=None):
    z = max(MINZOOM[cls], (P or {}).get("minzoom_shift", {}).get(cls, 0))  # GM-059: je Stil kleine Straßen später
    if z: l["minzoom"] = z
    return l


# GM-026: weiße Kartensymbole mit schwarzem Rand wie in der Vorlage. Bilder zeichnet die App beim Laden (RouteOverlay.poiImages)
# GM-057: mehr Arten (Nutzer: „mir fehlen Icons wie in meinen Screenshots“) – Bilder: RouteOverlay.poiKinds (NeonMapView.swift)
POI = {"shop": "ez-poi-shop", "grocery": "ez-poi-shop", "hospital": "ez-poi-cross", "pharmacy": "ez-poi-cross", "doctors": "ez-poi-cross",
       "fuel": "ez-poi-fuel", "parking": "ez-poi-parking", "restaurant": "ez-poi-food", "fast_food": "ez-poi-fastfood", "cafe": "ez-poi-coffee",
       "charging_station": "ez-poi-charge", "clothing_store": "ez-poi-shirt", "bank": "ez-poi-cash", "atm": "ez-poi-cash",
       "cinema": "ez-poi-cinema", "hairdresser": "ez-poi-barber", "lodging": "ez-poi-hotel", "school": "ez-poi-school",
       "college": "ez-poi-school", "place_of_worship": "ez-poi-church", "playground": "ez-poi-playground"}
def poi_layer(P):
    match = ["match", ["get", "class"]]
    for k, v in POI.items(): match += [k, v + P.get("poi_suffix", "")]  # GM-045: Neon City farbig
    match.append("")
    return {
        "id": "poi-icons", "type": "symbol", "source": "openmaptiles", "source-layer": "poi", "minzoom": P.get("poi_minzoom", 14.5),
        "filter": ["in", ["get", "class"], ["literal", list(POI)]],
        "layout": {"icon-image": match, "icon-size": ["interpolate", ["linear"], ["zoom"], 14.5, round(0.5 * P.get("poi_scale", 1), 2), 17, round(0.72 * P.get("poi_scale", 1), 2),
                                                  19, round(0.72 * P.get("poi_scale", 1) * P.get("poi_near", 1), 2)], "icon-padding": 44},  # GM-079: nah weiter wachsen  # GM-067: größer (Nutzer: „Icons zu klein“)
    }


# GM-058: Ortsnamen – Städte groß, Dörfer klein, Stadtteile erst nah; Schrift und Farbe je Stil
def place_layer(P):
    font = P.get("place_font", P.get("font", "Barlow Condensed SemiBold"))
    sc = P.get("label_scale", 1)
    size = ["interpolate", ["linear"], ["zoom"],
            6, ["match", ["get", "class"], "city", round(14 * sc, 1), "town", round(10 * sc, 1), round(8 * sc, 1)],
            12, ["match", ["get", "class"], "city", round(24 * sc, 1), "town", round(18 * sc, 1), "village", round(14 * sc, 1), round(12 * sc, 1)],
            16, ["match", ["get", "class"], "city", round(30 * sc, 1), "town", round(24 * sc, 1), "village", round(18 * sc, 1), round(14 * sc, 1)]]
    return {
        "id": "place-names", "type": "symbol", "source": "openmaptiles", "source-layer": "place", "minzoom": 5,
        "filter": ["any", ["in", ["get", "class"], ["literal", ["city", "town"]]],
                   ["all", ["==", ["get", "class"], "village"], [">=", ["zoom"], 9.5]],
                   ["all", ["in", ["get", "class"], ["literal", ["suburb", "quarter"]]], [">=", ["zoom"], 12]]],
        "layout": {"text-field": ["coalesce", ["get", "name:de"], ["get", "name"]], "text-font": [font], "text-size": size,
                   "text-transform": P.get("place_transform", "uppercase"), "text-letter-spacing": P.get("place_spacing", 0.08),
                   "text-max-width": 8, "text-padding": 4, "symbol-sort-key": ["get", "rank"]},
        "paint": {"text-color": P.get("place_color", P["label"]), "text-halo-color": P.get("place_halo", P.get("label_halo") or "#000000"),
                  "text-halo-width": P.get("place_halo_width", 1.6)},
    }


# Dateinamen = MapStyle.styleFileName (Core/Sources/EzMapsCore/MapStyle.swift)
STYLES = {"classic": (CLASSIC, "Klassik"), "neon-city": (NEON, "Neon City"), "wild-west": (WESTERN, "Wild West"),
          "pixel-quest": (PIXEL, "Pixel Quest"), "toy-town": (TOY, "Toy Town"), "frontier": (FRONTIER, "Frontier")}
OUT_DIR.mkdir(parents=True, exist_ok=True)
for key, (P, title) in STYLES.items():
    out = OUT_DIR / f"style-{key}.json"
    style = build(P, title)
    out.write_text(json.dumps(style, ensure_ascii=False, indent=1), encoding="utf-8")
    print(out.relative_to(ROOT), len(style["layers"]), "Ebenen")
