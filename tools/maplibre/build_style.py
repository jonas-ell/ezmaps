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
               water="#aaa392", building="#e9d1b2", buildingEdge="#a48c6c", rail="#4a3b2c", casing="#4a3b2c", label="#4a3b2c",
               road=lambda r: "#4a3b2c", widen=1.0, ink_lines={0: 3.2, 1: 3.0, 2: 2.6, 3: 2.2, 4: 1.8, 5: 1.3, 6: 1.0, 7: 0.8},
               water_soft=True, rail_ticks=True, label_halo="#e4c9a8", label_halo_width=2,
               font="Old Standard TT Regular", label_scale=0.85, letter_spacing=0.18,
               poi_suffix="-west", poi_minzoom=13.5, place_spacing=0.2, place_color="#3a2d20", place_halo="#e4c9a8")
# GM-050: Pixel Quest und Toy Town wieder eigenständig wie im Prototyp (js/map.js drawPixel/drawToy, docs/previews/c4-*):
# eigene Muster (Bilder zeichnet die App: RouteOverlay.patternImages, Website: js/poi.js), eigene Schrift, eigene Symbole.
# Nutzer: „du kannst die Maps doch nicht alle im selben Stil machen“.
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
             building_pattern=by_height(["ez-pat-oak-px", "ez-pat-spruce-px", "ez-pat-brick-px", "ez-pat-cobble-px"]),
             building_shadow=True,
             font="Press Start 2P Regular", label_scale=0.62, text_transform="none", letter_spacing=0, label_halo_width=1.6,
             poi_suffix="-px", poi_minzoom=14, place_color="#ffffff", place_halo="#000000", place_halo_width=2, place_transform="none")
