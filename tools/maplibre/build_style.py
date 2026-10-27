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
NEON = dict(land=zc("#232425", "#3b3c3e"), residential=zc("#323335", "#3b3c3e"), industrial=zc("#343537", "#3e3f41"),
            farm=zc("#212223", "#38393b"), park=zc("#202322", "#36383a"), forest=zc("#1e2120", "#333537"),
            water=zc("#4b5155", "#5d6870"), building="#5b5c5f", buildingEdge="#4a4b4e", urban="#3b3c3e", rail="#2b2c2e",
            casing=zc("#232425", "#151617"), label="#1d1e20", poi_suffix="-neon", poi_minzoom=13.5)
NEON.update(road=lambda r: zc("#bdbdbd" if r <= 1 else "#959595" if r <= 2 else "#727272" if r <= 4 else "#5f5f5f", "#ececec" if r <= 4 else "#dcdcdc" if r <= 6 else "#c4c4c4"),
            widen=1.5, label_halo=None)
CLASSIC = dict(land="#f2efe9", residential="#ece7e0", industrial="#ebe3e8", farm="#eef0d6", park="#d4ebc8", forest="#c3dfb4",
               water="#aad3df", building="#ddd5cc", buildingEdge="#cbc0b5", rail="#a3a3a3", casing="#c9c1b6", label="#4a4a4a",
               road=lambda r: "#f7c56b" if r <= 1 else "#fde7a6" if r <= 3 else "#ffffff", widen=1.15, label_halo="#ffffff")
WESTERN = dict(land="#dcc59a", residential="#d4bb8a", industrial="#ccb07f", farm="#e3cfa2", park="#d6c18c", forest="#cdb782",
               water="#a3b7ae", building="#9b7a50", buildingEdge="#5e4127", rail="#4a3220", casing="#4a3220", label="#3a2414",
               road=lambda r: "#f2e4bf" if r <= 4 else "#7a5a38", widen=1.0, thin_minor=True, label_halo="#e9d9b0")
PIXEL = dict(land="#60a83a", residential="#6eb242", industrial="#9c9c88", farm="#c9b458", park="#7cbe4c", forest="#2f7d32",
             water="#3b7dd8", building="#be4632", buildingEdge="#602a1e", rail="#5a4632", casing="#606060", label="#1b1206",
             road=lambda r: "#a7a7a7" if r <= 3 else "#d8b878", casing_minor="#a8864f", widen=1.2, label_halo="#e8d48a")
TOY = dict(land="#8dc63f", residential="#a3d65a", industrial="#cfd0d2", farm="#b9d86a", park="#7cc142", forest="#62b235",
           water="#4ab0ea", building="#f6d743", buildingEdge="#2f3640", rail="#2f3640", casing="#c9cbce", label="#ffffff",
           road=lambda r: "#66686c", widen=1.4, label_halo="#2f3640")

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


def fill(id_, layer, color, flt=None, extra=None):
    l = {"id": id_, "type": "fill", "source": "openmaptiles", "source-layer": layer, "paint": {"fill-color": color, "fill-antialias": True}}
    if flt: l["filter"] = flt
    if extra: l["paint"].update(extra)
    return l


def line(id_, layer, color, width, flt=None, cap="round"):
    l = {"id": id_, "type": "line", "source": "openmaptiles", "source-layer": layer,
         "layout": {"line-cap": cap, "line-join": "round"}, "paint": {"line-color": color, "line-width": width}}
    if flt: l["filter"] = flt
    return l


