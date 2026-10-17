"""Rendert render.html in allen Ansichten zu PNGs in out/.

Aufruf: python shoot.py [progress_meter]
"""
import functools
import http.server
import pathlib
import sys
import threading

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).parent
PROGRESS = sys.argv[1] if len(sys.argv) > 1 else "520"
SIZES = {"overview": (1600, 1170), "carplay": (1920, 720), "iphone": (1179, 2556), "cluster": (640, 640)}

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT))
handler.log_message = lambda *a: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
port = server.server_address[1]

with sync_playwright() as p:
    browser = p.chromium.launch()
    for mode, (w, h) in SIZES.items():
        page = browser.new_page(viewport={"width": w, "height": h})
        page.on("console", lambda m: print("console:", m.text))
        page.goto(f"http://127.0.0.1:{port}/render.html?mode={mode}&progress={PROGRESS}")
        page.wait_for_function("document.title === 'ready' || document.title.startsWith('error')", timeout=120000)
        if page.title() != "ready":
            print(mode, page.title())
        page.locator("#view").screenshot(path=str(ROOT / "out" / f"neon-{mode}.png"), omit_background=True)
        print("ok", mode)
    browser.close()
server.shutdown()
