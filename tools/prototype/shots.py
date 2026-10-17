"""Klickt den Prototyp per Playwright durch und speichert Bildschirmfotos nach docs/previews/.

Aufruf: python tools/prototype/shots.py [nur-test]
"""
import functools
import http.server
import pathlib
import sys
import threading

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).parent
OUT = ROOT.parent.parent / "docs" / "previews"
TEST = len(sys.argv) > 1
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT))
handler.log_message = lambda *a: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
URL = f"http://127.0.0.1:{server.server_address[1]}/index.html"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        page = b.new_page(viewport={"width": 1800, "height": 1000}, device_scale_factor=3 if not TEST else 1)
        errors = []
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.on("pageerror", lambda e: errors.append(str(e) + " @ " + (e.stack or "")[:600]))
        page.goto(URL)
        page.wait_for_function("window.__ready === true", timeout=120000)
        phone, car = page.locator("#phone"), page.locator("#car")

        def shot(name, el=phone, wait=700):
            page.wait_for_timeout(wait)
            el.screenshot(path=str(OUT / f"{name}.png"))
            print("bild", name)

        def tap(sel, scope="#pui"):
            page.locator(f"{scope} [data-act='{sel}']").first.click()

        shot("01-start")
        tap("go:permission"); shot("02-standort")
        tap("go:pickStyle"); shot("03-stilwahl")
        tap("go:main"); shot("04-karte", wait=1200)
        shot("c1-carplay-karte", car)
        tap("open:search"); page.keyboard.type("hexen"); shot("05-suche")
        page.locator("#pui [data-act='pick:0']").click(); shot("06-routen-vorschau", wait=1500)
        tap("start"); page.wait_for_timeout(5000); shot("07-navigation", wait=300)
        shot("c4-carplay-navigation", car, wait=0)
        for st in ["western", "pixel", "toy"]:
            page.evaluate(f"import('./js/app.js').then(m => m.useStyle('{st}'))")
            page.wait_for_function(f"document.getElementById('phone').className.includes('t-{st}')", timeout=120000)
            shot(f"07-navigation-{st}", wait=900); shot(f"c4-carplay-navigation-{st}", car, wait=0)
        page.evaluate("import('./js/app.js').then(m => m.useStyle('neon'))"); page.wait_for_timeout(800)
        page.evaluate("import('./js/app.js').then(m => { m.app.state.simSpeed = 200; })"); page.wait_for_function("document.querySelector('.arrival') !== null", timeout=60000)
        shot("08-ankunft", wait=600); shot("c5-carplay-ankunft", car, wait=0)
        page.locator(".arrival [data-act='end']").click(); tap("tab:explore"); shot("09-entdecken", wait=1200)
        tap("tab:styles"); page.wait_for_timeout(9000); shot("10-stile", wait=500)
        tap("tab:profile"); shot("11-profil")
        tap("tab:map"); page.locator("#cui [data-act='go:dest']").click(); shot("c2-carplay-ziele", car)
        page.locator("#cui [data-act='pick:0']").click(); shot("c3-carplay-routen-vorschau", car, wait=1500)
        print("Fehler:", errors or "keine")
        b.close()


main()
server.shutdown()
