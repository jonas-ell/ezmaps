#!/bin/bash
# App-Store-Screenshots aus der echten App (Simulator auf dem Mac) holen – vom Windows-PC (Git Bash):
#   bash tools/mac_screens.sh           → iPhone 6,9″
#   bash tools/mac_screens.sh carplay   → CarPlay-Fenster (braucht Bedienungshilfen-Freigabe, s. mac_build.sh)
# Ergebnis: docs/store/iphone-69/<zustand>.png (1320 × 2868). Ablauf in tools/mac_build.sh (Marker .do_screens).
set -u
H=mac-ezmaps
cd "$(dirname "$0")/.."
OUTDIR=docs/store/iphone-69
MARK=.do_screens
if [ "${1:-}" = "carplay" ]; then OUTDIR=docs/store/carplay; MARK=.do_carscreens; fi  # GM-023
if [ "${1:-}" = "freigabe" ]; then MARK=.do_open_privacy; fi  # GM-024: Einstellungen am Mac öffnen
TMP=$(mktemp -d)
RAW="$TMP/ausgabe.txt"

P=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$H" ping 2>&1)
[ "$P" = "ok" ] || { echo "Mac nicht erreichbar: $P (VPN wie Mullvad aus? Tailscale an?)"; exit 1; }

# letzten Commit + Marker schicken (Marker nie im Repo, nie liegen lassen – MAC_ZUGANG Abschnitt 4)
mkdir -p "$TMP/src"
git archive --format=tar HEAD App Core project.yml tools/mac_build.sh | tar -x -C "$TMP/src"
touch "$TMP/src/tools/$MARK"
ssh "$H" clean >/dev/null || exit 1
tar -cf - -C "$TMP/src" . | ssh "$H" extract || exit 1
rm -rf "$TMP/src"

echo "Baue im Simulator und mache Bilder (dauert ein paar Minuten) …"
ssh "$H" build > "$RAW"
grep -vE '^[A-Za-z0-9+/=]{60,}$' "$RAW" | grep -v "^===" | tail -25

mkdir -p "$OUTDIR"
python - "$RAW" "$OUTDIR" <<'PY'
import base64, sys, pathlib
raw, out = sys.argv[1], pathlib.Path(sys.argv[2])
name, buf, n = None, [], 0
for line in open(raw, encoding="utf-8", errors="ignore"):
    line = line.strip()
    if line.startswith("===SHOT "): name, buf = line[8:].rstrip("="), []
    elif line == "===END===" and name:
        (out / f"{name}.png").write_bytes(base64.b64decode("".join(buf))); n += 1; name = None
    elif name: buf.append(line)
print(f"{n} Bilder gespeichert in {out}")
PY
rm -rf "$TMP"
