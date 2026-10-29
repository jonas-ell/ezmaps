"""GM-049: Stil-Vorschauen „wie im Einsatz in CarPlay“ aus den echten App-Stilen rendern.

Vorher in einem zweiten Fenster: python tools/prototype/serve.py (Server auf Port 8765, Repo-Hauptordner).
Aufruf: python tools/maplibre/render_previews.py
Ergebnis: App/Assets.xcassets/StyleTiles/style-<stil>.imageset (JPEG 1×/2×/3×, 240 × 160 pt) und docs/store/stile/<stil>.png zum Ansehen.
"""
import asyncio
import json
import pathlib

from PIL import Image
from playwright.async_api import async_playwright

ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "http://localhost:8765/tools/prototype/stylepreview.html"
STYLES = ["classic", "neon-city", "wild-west", "pixel-quest", "toy-town", "frontier"]
W, H = 240, 160  # Punkte; Karten im Onboarding/Shop schneiden mit scaledToFill zu


async def main():
    shots = ROOT / "docs" / "store" / "stile"
    shots.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        for st in STYLES:
            # in CarPlay-Größe rendern (720 × 480 = 3× der Vorschau) – dann ist es ein verkleinertes CarPlay-Bild
            pg = await b.new_page(viewport={"width": W * 3, "height": H * 3}, device_scale_factor=1)
            await pg.goto(f"{URL}?style={st}")
            await pg.wait_for_function("document.title == 'ready'", timeout=120000)
            out = shots / f"{st}.png"
            await pg.screenshot(path=str(out))
            master = Image.open(out).convert("RGB")
            d = ROOT / "App" / "Assets.xcassets" / "StyleTiles" / f"style-{st}.imageset"
            for f in d.glob("*.*"):
                f.unlink()
            imgs = []
            for s in (1, 2, 3):
                name = f"style-{st}.jpg" if s == 1 else f"style-{st}@{s}x.jpg"
                master.resize((W * s, H * s), Image.Resampling.LANCZOS).save(d / name, quality=86, optimize=True)
                imgs.append({"filename": name, "idiom": "universal", "scale": f"{s}x"})
            (d / "Contents.json").write_text(json.dumps({"images": imgs, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
            await pg.close()
            print("Vorschau:", st)
        await b.close()


asyncio.run(main())
