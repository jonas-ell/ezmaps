"""Erzeugt App/MapStyles/style-neon-city.json (MapLibre-Style) aus den Werten des Prototyps.

Quelle der Werte: tools/prototype/js/map.js – NEON, WIDTH, MIN_PX, widen, urbanReach.
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
OUT = ROOT / "App" / "MapStyles" / "style-neon-city.json"

# --- aus js/map.js (NEON) ---
# GM-024: nach Foto des Nutzers (CarPlay-Vorlage): mittelgrauer Boden, Häuser heller als der Boden,
# fast weiße Straßen mit dunklem Rand, Straßennamen dunkel auf der Straße
NEON = dict(land="#3b3c3e", residential="#3b3c3e", industrial="#3e3f41", farm="#38393b", park="#36383a", forest="#333537",
            water="#5d6870", building="#5b5c5f", buildingEdge="#4a4b4e", urban="#3b3c3e", rail="#2b2c2e",
            casing="#151617", label="#1d1e20")
WIDTH = {0: 16, 1: 13, 2: 12, 3: 10, 4: 9, 5: 7, 6: 6, 7: 3.5}       # Meter
MIN_PX = {0: 4.4, 1: 3.6, 2: 3, 3: 2.4, 4: 2, 5: 1.4, 6: 1.2, 7: 1}   # Bildpunkte
WIDEN, URBAN_REACH = 1.5, 46
road_color = lambda r: "#ececec" if r <= 4 else "#dcdcdc" if r <= 6 else "#c4c4c4"
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


layers = [
    {"id": "land", "type": "background", "paint": {"background-color": NEON["land"]}},
    fill("farm", "landcover", NEON["farm"], ["==", ["get", "class"], "farmland"]),
    fill("forest", "landcover", NEON["forest"], ["==", ["get", "class"], "wood"]),
    fill("grass", "landcover", NEON["park"], ["==", ["get", "class"], "grass"]),
    fill("park", "park", NEON["park"]),
    fill("residential", "landuse", NEON["residential"], ["in", ["get", "class"], ["literal", ["residential", "suburb", "neighbourhood"]]]),
    fill("industrial", "landuse", NEON["industrial"], ["in", ["get", "class"], ["literal", ["industrial", "commercial", "retail", "railway", "garages"]]]),
    fill("landuse-green", "landuse", NEON["park"], ["in", ["get", "class"], ["literal", ["cemetery", "pitch", "playground", "park", "zoo"]]]),
    fill("water", "water", NEON["water"], ["!=", ["get", "class"], "swimming_pool"]),
    line("river", "waterway", NEON["water"], meters(9, 1), ["in", ["get", "class"], ["literal", ["river", "canal"]]]),
    line("stream", "waterway", NEON["water"], meters(3, 0.6), ["!", ["in", ["get", "class"], ["literal", ["river", "canal"]]]]),
    fill("building", "building", NEON["building"], None, {"fill-outline-color": NEON["buildingEdge"]}),
    line("rail", "transportation", NEON["rail"], meters(1.5, 1), ["in", ["get", "class"], ["literal", ["rail", "transit"]]], cap="butt"),
]
# Straßen: erst alle dunklen Ränder, dann die hellen Flächen (so verschmelzen Kreuzungen sauber), große obenauf
order = sorted(CLASS_RANK.items(), key=lambda kv: -kv[1])
road_filter = lambda cls: ["all", ["==", ["get", "class"], cls], ["!=", ["get", "brunnel"], "tunnel"]]
for cls, r in order:
    layers.append(line(f"road-{cls}-casing", "transportation", NEON["casing"], meters(WIDTH[r] * 0.75 * WIDEN + 3, MIN_PX[r] + 1.6), road_filter(cls)))
for cls, r in order:
    layers.append(line(f"road-{cls}", "transportation", road_color(r), meters(WIDTH[r] * 0.75 * WIDEN, MIN_PX[r]), road_filter(cls)))
# Straßennamen auf der Straße (Großbuchstaben, dunkel). GM-026: schon ab Zoom 13,5 – die Fahrkamera in CarPlay liegt um 14–15
layers.append({
    "id": "road-names", "type": "symbol", "source": "openmaptiles", "source-layer": "transportation_name", "minzoom": 13.5,
    "filter": ["in", ["get", "class"], ["literal", ["primary", "secondary", "tertiary", "minor", "trunk", "service"]]],
    "layout": {"symbol-placement": "line", "text-field": ["coalesce", ["get", "name:de"], ["get", "name"]], "text-font": ["Noto Sans Bold"],
               "text-size": ["interpolate", ["linear"], ["zoom"], 13.5, 8.5, 16, 11, 18, 14], "text-transform": "uppercase", "text-letter-spacing": 0.08,
               "text-max-angle": 30, "text-padding": 2, "symbol-spacing": 220},
    "paint": {"text-color": NEON["label"]},
})
# GM-026: weiße Kartensymbole mit schwarzem Rand wie in der Vorlage. Bilder zeichnet die App beim Laden (RouteOverlay.poiImages)
POI = {"shop": "ez-poi-shop", "grocery": "ez-poi-shop", "hospital": "ez-poi-cross", "pharmacy": "ez-poi-cross", "doctors": "ez-poi-cross",
       "fuel": "ez-poi-fuel", "parking": "ez-poi-parking", "restaurant": "ez-poi-food", "fast_food": "ez-poi-food", "cafe": "ez-poi-food",
       "charging_station": "ez-poi-charge"}
match = ["match", ["get", "class"]]
for k, v in POI.items(): match += [k, v]
match.append("")
layers.append({
    "id": "poi-icons", "type": "symbol", "source": "openmaptiles", "source-layer": "poi", "minzoom": 14.5,
    "filter": ["in", ["get", "class"], ["literal", list(POI)]],
    "layout": {"icon-image": match, "icon-size": ["interpolate", ["linear"], ["zoom"], 14.5, 0.55, 17, 0.8], "icon-padding": 6},
})

style = {
    "version": 8,
    "name": "EzMaps Neon City",
    "metadata": {"ezmaps:source": "tools/maplibre/build_style.py – Werte aus tools/prototype/js/map.js (NEON)"},
    "sources": {"openmaptiles": {"type": "vector", "url": "https://tiles.openfreemap.org/planet",
                                 # GM-020: OpenFreeMap verlangt den Hinweis auf OpenMapTiles und OpenStreetMap
                                 "attribution": "<a href=\"https://openfreemap.org\">OpenFreeMap</a> · © <a href=\"https://www.openmaptiles.org/\">OpenMapTiles</a> · © <a href=\"https://www.openstreetmap.org/copyright\">OpenStreetMap-Mitwirkende</a>"}},
    "glyphs": "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
    "layers": layers,
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(style, ensure_ascii=False, indent=1), encoding="utf-8")
print(OUT.relative_to(ROOT), len(layers), "Ebenen")
