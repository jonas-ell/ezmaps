"""Prüft die Deutschland-Funktionen (GM-015) automatisch in Chromium und WebKit (Safari-Engine).

Ablauf: Rauszoomen bis Deutschland und wieder rein, alle vier Stile außerhalb von Idstein,
„Römerberg Frankfurt“ suchen → Route → Los → Tempolimit → „Falsch abbiegen“ → neue Route, CarPlay dazu.
Bilder nach tools/prototype/out/check/ (nicht im Repo).

Aufruf: python tools/prototype/check_germany.py [chromium|webkit]
"""
import functools
import http.server
import pathlib
import sys
import threading

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "out" / "check"
OUT.mkdir(parents=True, exist_ok=True)
ENGINE = sys.argv[1] if len(sys.argv) > 1 else "chromium"
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT.parent.parent))
handler.log_message = lambda *a: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
URL = f"http://127.0.0.1:{server.server_address[1]}/tools/prototype/index.html"
M = "import('./js/app.js').then(m => {})"


def main():
    with sync_playwright() as p:
        b = getattr(p, ENGINE).launch()
        pg = b.new_page(viewport={"width": 1800, "height": 1000})
        errs = []
        pg.on("pageerror", lambda e: errs.append("pageerror: " + str(e)))
        pg.on("console", lambda m: errs.append("console: " + m.text) if m.type == "error" else None)
        st = lambda expr: pg.evaluate(f"import('./js/app.js').then(m => {expr})")
        shot = lambda name: (pg.wait_for_timeout(200), pg.locator("#phone").screenshot(path=str(OUT / f"{ENGINE}-{name}.png")))
        cshot = lambda name: pg.locator("#car").screenshot(path=str(OUT / f"{ENGINE}-{name}.png"))
        pg.goto(URL)
        pg.wait_for_function("window.__ready === true", timeout=120000)
        for a in ["go:permission", "go:pickStyle", "go:main"]:
            pg.locator(f"#pui [data-act='{a}']").first.click(); pg.wait_for_timeout(200)
        print("Kacheln erreichbar:", st("import('./js/tiles.js').then(t => t.tilesReady())"))

        # 1) bis Deutschland raus und zurück
        for name, scale in [("zoom-deutschland", 0.0006), ("zoom-hessen", 0.004), ("zoom-taunus", 0.03), ("zoom-idstein", 0.3)]:
            st(f"{{ m.app.state.browse.phone.scale = {scale}; m.app.state.browse.phone.center = [0, 0]; }}")
            pg.wait_for_timeout(6000); shot(name)
        # 2) Stile außerhalb von Idstein (Frankfurt, ca. 30 km südöstlich)
        st("import('./js/geo.js').then(g => { m.app.state.browse.phone.center = g.toLocal(50.1106, 8.6821); m.app.state.browse.phone.scale = 0.25; })")
        for s in ["neon", "western", "pixel", "toy"]:
            st(f"m.useStyle('{s}')"); pg.wait_for_timeout(9000); shot(f"frankfurt-{s}")
        st("m.useStyle('neon')"); pg.wait_for_timeout(1500)
        # 3) Suche → Route → Los → Tempolimit → Falsch abbiegen
        pg.locator("#pui [data-act='open:search']").click(); pg.wait_for_timeout(300)
        pg.keyboard.type("Römerberg Frankfurt"); pg.wait_for_timeout(3500); shot("suche")
        items = pg.locator("#pui .item .tl").all_inner_texts()
        print("Treffer:", [i.split("\n")[0] for i in items[:6]])
        idx = next((i for i, t in enumerate(items) if "Römerberg" in t), 0)
        pg.locator(f"#pui [data-act='pick:{idx}']").click()
        pg.wait_for_function("document.querySelector('#pui [data-act=\"start\"]') !== null", timeout=60000)
        pg.wait_for_timeout(2500); shot("vorschau")
        print("Routen:", st("m.app.state.nav.routes.map(r => Math.round(r.route.length / 100) / 10 + ' km / ' + Math.round(r.route.seconds / 60) + ' min')"))
        pg.locator("#pui [data-act='start']").click(); pg.wait_for_timeout(6000)
        print("Tempolimit geladen:", st("!!m.app.state.nav.route.limits"), "| angezeigt:", pg.locator("#pui [data-hud='limit']").inner_text() if pg.locator("#pui [data-hud='limit']").count() else "-")
        shot("navigation"); cshot("carplay-navigation")
        print("CarPlay-Tempolimit:", pg.locator("#cui [data-hud='limit']").inner_text() if pg.locator("#cui [data-hud='limit']").count() else "-", "| CarPlay-Ziel:", st("m.app.state.car.screen"))
        before = st("m.app.state.nav.route.length")
        pg.locator("[data-ctl='reroute']").click(); pg.wait_for_timeout(6000)
        after = st("m.app.state.nav.route.length")
        print("Neuberechnung:", round(before), "->", round(after), "m |", st("m.app.state.nav.routes[0].label"))
        shot("neuberechnet"); cshot("carplay-neuberechnet")
        print("Fehler:", errs or "keine")
        b.close()


main()
server.shutdown()
