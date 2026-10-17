"""Baut tools/prototype/data/hillshade.png (Hügel-Schattierung) für den Kartenausschnitt.

Quelle: „Terrain Tiles“ (AWS Open Data, früher Mapzen), Terrarium-Kodierung, Zoom 14.
Datenquellen u. a. SRTM (NASA, gemeinfrei) und EU-DEM (© Copernicus) – Hinweis in der App nennen.

Aufruf (aus tools/prototype): python hillshade.py
Rohkacheln liegen in raw/dem/ (nicht im Repo).
"""
import math
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).parent
LAT0, LON0 = 50.2215, 8.2680                 # wie prep.py
TEX = dict(x0=-1800, y0=-1500, w=3600, h=3000)  # wie js/map.js
RES = 4.0                                      # Meter pro Bildpunkt
Z = 14
KX = math.cos(math.radians(LAT0)) * 111320.0
KY = 110540.0



# Kacheln zu einem Mosaik zusammensetzen, dann bilinear abtasten (GM-010: kein Kachelraster)
xs, ys = [], []
for f in (ROOT / "raw" / "dem").glob(f"{Z}_*.png"):
    _, tx, ty = f.stem.split("_"); xs.append(int(tx)); ys.append(int(ty))
tx0, ty0 = min(xs), min(ys)
mosaic = np.zeros(((max(ys) - ty0 + 1) * 256, (max(xs) - tx0 + 1) * 256))
for tx in range(tx0, max(xs) + 1):
    for ty in range(ty0, max(ys) + 1):
        im = np.asarray(Image.open(ROOT / "raw" / "dem" / f"{Z}_{tx}_{ty}.png").convert("RGB"), dtype=np.float64)
        mosaic[(ty - ty0) * 256:(ty - ty0 + 1) * 256, (tx - tx0) * 256:(tx - tx0 + 1) * 256] = im[..., 0] * 256 + im[..., 1] + im[..., 2] / 256 - 32768

W, H = int(TEX["w"] / RES), int(TEX["h"] / RES)
cc, rr = np.meshgrid(np.arange(W), np.arange(H))
lat = LAT0 - (TEX["y0"] + (rr + 0.5) * RES) / KY
lon = LON0 + (TEX["x0"] + (cc + 0.5) * RES) / KX
n = 2 ** Z
px = ((lon + 180) / 360 * n - tx0) * 256 - 0.5
py = ((1 - np.log(np.tan(np.radians(lat)) + 1 / np.cos(np.radians(lat))) / np.pi) / 2 * n - ty0) * 256 - 0.5
i0, j0 = np.floor(py).astype(int), np.floor(px).astype(int)
fy, fx = py - i0, px - j0
g = lambda i, j: mosaic[np.clip(i, 0, mosaic.shape[0] - 1), np.clip(j, 0, mosaic.shape[1] - 1)]
dem = g(i0, j0) * (1 - fx) * (1 - fy) + g(i0, j0 + 1) * fx * (1 - fy) + g(i0 + 1, j0) * (1 - fx) * fy + g(i0 + 1, j0 + 1) * fx * fy

# weich glätten (Gauß 7×7)
k1 = np.exp(-np.arange(-3, 4) ** 2 / 4.5); k1 /= k1.sum()
pad = np.pad(dem, 3, mode="edge")
tmp = sum(pad[:, j:j + W] * k1[j] for j in range(7))
dem = sum(tmp[i:i + H, :] * k1[i] for i in range(7))

dy, dx = np.gradient(dem, RES)
slope = np.arctan(np.hypot(dx, dy) * 1.6)        # etwas überhöht, damit der Taunus sichtbar wird
aspect = np.arctan2(-dx, dy)
az, alt = math.radians(315), math.radians(45)
shade = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
shade = np.clip(shade, 0, 1)
flat = math.sin(alt)
out = np.clip(128 + (shade - flat) * 260, 0, 255).astype(np.uint8)   # 128 = flach (neutral für „overlay“)
Image.fromarray(out, "L").save(ROOT / "data" / "hillshade.png", optimize=True)
print("hillshade.png", out.shape, "Höhe", round(dem.min()), "–", round(dem.max()), "m")
