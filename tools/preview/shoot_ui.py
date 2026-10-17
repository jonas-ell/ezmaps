"""Rendert Karten-Hintergründe (render.html) und UI-Entwürfe (ui.html) nach out/ui-*.png."""
import functools
import http.server
import pathlib
import threading

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "out"
BACKGROUNDS = {
    "phone-home": "mode=iphone&route=0&hud=none&progress=1250",
    "phone-preview": "mode=overview&w=1179&h=2556&scale=0.62&cx=0&cy=800&progress=0&hud=none",
    "phone-fog": "mode=overview&w=1179&h=2556&scale=0.42&cx=0&cy=900&progress=1250&hud=none&route=0&fog=1",
    "car-browse": "mode=carplay&w=1780&route=0&hud=none&progress=1250",
    "car-preview": "mode=overview&w=1780&h=720&scale=0.38&cx=-763&cy=0&progress=0&hud=none",
    "car-nav": "mode=carplay&w=1780&progress=1250",
}
SCREENS = {
    "phone-home": (1179, 2556), "phone-search": (1179, 2556), "phone-preview": (1179, 2556),
    "phone-nav": (1179, 2556), "phone-explore": (1179, 2556), "phone-styles": (1179, 2556),
    "car-browse": (1920, 720), "car-list": (1920, 720), "car-preview": (1920, 720), "car-nav": (1920, 720),
}

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT))
handler.log_message = lambda *a: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_address[1]}"


def shoot(browser, url, w, h, selector, path):
    page = browser.new_page(viewport={"width": w, "height": h})
    page.on("console", lambda m: print("console:", m.text) if m.type == "error" else None)
    page.goto(url)
    page.wait_for_function("document.title === 'ready' || document.title.startsWith('error')", timeout=120000)
    page.wait_for_load_state("networkidle")
    if page.title() != "ready":
        print(path.name, page.title())
    page.locator(selector).screenshot(path=str(path))
    page.close()


with sync_playwright() as p:
    browser = p.chromium.launch()
    for name, q in BACKGROUNDS.items():
        w = int(q.split("w=")[1].split("&")[0]) if "w=" in q else (1179 if "iphone" in q else 1920)
        shoot(browser, f"{base}/render.html?{q}", w, 2556, "#view", OUT / f"bg-{name}.png")
        print("bg", name)
    for name, (w, h) in SCREENS.items():
        shoot(browser, f"{base}/ui.html?screen={name}", w, h, ".screen", OUT / f"ui-{name}.png")
        print("ui", name)
    browser.close()
server.shutdown()
