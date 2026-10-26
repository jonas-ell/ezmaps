"""Erzeugt MapLibre-Schriftdateien (SDF-Glyphen, .pbf) aus einer TTF – für die Straßennamen in Neon City.

Warum selbst: OpenFreeMap bietet nur Noto Sans; die Vorlage des Nutzers hat eine schmale, fette Schrift.
Schrift: Barlow Condensed (SIL Open Font License 1.1, OFL.txt liegt daneben) – darf in Apps eingebettet werden.

Aufruf: python tools/maplibre/build_glyphs.py <BarlowCondensed-SemiBold.ttf> [Name]
Ausgabe: Resources/Glyphs/<Name>/<start>-<end>.pbf (für die App gebündelt, Stil verweist per asset://)
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt

ROOT = pathlib.Path(__file__).resolve().parents[2]
TTF = sys.argv[1]
NAME = sys.argv[2] if len(sys.argv) > 2 else "Barlow Condensed SemiBold"
OUT = ROOT / "Resources" / "Glyphs" / NAME
SIZE, BUFFER, RADIUS, CUTOFF, SS = 24, 3, 8, 0.25, 4   # wie fontnik / sdf-glyph-foundry
RANGES = [(0, 255), (256, 511), (8192, 8447)]           # Latein, Umlaute, Erweiterung, Satzzeichen

font = ImageFont.truetype(TTF, SIZE * SS)
ascent, _ = font.getmetrics()


def varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def field(num, wire, payload):
    key = varint((num << 3) | wire)
    if wire == 0:
        return key + varint(payload)
    return key + varint(len(payload)) + payload


def zigzag(n):
    return (n << 1) ^ (n >> 31)


def glyph(cp):
    ch = chr(cp)
    advance = round(font.getlength(ch) / SS)
    box = font.getbbox(ch)
    if box[2] <= box[0] or box[3] <= box[1]:
        return field(1, 0, cp) + field(3, 0, 0) + field(4, 0, 0) + field(5, 0, zigzag(0)) + field(6, 0, zigzag(-SIZE)) + field(7, 0, advance)
    x0, y0, x1, y1 = box
    w, h = math.ceil((x1 - x0) / SS), math.ceil((y1 - y0) / SS)
    pad = BUFFER * SS
    img = Image.new("L", (w * SS + 2 * pad, h * SS + 2 * pad), 0)
    ImageDraw.Draw(img).text((pad - x0, pad - y0), ch, font=font, fill=255)
    m = np.asarray(img) > 127
    signed = (distance_transform_edt(~m) - distance_transform_edt(m)) / SS   # >0 außen, in 24-px-Einheiten
    ys = np.arange(h + 2 * BUFFER) * SS + SS // 2
    xs = np.arange(w + 2 * BUFFER) * SS + SS // 2
    d = signed[np.ix_(ys, xs)]
    val = np.clip(255 - 255 * (d / RADIUS + CUTOFF), 0, 255).astype(np.uint8)
    left = round(x0 / SS)
    top = round((ascent - y0) / SS) - SIZE
    return (field(1, 0, cp) + field(2, 2, val.tobytes()) + field(3, 0, w) + field(4, 0, h)
            + field(5, 0, zigzag(left)) + field(6, 0, zigzag(top)) + field(7, 0, advance))


OUT.mkdir(parents=True, exist_ok=True)
cmap = None
try:
    from fontTools.ttLib import TTFont
    cmap = TTFont(TTF).getBestCmap()
except Exception:
    pass
for a, b in RANGES:
    glyphs = b"".join(field(3, 2, glyph(cp)) for cp in range(a, b + 1) if cmap is None or cp in cmap or cp == 32)
    stack = field(1, 2, NAME.encode()) + field(2, 2, f"{a}-{b}".encode()) + glyphs
    (OUT / f"{a}-{b}.pbf").write_bytes(field(1, 2, stack))
print(OUT.relative_to(ROOT), [p.name for p in sorted(OUT.glob("*.pbf"))])