TOY = dict(land="#8dc63f", residential="#8dc63f", industrial="#cfd0d2", farm="#b9d86a", park="#7cc142", forest="#62b235",
           water="#4ab0ea", building=by_height(["#e3412f", "#ef7d2d", "#3d78c9", "#8b8f96"]),
           buildingEdge="#2f3640", rail="#2f3640", casing="#c9cbce", label="#ffffff",
           road=lambda r: "#66686c", widen=1.4, label_halo="#2f3640",
           pat=dict(land="ez-pat-lawn-toy", forest="ez-pat-trees-toy", park="ez-pat-park-toy"),
           water_edge="#f2d48b", road_dash="#ffffff", building_ink="#2f3640",
           font="Fredoka Bold", label_scale=1.05, text_transform="none", letter_spacing=0.02, label_halo_width=2,
           poi_suffix="-toy", poi_minzoom=14, place_color="#ffffff", place_halo="#2f3640", place_halo_width=2.4, place_transform="none")

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
        fill("park", "park", P["park"], pattern=pat.get("park")),
        fill("residential", "landuse", P["residential"], ["in", ["get", "class"], ["literal", ["residential", "suburb", "neighbourhood"]]], pattern=pat.get("residential")),
        fill("industrial", "landuse", P["industrial"], ["in", ["get", "class"], ["literal", ["industrial", "commercial", "retail", "railway", "garages"]]], pattern=pat.get("industrial")),
        fill("landuse-green", "landuse", P["park"], ["in", ["get", "class"], ["literal", ["cemetery", "pitch", "playground", "park", "zoo"]]], pattern=pat.get("park")),
        fill("water", "water", P["water"], ["!=", ["get", "class"], "swimming_pool"], pattern=pat.get("water")),
        line("river", "waterway", P["water"], meters(9, 1), ["in", ["get", "class"], ["literal", ["river", "canal"]]]),
        line("stream", "waterway", P["water"], meters(3, 0.6), ["!", ["in", ["get", "class"], ["literal", ["river", "canal"]]]]),
        # GM-050: Block-Schatten (Pixel Quest) – dunkle Kopie leicht versetzt, wirkt wie ein Block von oben
        *([fill("building-shadow", "building", "rgba(0,0,0,0.38)", None, {"fill-translate": [2.5, 2.5], "fill-antialias": False})] if P.get("building_shadow") else []),
        fill("building", "building", P["building"], None, {"fill-outline-color": P["buildingEdge"]}, pattern=P.get("building_pattern")),
        line("rail", "transportation", P["rail"], meters(1.5, 1), ["in", ["get", "class"], ["literal", ["rail", "transit"]]], cap="butt"),
    ]
    # Straßen: erst alle dunklen Ränder, dann die hellen Flächen (so verschmelzen Kreuzungen sauber), große obenauf
    order = sorted(CLASS_RANK.items(), key=lambda kv: -kv[1])
    widen = P["widen"]
    thin = P.get("thin_minor", False)  # Wild West: kleine Straßen als dünne braune Linien ohne Rand
    ink = P.get("ink_lines")  # GM-057: Wild West – nur eine dünne Tintenlinie je Straße
    for cls, r in (order if not ink else []):
        if thin and r >= 5:
            continue
        casing = P.get("casing_minor", P["casing"]) if r >= 4 else P["casing"]
        layers.append(with_min(line(f"road-{cls}-casing", "transportation", casing, meters(WIDTH[r] * 0.75 * widen + 3, MIN_PX[r] + 1.6), road_filter(cls)), cls))
    for cls, r in (order if ink else []):
        px = ink[r]
        layers.append(with_min(line(f"road-{cls}", "transportation", P["road"](r),
                                    ["interpolate", ["linear"], ["zoom"], 10, px * 0.6, 15, px, 18, px * 1.6], road_filter(cls)), cls))
    for cls, r in (order if not ink else []):
        w = meters(WIDTH[r] * 0.75 * widen * (0.42 if thin and r >= 5 else 1), MIN_PX[r] * (2.4 * 0.42 if thin and r >= 5 else 1))
        layers.append(with_min(line(f"road-{cls}", "transportation", P["road"](r), w, road_filter(cls)), cls))
        if P.get("road_pattern"): layers[-1]["paint"]["line-pattern"] = P["road_pattern"]  # GM-050: Steinstraße (Pixel Quest)
    # GM-050: Toy Town – weiße Mittellinie auf größeren Straßen, Sandrand am Wasser, dunkle Kontur um die Häuser
    if P.get("road_dash"):
        for cls, r in order:
            if r <= 5:
                layers.append(with_min({**line(f"road-{cls}-dash", "transportation", P["road_dash"], meters(0.5, 0.8, 13), road_filter(cls), cap="butt"),
                                        "minzoom": 14}, cls) | {"minzoom": max(14, MINZOOM[cls])})
                layers[-1]["paint"]["line-dasharray"] = [3, 3]
    if P.get("water_soft"):  # GM-057: weicher Übergang ins Papier
        i = next(k for k, l in enumerate(layers) if l["id"] == "water")
        soft = line("water-soft", "water", P["water"], 10, ["!=", ["get", "class"], "swimming_pool"])
        soft["paint"].update({"line-blur": 8, "line-opacity": 0.7})
        layers.insert(i, soft)
    rail_i = next(k for k, l in enumerate(layers) if l["id"] == "rail")
    if P.get("rail_ticks"):  # GM-057: Bahn mit Querstrichen (Wild West)
        t = line("rail-ticks", "transportation", P["rail"], 6, ["in", ["get", "class"], ["literal", ["rail", "transit"]]], cap="butt")
        t["paint"]["line-dasharray"] = [0.25, 1.4]
        layers.insert(rail_i + 1, t)
    if P.get("rail_pattern"):  # GM-057: Schienen-Grafik (Pixel Quest)
        layers[rail_i]["paint"]["line-pattern"] = P["rail_pattern"]
        layers[rail_i]["minzoom"] = 13  # GM-058: weit weg nur Rauschen
        layers[rail_i]["paint"]["line-width"] = ["interpolate", ["linear"], ["zoom"], 13, 8, 17, 18]
    if P.get("water_edge"):
        i = next(k for k, l in enumerate(layers) if l["id"] == "water")
        layers.insert(i + 1, line("water-edge", "water", P["water_edge"], meters(2.5, 1.2), ["!=", ["get", "class"], "swimming_pool"]))
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
                   "text-size": ["interpolate", ["linear"], ["zoom"], 13.5, round(10 * ls, 2), 16, round(13 * ls, 2), 18, round(16 * ls, 2)],
                   "text-transform": P.get("text_transform", "uppercase"), "text-letter-spacing": P.get("letter_spacing", 0.12),
                   "text-max-angle": 30, "text-padding": 2, "symbol-spacing": 220},
        "paint": paint,
    })
    layers.append(poi_layer(P))
    layers.append(place_layer(P))  # GM-058: Orts- und Stadtnamen (vorher keine – beim Rauszoomen kein „Frankfurt“)
    return {
        "version": 8,
        "name": f"EzMaps {title}",
        "metadata": {"ezmaps:source": "tools/maplibre/build_style.py – Werte aus tools/prototype/js/map.js"},
        "sources": {"openmaptiles": {"type": "vector", "url": "https://tiles.openfreemap.org/planet",
                                     # GM-020: OpenFreeMap verlangt den Hinweis auf OpenMapTiles und OpenStreetMap
                                     "attribution": "<a href=\"https://openfreemap.org\">OpenFreeMap</a> · © <a href=\"https://www.openmaptiles.org/\">OpenMapTiles</a> · © <a href=\"https://www.openstreetmap.org/copyright\">OpenStreetMap-Mitwirkende</a>"}},
        # GM-028: Glyphen liegen in der App (Resources/Glyphs, erzeugt von build_glyphs.py) – asset:// = App-Bundle
        "glyphs": "asset://Glyphs/{fontstack}/{range}.pbf",
        "layers": layers,
    }


road_filter = lambda cls: ["all", ["==", ["get", "class"], cls], ["!=", ["get", "brunnel"], "tunnel"]]
# GM-027: kleine Straßen erst beim Heranzoomen – sonst wird die Übersicht (Routen-Vorschau) eine weiße Fläche
MINZOOM = {"motorway": 0, "trunk": 0, "primary": 7, "secondary": 9, "tertiary": 10.5, "minor": 12, "service": 14}
def with_min(l, cls):
    if MINZOOM[cls]: l["minzoom"] = MINZOOM[cls]
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
        "layout": {"icon-image": match, "icon-size": ["interpolate", ["linear"], ["zoom"], 14.5, 0.5, 17, 0.7], "icon-padding": 22},  # GM-030: weniger dicht (Fahrt-Bilder)
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
          "pixel-quest": (PIXEL, "Pixel Quest"), "toy-town": (TOY, "Toy Town")}
OUT_DIR.mkdir(parents=True, exist_ok=True)
for key, (P, title) in STYLES.items():
    out = OUT_DIR / f"style-{key}.json"
    style = build(P, title)
    out.write_text(json.dumps(style, ensure_ascii=False, indent=1), encoding="utf-8")
    print(out.relative_to(ROOT), len(style["layers"]), "Ebenen")
