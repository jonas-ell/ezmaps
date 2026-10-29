"""GM-029: Prüft App/MapStyles/style-neon-city.json, ohne Mac.

- Stil ist aktuell (build_style.py erzeugt dieselbe Datei)
- jede Schrift (text-font) hat Glyph-Dateien in Resources/Glyphs
- jedes Kartensymbol (icon-image) wird in App/NeonMapView.swift (poiImages) gezeichnet
- Pflicht-Hinweis © OpenStreetMap steht in der Quelle
- optional: offizieller MapLibre-Validator (npx gl-style-validate), falls Node da ist

Aufruf: python tools/maplibre/check_style.py   (Exit 1 bei Fehlern)
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
STYLES = sorted((ROOT / "App" / "MapStyles").glob("style-*.json"))  # GM-031: alle Stile
errors = []

before = {p: p.read_bytes() for p in STYLES}
subprocess.run([sys.executable, str(ROOT / "tools" / "maplibre" / "build_style.py")], check=True, capture_output=True)
for p in STYLES:
    if p.read_bytes().replace(bytes([13, 10]), bytes([10])) != before[p].replace(bytes([13, 10]), bytes([10])):
        errors.append(f"{p.name} war nicht aktuell (build_style.py neu ausgeführt – bitte committen)")
swift = (ROOT / "App" / "NeonMapView.swift").read_text(encoding="utf-8")
drawn = set(re.findall(r'"(ez-(?:poi|pat)-[a-z0-9-]+)"', swift))  # GM-050: auch Muster (fill-pattern, background-pattern)
# GM-057: Symbole je Art und Stil (RouteOverlay.poiKinds × poiSuffixes)
_kinds = re.search(r"poiKinds: \[String: \(String, UIColor\)\] = \[(.*?)\n    \]", swift, re.S)
_suff = re.search(r"poiSuffixes = \[(.*?)\]", swift)
if _kinds and _suff:
    for k in re.findall(r'"([a-z]+)": \(', _kinds.group(1)):
        for sfx in re.findall(r'"([a-z0-9-]*)"', _suff.group(1)):  # GM-068: auch "-fv2"
            drawn.add(f"ez-poi-{k}{sfx}")
fonts_all = set()
for STYLE in STYLES:
    style = json.loads(STYLE.read_text(encoding="utf-8"))
    ids = [l["id"] for l in style["layers"]]
    if len(ids) != len(set(ids)):
        errors.append(f"{STYLE.name}: doppelte Ebenen-IDs")
    fonts = set()
    for l in style["layers"]:
        f = l.get("layout", {}).get("text-font")
        if f:
            fonts.update(f)
    fonts_all |= fonts
    for f in fonts:
        for rng in ("0-255", "256-511", "8192-8447"):
            if not (ROOT / "Resources" / "Glyphs" / f / f"{rng}.pbf").exists():
                errors.append(f"{STYLE.name}: Glyphen fehlen: {f}/{rng}.pbf")
    if fonts and not style.get("glyphs", "").startswith("asset://"):
        errors.append(f"{STYLE.name}: glyphs zeigt nicht auf das App-Bundle (asset://)")
    used = set()
    for l in style["layers"]:
        expr = [l.get("layout", {}).get("icon-image"), l.get("paint", {})]  # GM-050: auch fill-/line-/background-pattern
        if any(expr):
            used.update(x for x in json.dumps(expr).split('"') if x.startswith(("ez-poi-", "ez-pat-")))
    for name in sorted(used - drawn):
        errors.append(f"{STYLE.name}: Symbol {name} wird nicht in poiImages gezeichnet")
    if "OpenStreetMap" not in json.dumps(style["sources"]):
        errors.append(f"{STYLE.name}: Hinweis © OpenStreetMap fehlt")

if shutil.which("npx"):
    for STYLE in STYLES:
        r = subprocess.run("npx --yes -p @maplibre/maplibre-gl-style-spec@20 gl-style-validate " + f'"{STYLE}"',
                           shell=True, capture_output=True, text=True, timeout=300)
        if r.returncode != 0:
            errors.append(f"{STYLE.name} gl-style-validate: " + (r.stdout + r.stderr).strip()[:400])

print(f"Stile: {len(STYLES)}, Schriften {sorted(fonts_all)}")
for e in errors:
    print("FEHLER:", e)
print("STIL OK" if not errors else f"{len(errors)} Fehler")
sys.exit(1 if errors else 0)