def build(P, title):
    """Ebenen für eine Palette P (Mirror der Zeichenreihenfolge in js/map.js drawClassic)"""
    layers = [
        {"id": "land", "type": "background", "paint": {"background-color": P["land"]}},
        fill("farm", "landcover", P["farm"], ["==", ["get", "class"], "farmland"]),
        fill("forest", "landcover", P["forest"], ["==", ["get", "class"], "wood"]),
        fill("grass", "landcover", P["park"], ["==", ["get", "class"], "grass"]),
        fill("park", "park", P["park"]),
        fill("residential", "landuse", P["residential"], ["in", ["get", "class"], ["literal", ["residential", "suburb", "neighbourhood"]]]),
        fill("industrial", "landuse", P["industrial"], ["in", ["get", "class"], ["literal", ["industrial", "commercial", "retail", "railway", "garages"]]]),
        fill("landuse-green", "landuse", P["park"], ["in", ["get", "class"], ["literal", ["cemetery", "pitch", "playground", "park", "zoo"]]]),
        fill("water", "water", P["water"], ["!=", ["get", "class"], "swimming_pool"]),
        line("river", "waterway", P["water"], meters(9, 1), ["in", ["get", "class"], ["literal", ["river", "canal"]]]),
        line("stream", "waterway", P["water"], meters(3, 0.6), ["!", ["in", ["get", "class"], ["literal", ["river", "canal"]]]]),
        fill("building", "building", P["building"], None, {"fill-outline-color": P["buildingEdge"]}),
        line("rail", "transportation", P["rail"], meters(1.5, 1), ["in", ["get", "class"], ["literal", ["rail", "transit"]]], cap="butt"),
    ]
    # Straßen: erst alle dunklen Ränder, dann die hellen Flächen (so verschmelzen Kreuzungen sauber), große obenauf
    order = sorted(CLASS_RANK.items(), key=lambda kv: -kv[1])
    widen = P["widen"]
    thin = P.get("thin_minor", False)  # Wild West: kleine Straßen als dünne braune Linien ohne Rand
    for cls, r in order:
        if thin and r >= 5:
            continue
        casing = P.get("casing_minor", P["casing"]) if r >= 4 else P["casing"]
        layers.append(with_min(line(f"road-{cls}-casing", "transportation", casing, meters(WIDTH[r] * 0.75 * widen + 3, MIN_PX[r] + 1.6), road_filter(cls)), cls))
    for cls, r in order:
        w = meters(WIDTH[r] * 0.75 * widen * (0.42 if thin and r >= 5 else 1), MIN_PX[r] * (2.4 * 0.42 if thin and r >= 5 else 1))
        layers.append(with_min(line(f"road-{cls}", "transportation", P["road"](r), w, road_filter(cls)), cls))
    # Straßennamen auf der Straße (Großbuchstaben). GM-026: schon ab Zoom 13,5 – die Fahrkamera in CarPlay liegt um 14–15
    paint = {"text-color": P["label"]}
    if P.get("label_halo"):
        paint.update({"text-halo-color": P["label_halo"], "text-halo-width": 1.2})
    layers.append({
        "id": "road-names", "type": "symbol", "source": "openmaptiles", "source-layer": "transportation_name", "minzoom": 13.5,
        "filter": ["in", ["get", "class"], ["literal", ["primary", "secondary", "tertiary", "minor", "trunk", "service"]]],
        "layout": {"symbol-placement": "line", "text-field": ["coalesce", ["get", "name:de"], ["get", "name"]], "text-font": ["Barlow Condensed SemiBold"],  # GM-028: schmale fette Schrift wie die Vorlage (eigene Glyphen, OFL)
                   "text-size": ["interpolate", ["linear"], ["zoom"], 13.5, 10, 16, 13, 18, 16], "text-transform": "uppercase", "text-letter-spacing": 0.12,
                   "text-max-angle": 30, "text-padding": 2, "symbol-spacing": 220},
        "paint": paint,
    })
    layers.append(poi_layer(P))
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
POI = {"shop": "ez-poi-shop", "grocery": "ez-poi-shop", "hospital": "ez-poi-cross", "pharmacy": "ez-poi-cross", "doctors": "ez-poi-cross",
       "fuel": "ez-poi-fuel", "parking": "ez-poi-parking", "restaurant": "ez-poi-food", "fast_food": "ez-poi-food", "cafe": "ez-poi-food",
       "charging_station": "ez-poi-charge"}
def poi_layer(P):
    match = ["match", ["get", "class"]]
    for k, v in POI.items(): match += [k, v + P.get("poi_suffix", "")]  # GM-045: Neon City farbig
    match.append("")
    return {
        "id": "poi-icons", "type": "symbol", "source": "openmaptiles", "source-layer": "poi", "minzoom": P.get("poi_minzoom", 14.5),
        "filter": ["in", ["get", "class"], ["literal", list(POI)]],
        "layout": {"icon-image": match, "icon-size": ["interpolate", ["linear"], ["zoom"], 14.5, 0.5, 17, 0.7], "icon-padding": 22},  # GM-030: weniger dicht (Fahrt-Bilder)
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
