"""GM-074: Gemalte Frontier-Kacheln (XYZ, Web-Mercator) aus Höhen und Bodenbedeckung berechnen.

Ablauf je Kachel: Höhen (Copernicus DEM) und Bodenklassen (ESA WorldCover) auf die Kachel umrechnen, Materialien
nach Klasse weich mischen, Relief (Licht 315°) darüberlegen, Ufer abdunkeln, leichter Malfilter. Straßen, Namen und
Route zeichnet die App weiter als Vektoren darüber.

Materialien: tools/terrain/materials/<name>.png (nahtlos, von Codex – Prompts in docs/FRONTIER_KACHELN.md). Fehlt eine
Datei, nimmt das Skript einen berechneten Platzhalter. Muster werden über Weltpixel gelegt → keine Kanten zwischen Kacheln.

Aufruf:  python tools/terrain/render_tiles.py preview            → Vorschaubild Taunus (Zoom 11, 12, 14) in docs/frontier-v2/
         python tools/terrain/render_tiles.py tiles Z0 Z1 [bbox]  → Kacheln nach EzMapsData/tiles/{z}/{x}/{y}.jpg
"""
import math
import os
import pathlib
import sys

import numpy as np
import rasterio
from PIL import Image, ImageFilter
from rasterio.enums import Resampling
from rasterio.vrt import WarpedVRT
from scipy.ndimage import gaussian_filter

ROOT = pathlib.Path(__file__).resolve().parents[2]
DATA = pathlib.Path(os.environ.get("EZMAPS_DATA", pathlib.Path.home() / "EzMapsData"))
MAT_DIR = ROOT / "tools" / "terrain" / "materials"
MAT_SCALE = 0.35   # GM-084: Materialgröße relativ zu Weltpixeln
MAT_TINT = 0.6     # GM-084: Anteil der Grundfarbe aus der Palette
T = 512           # Kachelgröße in Pixel (512 = scharf auf dem iPhone bei tileSize 512)
R = 6378137.0

# Grundfarben je Material (aus docs/frontier-v2/palette.json, GM-069 satter)
BASE = {"forest": (79, 98, 48), "meadow": (134, 146, 78), "field": (173, 163, 106), "rock": (183, 173, 133),
        "shrub": (112, 120, 64), "wet": (98, 118, 84), "built": (150, 140, 104), "water": (134, 166, 172), "snow": (236, 236, 228)}
# ESA-WorldCover-Klasse → Material
CLASS = {10: "forest", 20: "shrub", 30: "meadow", 40: "field", 50: "built", 60: "rock", 70: "snow", 80: "water", 90: "wet", 95: "wet", 100: "meadow"}


def tile_bounds(z, x, y):
    n = 2 ** z
    size = 2 * math.pi * R / n
    minx = -math.pi * R + x * size
    maxy = math.pi * R - y * size
    return minx, maxy - size, minx + size, maxy


