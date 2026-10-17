"""Bereitet Overpass-JSON für die Stil-Vorschau auf: Ebenen in Metern + Route (Dijkstra).

Aufruf: python prep.py data/idstein.json out/scene.json START_LAT,START_LON ZIEL_LAT,ZIEL_LON
"""
import heapq
import json
import math
import sys

src, dst = sys.argv[1], sys.argv[2]
start = tuple(map(float, sys.argv[3].split(",")))
goal = tuple(map(float, sys.argv[4].split(",")))

LAT0, LON0 = (start[0] + goal[0]) / 2, (start[1] + goal[1]) / 2
KX = math.cos(math.radians(LAT0)) * 111320.0
KY = 110540.0


def proj(lat, lon):
    return (round((lon - LON0) * KX, 1), round(-(lat - LAT0) * KY, 1))


def area_kind(t):
    if "building" in t:
        return "building"
    v = t.get("natural") or t.get("landuse") or t.get("leisure")
    if t.get("natural") == "water" or t.get("landuse") in ("reservoir", "basin"):
        return "water"
    if v in ("wood", "forest", "scrub"):
        return "forest"
    if v in ("grass", "meadow", "grassland", "park", "garden", "recreation_ground",
             "village_green", "allotments", "orchard", "cemetery", "pitch", "playground"):
        return "park"
    if v in ("farmland", "farmyard", "vineyard"):
        return "farm"
    if v in ("industrial", "commercial", "retail", "railway", "construction"):
        return "industrial"
    if v == "residential":
        return "residential"
    return None


ROAD_RANK = {
    "motorway": 0, "motorway_link": 1, "trunk": 1, "trunk_link": 2, "primary": 2,
    "primary_link": 3, "secondary": 3, "secondary_link": 4, "tertiary": 4,
    "tertiary_link": 5, "unclassified": 5, "residential": 5, "living_street": 6,
    "service": 7, "track": 8, "footway": 9, "path": 9, "cycleway": 9, "pedestrian": 6,
    "steps": 9,
}
SPEED_COST = {"motorway": 0.5, "trunk": 0.6, "primary": 0.8, "secondary": 0.9, "tertiary": 1.0,
              "residential": 1.8, "unclassified": 1.5, "living_street": 3.0, "service": 3.0}
DRIVABLE = {k for k, v in ROAD_RANK.items() if v <= 6 and k != "pedestrian"}

data = json.load(open(src, encoding="utf-8"))
areas, lines, pois, places = [], [], [], []
graph = {}
coords = {}

for el in data["elements"]:
    t = el.get("tags", {})
    if el["type"] == "node":
        p = proj(el["lat"], el["lon"])
        if "place" in t and "name" in t:
            places.append({"p": p, "name": t["name"], "kind": t["place"]})
        else:
            kind = t.get("amenity") or t.get("shop")
            pois.append({"p": p, "kind": kind, "name": t.get("name", "")})
        continue
    geom = el.get("geometry")
    if not geom:
        continue
    pts = [proj(g["lat"], g["lon"]) for g in geom]
    closed = el["nodes"][0] == el["nodes"][-1]
    if "highway" in t:
        hw = t["highway"]
        if hw not in ROAD_RANK:
            continue
        lines.append({"k": "road", "c": hw, "r": ROAD_RANK[hw], "name": t.get("name", ""),
                      "ref": t.get("ref", ""), "bridge": t.get("bridge") == "yes", "pts": pts})
        if hw in DRIVABLE:
            ow = t.get("oneway")
            oneway = ow in ("yes", "1", "true") or hw in ("motorway", "motorway_link") or t.get("junction") == "roundabout"
            rev = ow == "-1"
            for (a, b), pa, pb in zip(zip(el["nodes"], el["nodes"][1:]), pts, pts[1:]):
                coords[a], coords[b] = pa, pb
                d = math.dist(pa, pb) * SPEED_COST.get(hw, 2.0)
                if not rev:
                    graph.setdefault(a, []).append((b, d, t.get("name", t.get("ref", ""))))
                if not oneway or rev:
                    graph.setdefault(b, []).append((a, d, t.get("name", t.get("ref", ""))))
    elif "railway" in t and t["railway"] in ("rail", "light_rail"):
        lines.append({"k": "rail", "pts": pts, "tunnel": t.get("tunnel") == "yes"})
    elif "waterway" in t and not closed:
        lines.append({"k": "water", "c": t["waterway"], "pts": pts})
    elif closed:
        k = area_kind(t)
        if k:
            areas.append({"k": k, "pts": pts})


def nearest(latlon):
    p = proj(*latlon)
    return min(graph, key=lambda n: math.dist(coords[n], p))


s, g = nearest(start), nearest(goal)
dist, prev = {s: 0.0}, {}
pq = [(0.0, s)]
while pq:
    d, n = heapq.heappop(pq)
    if n == g:
        break
    if d > dist[n]:
        continue
    for m, w, name in graph.get(n, []):
        nd = d + w
        if nd < dist.get(m, 1e18):
            dist[m], prev[m] = nd, (n, name)
            heapq.heappush(pq, (nd, m))

path, names = [g], []
while path[-1] != s:
    n, name = prev[path[-1]]
    names.append(name)
    path.append(n)
path.reverse()
names.reverse()
route = [coords[n] for n in path]


def bearing(a, b):
    return math.degrees(math.atan2(b[0] - a[0], -(b[1] - a[1])))


# Abbiegepunkte: Straßennamenwechsel; Winkel aus 25 m davor/danach (robust gegen kleine Knicke)
cum = [0.0]
for a, b in zip(route, route[1:]):
    cum.append(cum[-1] + math.dist(a, b))


def at(d):
    d = max(0.0, min(cum[-1], d))
    for i in range(1, len(route)):
        if cum[i] >= d:
            t = (d - cum[i - 1]) / ((cum[i] - cum[i - 1]) or 1)
            a, b = route[i - 1], route[i]
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    return route[-1]


maneuvers = []
for i in range(1, len(route) - 1):
    if names[i - 1] == names[i]:
        continue
    d = cum[i]
    turn = (bearing(route[i], at(d + 25)) - bearing(at(d - 25), route[i]) + 540) % 360 - 180
    if abs(turn) < 30:
        continue
    if maneuvers and d - maneuvers[-1]["at"] < 30:
        maneuvers.pop()
    maneuvers.append({"at": round(d, 1), "turn": round(turn), "street": names[i] or names[min(i + 1, len(names) - 1)], "p": route[i]})
acc = cum[-2]
total = acc + math.dist(route[-2], route[-1])

json.dump({"origin": [LAT0, LON0], "routeNames": names, "areas": areas, "lines": lines, "pois": pois, "places": places,
           "route": route, "routeLength": round(total), "maneuvers": maneuvers},
          open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(f"{len(areas)} Flächen, {len(lines)} Linien, {len(pois)} POIs, Route {total:.0f} m, "
      f"{len(maneuvers)} Abbiegungen: " + "; ".join(f"{m['at']:.0f} m {m['turn']:+d}° {m['street']}" for m in maneuvers))
