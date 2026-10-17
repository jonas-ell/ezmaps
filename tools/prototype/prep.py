"""Baut tools/prototype/data/idstein.json aus Overpass-Rohdaten.

Enthält Kartenebenen (Meter um den Ursprung), Straßengraph fürs Routing im Browser,
Orte für die Suche und Ortsteile für den „Nebel des Krieges“.
Daten: © OpenStreetMap-Mitwirkende, ODbL.

Aufruf (aus tools/prototype):
  python prep.py raw/idstein.json raw/named.json raw/hexen.json data/idstein.json
Rohdaten per Overpass holen: siehe README.md, Abschnitt „Prototyp“.
"""
import json
import math
import sys

raw, named_src, extra_src, dst = sys.argv[1:5]
LAT0, LON0 = 50.2215, 8.2680
KX = math.cos(math.radians(LAT0)) * 111320.0
KY = 110540.0
HALF_W, HALF_H = 2200, 1900  # Ausschnitt, der in die Datei kommt (Meter)


def proj(lat, lon):
    return (round((lon - LON0) * KX, 1), round(-(lat - LAT0) * KY, 1))


def inside(pts, m=0):
    return any(abs(x) < HALF_W + m and abs(y) < HALF_H + m for x, y in pts)


def area_kind(t):
    if "building" in t:
        return "building"
    v = t.get("natural") or t.get("landuse") or t.get("leisure")
    if t.get("natural") == "water" or t.get("landuse") in ("reservoir", "basin"):
        return "water"
    if v in ("wood", "forest", "scrub"):
        return "forest"
    if v in ("grass", "meadow", "grassland", "park", "garden", "recreation_ground", "village_green",
             "allotments", "orchard", "cemetery", "pitch", "playground"):
        return "park"
    if v in ("farmland", "farmyard", "vineyard"):
        return "farm"
    if v in ("industrial", "commercial", "retail", "railway", "construction"):
        return "industrial"
    if v == "residential":
        return "residential"
    return None


RANK = {"motorway": 0, "motorway_link": 1, "trunk": 1, "trunk_link": 2, "primary": 2, "primary_link": 3,
        "secondary": 3, "secondary_link": 4, "tertiary": 4, "tertiary_link": 5, "unclassified": 5,
        "residential": 5, "living_street": 6, "service": 7, "pedestrian": 6, "track": 8, "footway": 9,
        "path": 9, "cycleway": 9, "steps": 9}
SPEED = {"motorway": 110, "motorway_link": 60, "trunk": 80, "trunk_link": 50, "primary": 55, "primary_link": 40,
         "secondary": 50, "secondary_link": 40, "tertiary": 45, "tertiary_link": 35, "unclassified": 35,
         "residential": 30, "living_street": 10, "service": 15}

data = json.load(open(raw, encoding="utf-8"))
areas, lines, pois, places = [], [], [], []
node_index, nodes, edges, names = {}, [], [], []
name_index = {}


def nid(osm_id, p):
    if osm_id not in node_index:
        node_index[osm_id] = len(nodes)
        nodes.append(p)
    return node_index[osm_id]


def name_id(n):
    if n not in name_index:
        name_index[n] = len(names)
        names.append(n)
    return name_index[n]


for el in data["elements"]:
    t = el.get("tags", {})
    if el["type"] == "node":
        p = proj(el["lat"], el["lon"])
        if not inside([p], 300):
            continue
        if "place" in t and "name" in t:
            places.append({"p": p, "name": t["name"], "kind": t["place"]})
        else:
            pois.append({"p": p, "kind": t.get("amenity") or t.get("shop"), "name": t.get("name", "")})
        continue
    geom = el.get("geometry")
    if not geom:
        continue
    pts = [proj(g["lat"], g["lon"]) for g in geom]
    if not inside(pts, 200):
        continue
    closed = el["nodes"][0] == el["nodes"][-1]
    if "highway" in t:
        hw = t["highway"]
        if hw not in RANK:
            continue
        lines.append({"k": "road", "c": hw, "r": RANK[hw], "name": t.get("name", ""), "pts": pts,
                      "ids": [nid(n, p) for n, p in zip(el["nodes"], pts)] if hw in SPEED else None})
        if hw in SPEED:
            ow = t.get("oneway")
            oneway = ow in ("yes", "1", "true") or hw in ("motorway", "motorway_link") or t.get("junction") == "roundabout"
            if ow == "-1":
                el["nodes"], pts = el["nodes"][::-1], pts[::-1]
                oneway = True
            ni = name_id(t.get("name") or t.get("ref") or "")
            for (a, b), pa, pb in zip(zip(el["nodes"], el["nodes"][1:]), pts, pts[1:]):
                edges.append([nid(a, pa), nid(b, pb), round(math.dist(pa, pb), 1), SPEED[hw], ni, 1 if oneway else 0, RANK[hw]])
    elif "railway" in t and t["railway"] in ("rail", "light_rail"):
        lines.append({"k": "rail", "pts": pts, "tunnel": t.get("tunnel") == "yes"})
    elif "waterway" in t and not closed:
        lines.append({"k": "water", "c": t["waterway"], "pts": pts})
    elif closed:
        k = area_kind(t)
        if k:
            areas.append({"k": k, "pts": pts})