def lonlat_to_tile(lon, lat, z):
    n = 2 ** z
    x = int((lon + 180) / 360 * n)
    y = int((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n)
    return x, y


_open = {}
def sources(kind):
    if kind not in _open:
        _open[kind] = [rasterio.open(p) for p in sorted((DATA / kind).glob("*.tif"))]
    return _open[kind]


def read(kind, bounds, size, resampling):
    """Raster auf die Kachel (EPSG:3857) umrechnen; mehrere Quelldateien werden zusammengesetzt."""
    from rasterio.transform import from_bounds
    out = np.zeros((size, size), dtype=np.float32 if kind == "dem" else np.uint8)
    tr = from_bounds(*bounds, size, size)
    for src in sources(kind):
        with WarpedVRT(src, crs="EPSG:3857", transform=tr, width=size, height=size, resampling=resampling, nodata=0) as v:
            a = v.read(1)
            m = a != 0
            out[m] = a[m]
    return out


def hillshade(dem, cell, az=315, alt=45, exag=2.4):  # GM-084: kräftiger (Zielbild: Gelände ist das Wichtigste)
    dy, dx = np.gradient(dem * exag, cell)
    slope = np.arctan(np.hypot(dx, dy))
    aspect = np.arctan2(-dx, dy)
    a, z = math.radians(360 - az + 90), math.radians(90 - alt)
    hs = np.cos(z) * np.cos(slope) + np.sin(z) * np.sin(slope) * np.cos(a - aspect)
    return np.clip(hs, 0, 1)


def noise(gx, gy, scale, seed):
    """Wertrauschen in Weltpixeln (nahtlos über Kachelgrenzen)."""
    xs, ys = gx / scale, gy / scale
    x0, y0 = np.floor(xs).astype(np.int64), np.floor(ys).astype(np.int64)
    fx, fy = xs - x0, ys - y0
    def h(x, y):
        v = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
        v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b, c, d = h(x0, y0), h(x0 + 1, y0), h(x0, y0 + 1), h(x0 + 1, y0 + 1)
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy


_mats = {}
def material(name, gx, gy):
    """Farbe des Materials an Weltpixeln: Codex-Bild (nahtlos) oder Platzhalter aus Rauschen."""
    p = MAT_DIR / f"{name}.png"
    if p.exists():
        if name not in _mats:
            # GM-084: Codex-Materialien verkleinern (Kronen waren riesig) und Richtung Grundfarbe ziehen (Felder zu gelb)
            im = Image.open(p).convert("RGB")
            im = im.resize((int(im.width * MAT_SCALE), int(im.height * MAT_SCALE)), Image.Resampling.LANCZOS)
            a = np.asarray(im, dtype=np.float32)
            base = np.array(BASE[name], dtype=np.float32)
            mean = a.reshape(-1, 3).mean(0)
            _mats[name] = (a - mean) * 0.85 + (mean * (1 - MAT_TINT) + base * MAT_TINT)
        m = _mats[name]
        return m[(gy % m.shape[0]).astype(np.int64), (gx % m.shape[1]).astype(np.int64)]
    base = np.array(BASE[name], dtype=np.float32)
    n = 0.55 * noise(gx, gy, 6, 1) + 0.3 * noise(gx, gy, 23, 2) + 0.15 * noise(gx, gy, 90, 3)
    k = {"forest": 0.55, "meadow": 0.3, "field": 0.25, "rock": 0.3, "shrub": 0.4, "wet": 0.3, "built": 0.2, "water": 0.08, "snow": 0.05}[name]
    return base[None, None, :] * (1 - k / 2 + k * n)[..., None]


def render(z, x, y):
    b = tile_bounds(z, x, y)
    cell = (b[2] - b[0]) / T
    pad = 8   # Rand gegen Kanten im Relief
    pb = (b[0] - pad * cell, b[1] - pad * cell, b[2] + pad * cell, b[3] + pad * cell)
    dem = read("dem", pb, T + 2 * pad, Resampling.cubic)
    lc = read("worldcover", pb, T + 2 * pad, Resampling.nearest)
    m_px = cell * math.cos(math.radians(50))   # Meter je Pixel (Mercator etwa auf 50° Breite)
    # Höhen nur alle 30 m: nah glätten, sonst Treppen im Relief
    sig = 12.0 / m_px
    if sig > 0.6:
        dem = gaussian_filter(dem, sig)
    hs = hillshade(dem, m_px)
    gx, gy = np.meshgrid(np.arange(-pad, T + pad) + x * T, np.arange(-pad, T + pad) + y * T)
    rgb = np.zeros((T + 2 * pad, T + 2 * pad, 3), dtype=np.float32)
    wsum = np.zeros((T + 2 * pad, T + 2 * pad), dtype=np.float32)
    blur = max(1.2, 9.0 / m_px)   # Bodenklassen nur alle 10 m: Übergänge weich statt eckig
    for cls, name in CLASS.items():
        m = (lc == cls).astype(np.float32)
        if not m.any():
            continue
        w = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255
        rgb += material(name, gx, gy) * w[..., None]
        wsum += w
    none = wsum < 1e-3
    rgb[none] = BASE["meadow"]
    wsum[none] = 1
    rgb /= wsum[..., None]
    water = (lc == 80).astype(np.float32)
    # Relief: Schatten olivbraun, Licht warm – nicht auf Wasser
    shade = (hs - 0.6) * 1.7
    tint = np.where(shade[..., None] < 0, np.array([35, 43, 20], np.float32), np.array([234, 223, 184], np.float32))
    a = np.clip(np.abs(shade), 0, 0.85)[..., None] * (1 - water[..., None])
    rgb = rgb * (1 - a) + tint * a
    # Ufer: dunkler Rand um Wasser
    wb = np.asarray(Image.fromarray((water * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2)), dtype=np.float32) / 255
    edge = np.clip((wb - water) * 2.2, 0, 1)[..., None]
    rgb = rgb * (1 - edge) + np.array([102, 111, 74], np.float32) * edge
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).crop((pad, pad, pad + T, pad + T))
    return img.filter(ImageFilter.SMOOTH)   # leichter Malfilter


def preview():
    out = ROOT / "docs" / "frontier-v2"
    lon, lat = 8.268, 50.2215
    shots = []
    for z, k in ((11, 2), (12, 2), (14, 2)):
        cx, cy = lonlat_to_tile(lon, lat, z)
        im = Image.new("RGB", (T * k, T * k))
        for dy in range(k):
            for dx in range(k):
                im.paste(render(z, cx - k // 2 + dx, cy - k // 2 + dy), (dx * T, dy * T))
        p = out / f"kacheln-z{z}.jpg"
        im.save(p, quality=88)
        shots.append(p)
        print("Vorschau", p.relative_to(ROOT), flush=True)


def tiles(z0, z1, bbox):
    w, s, e, n = bbox
    for z in range(z0, z1 + 1):
        x0, y0 = lonlat_to_tile(w, n, z)
        x1, y1 = lonlat_to_tile(e, s, z)
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                p = DATA / "tiles" / str(z) / str(x) / f"{y}.jpg"
                if p.exists():
                    continue
                p.parent.mkdir(parents=True, exist_ok=True)
                render(z, x, y).save(p, quality=84)
        print("Zoom", z, "fertig", flush=True)


if __name__ == "__main__":
    if (sys.argv[1:] or ["preview"])[0] == "preview":
        preview()
    else:
        z0, z1 = int(sys.argv[2]), int(sys.argv[3])
        bbox = tuple(map(float, sys.argv[4].split(","))) if len(sys.argv) > 4 else (5.8, 47.2, 15.1, 55.1)
        tiles(z0, z1, bbox)
