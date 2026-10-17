"""Startet den Prototyp lokal: python tools/prototype/serve.py  →  http://localhost:8765"""
import functools
import http.server
import pathlib
import webbrowser

ROOT = pathlib.Path(__file__).parent
PORT = 8765
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT))
print(f"EzMaps-Prototyp: http://localhost:{PORT}  (Strg+C beendet)")
webbrowser.open(f"http://localhost:{PORT}")
http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler).serve_forever()
