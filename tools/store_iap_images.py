"""GM-050: Werbebilder für die In-App-Käufe (App Store Connect → In-App-Käufe/Abos → „Werbebild“).
Apple: 1024 × 1024 px, RGB ohne Transparenz, keine runden Ecken (rundet Apple selbst), kein Preis im Bild.
Quelle: echte Stil-Vorschauen aus docs/store/stile (python tools/maplibre/render_previews.py).
Aufruf: python tools/store_iap_images.py → docs/store/iap/<Produkt-ID>.png
"""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC, OUT = ROOT / "docs" / "store" / "stile", ROOT / "docs" / "store" / "iap"
SINGLE = {"neon-city": "ezmaps.style.neon", "wild-west": "ezmaps.style.western",
          "pixel-quest": "ezmaps.style.pixel", "toy-town": "ezmaps.style.toy"}  # Core/Purchases.swift ProductID.single
PLUS = ["ezmaps.plus.monthly", "ezmaps.plus.yearly", "ezmaps.plus.lifetime"]


def square(im, size):
    w, h = im.size
    c = min(w, h)
    return im.crop(((w - c) // 2, (h - c) // 2, (w - c) // 2 + c, (h - c) // 2 + c)).resize((size, size), Image.Resampling.LANCZOS)


OUT.mkdir(parents=True, exist_ok=True)
for f in OUT.glob("*.png"):
    f.unlink()
tiles = {s: Image.open(SRC / f"{s}.png").convert("RGB") for s in SINGLE}
for style, pid in SINGLE.items():
    square(tiles[style], 1024).save(OUT / f"{pid}.png")
grid = Image.new("RGB", (1024, 1024), (11, 11, 13))
for i, style in enumerate(SINGLE):
    grid.paste(square(tiles[style], 508), ((i % 2) * 516, (i // 2) * 516))
for pid in PLUS:
    grid.save(OUT / f"{pid}.png")
print("Werbebilder:", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))
