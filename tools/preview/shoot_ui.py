"""Rendert Karten-Hintergründe und UI-Entwürfe, dazu Übersichtsbilder mit iPhone-Rahmen.

Aufruf: python shoot_ui.py
"""
from PIL import Image, ImageDraw

from shotlib import ROOT, shooter

OUT = ROOT / "out"
STYLES = ["neon", "western", "pixel"]
BG = {"phone-home": "style=neon&mode=iphone&route=0",
      "phone-fog": "style=neon&mode=overview&w=1179&h=2556&scale=0.42&cx=0&cy=900&route=0&fog=1",
      "car-browse": "style=neon&mode=carplay&route=0",
      "car-preview": "style=neon&mode=overview&w=1780&h=720&scale=0.38&cx=-763&cy=0&progress=0"}
for s in STYLES:
    BG[f"phone-nav-{s}"] = f"style={s}&mode=iphone"
    BG[f"phone-preview-{s}"] = f"style={s}&mode=overview&w=1179&h=2556&scale=0.62&cx=0&cy=800&progress=0"
    BG[f"car-nav-{s}"] = f"style={s}&mode=carplay"
PHONE = ["phone-home", "phone-search", "phone-preview-neon", "phone-nav-neon", "phone-explore", "phone-styles"] + \
        [f"phone-{k}-{s}" for s in ("western", "pixel") for k in ("preview", "nav")]
CAR = ["car-browse", "car-list", "car-preview"] + [f"car-nav-{s}" for s in STYLES]


def size_of(q):
    w = int(q.split("w=")[1].split("&")[0]) if "w=" in q else (1179 if "iphone" in q else 1780)
    return w, 2556 if w == 1179 else 720


def framed(path, scale=1 / 3):
    """Bildschirm mit abgerundeten Ecken (55 pt) in einen schlichten iPhone-Rahmen setzen."""
    scr = Image.open(path).convert("RGBA")
    w, h = scr.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=165, fill=255)
    bez = 54
    frame = Image.new("RGBA", (w + 2 * bez, h + 2 * bez), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle((0, 0, w + 2 * bez - 1, h + 2 * bez - 1), radius=165 + bez, fill=(18, 18, 20, 255), outline=(120, 118, 114, 255), width=8)
    frame.paste(scr, (bez, bez), mask)
    return frame.resize((round(frame.width * scale), round(frame.height * scale)), Image.LANCZOS)


def sheet(names, out, cols):
    tiles = [framed(OUT / f"ui-{n}.png") for n in names]
    tw, th, g = tiles[0].width, tiles[0].height, 40
    rows = (len(tiles) + cols - 1) // cols
    s = Image.new("RGB", (cols * (tw + g) + g, rows * (th + g) + g), (17, 17, 17))
    for i, t in enumerate(tiles):
        s.paste(t, (g + (i % cols) * (tw + g), g + (i // cols) * (th + g)), t)
    s.save(OUT / out)


def car_sheet(names, out):
    w, h, g = 960, 360, 24
    s = Image.new("RGB", (2 * w + 3 * g, ((len(names) + 1) // 2) * (h + g) + g), (17, 17, 17))
    for i, n in enumerate(names):
        s.paste(Image.open(OUT / f"ui-{n}.png").convert("RGB").resize((w, h), Image.LANCZOS), (g + (i % 2) * (w + g), g + (i // 2) * (h + g)))
    s.save(OUT / out)


if __name__ == "__main__":
    with shooter() as shoot:
        for name, q in BG.items():
            w, h = size_of(q)
            shoot(f"render.html?{q}", w, h, "#view", f"bg-{name}.png")
            print("bg", name)
        for n in PHONE:
            shoot(f"ui.html?screen={n}", 1179, 2556, ".screen", f"ui-{n}.png"); print("ui", n)
        for n in CAR:
            shoot(f"ui.html?screen={n}", 1920, 720, ".screen", f"ui-{n}.png"); print("ui", n)
    sheet(PHONE[:6], "sheet-iphone-neon.png", 6)
    sheet(["phone-nav-neon", "phone-nav-western", "phone-nav-pixel", "phone-preview-neon", "phone-preview-western", "phone-preview-pixel"], "sheet-iphone-stile.png", 6)
    car_sheet(CAR[:4], "sheet-carplay-neon.png")
    car_sheet([f"car-nav-{s}" for s in STYLES] + ["car-preview"], "sheet-carplay-stile.png")
    print("fertig")
