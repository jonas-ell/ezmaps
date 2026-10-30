#!/usr/bin/env python3
"""GM-090: Land/Wasser-Maske der Erde für die Pixel-Quest-Würfel-Erde.

Quelle: Natural Earth 1:50m Land (gemeinfrei), als TopoJSON aus dem npm-Paket world-atlas@2.0.2.
Ausgabe: 720 × 360 Bit (0,5°), Zeilen von Nord (+90°) nach Süd, Spalten von −180° nach Osten, MSB zuerst,
als Base64 in
  Core/Sources/EzMapsCore/LandMaskData.swift   (App, getestet)
  tools/prototype/js/landmask.js              (Prototyp)
Aufruf: python tools/cube/build_landmask.py  (lädt die Quelle, wenn nicht als Argument angegeben)
Nicht von Hand ändern – nur neu erzeugen.
"""
import base64, json, os, sys, urllib.request
from PIL import Image, ImageDraw

W, H, SS = 720, 360, 4
URL = "https://unpkg.com/world-atlas@2.0.2/land-50m.json"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(path):
    if path:
        return json.load(open(path))
    with urllib.request.urlopen(URL) as r:
        return json.loads(r.read())


def arcs_of(topo):
    sx, sy = topo["transform"]["scale"]
    tx, ty = topo["transform"]["translate"]
    out = []
    for arc in topo["arcs"]:
        x = y = 0
        pts = []
        for dx, dy in arc:
            x += dx; y += dy
            pts.append((x * sx + tx, y * sy + ty))
        out.append(pts)
    return out


def ring(arcs, idx):
    pts = []
    for i in idx:
        a = arcs[i] if i >= 0 else arcs[~i][::-1]
        pts.extend(a if not pts else a[1:])
    return pts


def main():
    topo = load(sys.argv[1] if len(sys.argv) > 1 else None)
    arcs = arcs_of(topo)
    img = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(img)
    px = lambda p: ((p[0] + 180) / 360 * W * SS, (90 - p[1]) / 180 * H * SS)
    for g in topo["objects"]["land"]["geometries"]:
        polys = g["arcs"] if g["type"] == "MultiPolygon" else [g["arcs"]]
        for poly in polys:
            for k, r in enumerate(poly):
                # Ringe über die Datumsgrenze (Tschukotka, Antarktis) entfalten und dreifach versetzt zeichnen –
                # sonst ziehen sie Streifen quer über die Karte
                raw = ring(arcs, r)
                if len(raw) < 3:
                    continue
                flat = [raw[0]]
                for lon, lat in raw[1:]:
                    prev = flat[-1][0]
                    while lon - prev > 180: lon -= 360
                    while lon - prev < -180: lon += 360
                    flat.append((lon, lat))
                for shift in (-360, 0, 360):
                    d.polygon([px((lon + shift, lat)) for lon, lat in flat], fill=255 if k == 0 else 0)
    small = img.resize((W, H), Image.BOX)
    # Antarktis bis zum Pol (Quelle endet knapp davor)
    for y in range(int((90 + 85) / 180 * H), H):
        for x in range(W):
            small.putpixel((x, y), 255)
    bits = bytearray(W * H // 8)
    land = 0
    for y in range(H):
        for x in range(W):
            if small.getpixel((x, y)) >= 128:
                i = y * W + x
                bits[i >> 3] |= 0x80 >> (i & 7)
                land += 1
    b64 = base64.b64encode(bytes(bits)).decode()
    note = "GM-090: erzeugt von tools/cube/build_landmask.py (Natural Earth 1:50m, gemeinfrei) – nicht von Hand ändern"
    lines = [b64[i:i + 120] for i in range(0, len(b64), 120)]
    swift = (f"// {note}\n\nextension LandMask {{\n    static let worldWidth = {W}\n    static let worldHeight = {H}\n"
             "    static let worldBase64 = \"\"\"\n" + "\n".join("        " + l for l in lines) + "\n        \"\"\"\n}\n")
    js = (f"// {note}\nwindow.LANDMASK = {{ width: {W}, height: {H}, base64:\n" +
          " +\n".join(f"  '{l}'" for l in lines) + " };\n")
    open(os.path.join(ROOT, "Core/Sources/EzMapsCore/LandMaskData.swift"), "w").write(swift)
    open(os.path.join(ROOT, "tools/prototype/js/landmask.js"), "w").write(js)
    print(f"MASKE OK: {W}×{H}, Land {land / (W * H) * 100:.1f} %")


if __name__ == "__main__":
    main()