for l in lines:
    if l.get("ids") is None:
        l.pop("ids", None)

# Orte für die Suche (ohne Gedenksteine/Stolpersteine – Personennamen gehören nicht in eine Navi-Suche)
search, seen = [], set()
KIND = {"restaurant": "Restaurant", "cafe": "Café", "fast_food": "Imbiss", "fuel": "Tankstelle", "parking": "Parkplatz",
        "pharmacy": "Apotheke", "school": "Schule", "townhall": "Rathaus", "bank": "Bank", "doctors": "Arztpraxis",
        "supermarket": "Supermarkt", "bakery": "Bäckerei", "attraction": "Sehenswürdigkeit", "hotel": "Hotel",
        "kindergarten": "Kita", "place_of_worship": "Kirche", "library": "Bücherei", "post_office": "Post",
        "charging_station": "Ladesäule", "bus_stop": "Haltestelle", "station": "Bahnhof", "clothes": "Mode",
        "beverages": "Getränke", "car": "Autohaus", "shoes": "Schuhe", "butcher": "Metzgerei", "optician": "Optiker",
        "dentist": "Zahnarzt", "swimming_pool": "Schwimmbad", "hairdresser": "Friseur", "kiosk": "Kiosk", "florist": "Blumen",
        "pub": "Kneipe", "ice_cream": "Eis", "museum": "Museum", "theatre": "Theater", "cinema": "Kino", "sports_centre": "Sport",
        "park": "Park", "playground": "Spielplatz", "car_repair": "Werkstatt", "drugstore": "Drogerie", "chemist": "Drogerie"}
SKIP = {"information", "toilets", "atm", "bench", "waste_basket", "vending_machine", "recycling"}
for src in (named_src, extra_src):
    for el in json.load(open(src, encoding="utf-8"))["elements"]:
        t = el.get("tags", {})
        n = t.get("name")
        if not n or t.get("historic") in ("memorial", "stone") or t.get("memorial") or "highway" in t and t["highway"] != "bus_stop":
            continue
        lat = el.get("lat", el.get("center", {}).get("lat"))
        lon = el.get("lon", el.get("center", {}).get("lon"))
        if lat is None:
            continue
        kind = t.get("tourism") if t.get("tourism") in KIND else t.get("amenity") or t.get("shop") or t.get("tourism") or t.get("leisure") or ""
        if kind in SKIP or n.startswith("IDS-"):
            continue
        if t.get("railway") == "station" or n == "Idstein Bahnhof":
            kind = "station"
        key = (n, kind)
        if key in seen:
            continue
        seen.add(key)
        search.append({"name": n, "kind": kind, "label": KIND.get(kind, kind.replace("_", " ").title() if kind else "Ort"),
                       "p": proj(lat, lon), "street": t.get("addr:street", ""), "no": t.get("addr:housenumber", "")})

out = {"origin": [LAT0, LON0], "extent": [HALF_W, HALF_H], "areas": areas, "lines": lines, "pois": pois, "places": places,
       "graph": {"nodes": nodes, "edges": edges, "names": names}, "search": search,
       "presets": {"start": proj(50.21712, 8.25734), "home": proj(50.2270, 8.2800), "work": proj(50.2132, 8.2548),
                   "hexenturm": proj(50.22205, 8.26856)}}
json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(f"{len(areas)} Flächen, {len(lines)} Linien, {len(nodes)} Knoten, {len(edges)} Kanten, {len(search)} Suchorte, {len(places)} Ortsteile")
