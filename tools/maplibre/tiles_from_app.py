"""GM-070: Stil-Vorschauen (Shop, Onboarding, CarPlay-Auswahl) aus echten App-Bildern statt aus der Web-Vorschau.
Nutzer: „die Vorschaubilder sehen kacke aus und sind nicht mal richtig“ – die Web-Vorschau zeichnet z. B. Pixel Quest mit
Ersatz-Mustern statt der App-Texturen.

Vorher: bash tools/mac_screens.sh tests  (legt docs/store/tests/stil-<stil>-karte.png an, 1320 × 2868, Simulator)
Aufruf: python tools/maplibre/tiles_from_app.py
Ergebnis: App/Assets.xcassets/StyleTiles/style-<stil>.imageset (JPEG 240 × 160 pt, 1×/2×/3×) und docs/store/stile/<stil>.png
"""
import pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
STYLES = ["classic", "neon-city", "wild-west", "pixel-quest", "toy-town"]
for st in STYLES:
    src = ROOT / "docs" / "store" / "tests" / f"stil-{st}-karte.png"
    if not src.exists():
        print("fehlt:", src.name); continue
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # Ausschnitt um den Standort (Mitte, etwa halbe Höhe), links von den Knöpfen, ohne Statusleiste und Leiste unten
    cw = int(w * 0.70); ch = cw * 2 // 3
    cx, cy = w // 2 - int(w * 0.07), int(h * 0.50)
    tile = im.crop((cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2))
    d = ROOT / "App" / "Assets.xcassets" / "StyleTiles" / f"style-{st}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    for sc, sfx in ((1, ""), (2, "@2x"), (3, "@3x")):
        tile.resize((240 * sc, 160 * sc), Image.Resampling.LANCZOS).save(d / f"style-{st}{sfx}.jpg", quality=88)
    tile.resize((720, 480), Image.Resampling.LANCZOS).save(ROOT / "docs" / "store" / "stile" / f"{st}.png")
    print("Kachel:", st)
