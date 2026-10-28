#!/bin/bash
# GM-025: Prüflauf nach jeder Änderung – Build + Tests, dann iPhone- und CarPlay-Screenshots aus der echten App.
# Bilder: docs/store/iphone-69/ und docs/store/carplay/ (werden mit committet, damit man Fehler nachverfolgen kann).
# Übersicht: docs/store/uebersicht.png
set -u
cd "$(dirname "$0")/.."
python tools/maplibre/check_style.py | tail -3 || { echo "Kartenstil fehlerhaft"; exit 1; }   # GM-029
bash tools/mac_run.sh | grep -E "error:|BUILD|Executed [0-9]+ tests, with|ALLES|FEHLER" || true
bash tools/mac_run.sh log | grep -q "ALLES OK" || { echo "Build/Tests nicht grün – keine Screenshots"; exit 1; }
bash tools/mac_screens.sh | grep -E "Bild:|gespeichert"
bash tools/mac_screens.sh carplay | grep -E "Bild:|gespeichert|AppleScript|GESPERRT"
bash tools/mac_screens.sh tests | grep -E "Bild:|gespeichert|Kein kleines|error"   # GM-029
python - <<'PY'
from PIL import Image
import glob, os
ph = [Image.open(f).convert("RGB").resize((330, 717)) for f in sorted(glob.glob("docs/store/iphone-69/*.png"))]
cp = [Image.open(f).convert("RGB") for f in sorted(glob.glob("docs/store/carplay/*.png"))]
W = max(len(ph) * 340, 820 * max(1, len(cp)))
s = Image.new("RGB", (W, 727 + (490 if cp else 0)), (17, 17, 17))
for i, im in enumerate(ph): s.paste(im, (i * 340, 0))
for i, im in enumerate(cp): s.paste(im.resize((800, 480)), (i * 820, 727))
s.save("docs/store/uebersicht.png"); print("Übersicht: docs/store/uebersicht.png")
PY
