"""Gemeinsame Hilfe: lokaler Server + Playwright-Screenshots."""
import functools
import http.server
import pathlib
import threading
from contextlib import contextmanager

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).parent


@contextmanager
def shooter():
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT))
    handler.log_message = lambda *a: None
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_address[1]}"
    with sync_playwright() as p:
        browser = p.chromium.launch()

        def shoot(path_query, w, h, selector, out):
            page = browser.new_page(viewport={"width": w, "height": h})
            page.on("console", lambda m: print("console:", m.text) if m.type == "error" else None)
            page.goto(f"{base}/{path_query}")
            page.wait_for_function("document.title === 'ready' || document.title.startsWith('error')", timeout=180000)
            page.wait_for_load_state("networkidle")
            if page.title() != "ready":
                print(out, page.title())
            page.locator(selector).screenshot(path=str(ROOT / "out" / out), omit_background=True)
            page.close()

        yield shoot
        browser.close()
    server.shutdown()
