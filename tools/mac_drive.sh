#!/bin/bash
# GM-030: Simulationsfahrt ohne Navigation – vom PC (Git Bash):
#   bash tools/mac_drive.sh tools/drive_wallrabenstein.txt [Sekunden]
# Ergebnis: docs/store/fahrt/<name>/car-*.jpg, phone-*.jpg und car.mp4 / phone.mp4 (ffmpeg)
set -u
H=mac-ezmaps
cd "$(dirname "$0")/.."
WPF=${1:?Wegpunkt-Datei angeben}; SECS=${2:-360}
NAME=$(basename "$WPF" .txt | sed 's/^drive_//'); OUTDIR=docs/store/fahrt/$NAME
P=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$H" ping 2>&1)
[ "$P" = "ok" ] || { echo "Mac nicht erreichbar: $P"; exit 1; }
TMP=$(mktemp -d); mkdir -p "$TMP/src"
git archive --format=tar HEAD App Core Resources project.yml tools/mac_build.sh | tar -x -C "$TMP/src"
# GM-067: Villager-Häuser (Bilder aus dem Spiel, vom Nutzer) nur lokal, nie im öffentlichen Repo – für Test-Builds mitschicken
for d in App/Assets.xcassets/PixelQuest/px-house-*.imageset App/Assets.xcassets/PixelQuest/px-sky.imageset; do [ -d "$d" ] && cp -r "$d" "$TMP/src/App/Assets.xcassets/PixelQuest/"; done
cp "$WPF" "$TMP/src/tools/drive.txt"; touch "$TMP/src/tools/.do_freedrive"
sed -i "s/DRIVE_SECONDS:-360/DRIVE_SECONDS:-$SECS/" "$TMP/src/tools/mac_build.sh"
# GM-061: optional Stil, Takt (Sekunden), Tempo (m/s), iPhone-Bilder 0/1 – z. B. STYLE=pixel-quest EVERY=1 PHONE=0
sed -i "s/DRIVE_STYLE:-neon-city/DRIVE_STYLE:-${STYLE:-neon-city}/; s/DRIVE_EVERY:-4/DRIVE_EVERY:-${EVERY:-4}/; s/DRIVE_PHONE:-1/DRIVE_PHONE:-${PHONE:-1}/; s/DRIVE_SPEED:-14/DRIVE_SPEED:-${SPEED:-14}/" "$TMP/src/tools/mac_build.sh"
ssh "$H" clean >/dev/null && tar -cf - -C "$TMP/src" . | ssh "$H" extract >/dev/null || exit 1
echo "Fahre $NAME ($SECS s) …"
ssh "$H" build > "$TMP/raw.txt"
grep -vE '^[A-Za-z0-9+/=]{60,}$' "$TMP/raw.txt" | grep -v "^===" | tail -8
rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
python - "$TMP/raw.txt" "$OUTDIR" <<'PY'
import base64, sys, pathlib
out = pathlib.Path(sys.argv[2]); name, buf, n = None, [], 0
for line in open(sys.argv[1], encoding="utf-8", errors="ignore"):
    line = line.strip()
    if line.startswith("===SHOT "): name, buf = line[8:].rstrip("="), []
    elif line == "===END===" and name: (out / f"{name}.jpg").write_bytes(base64.b64decode("".join(buf))); n += 1; name = None
    elif name: buf.append(line)
print(n, "Bilder in", out)
PY
for K in car phone; do
  ls "$OUTDIR"/$K-*.jpg >/dev/null 2>&1 && ffmpeg -loglevel error -y -framerate ${FPS:-4} -i "$OUTDIR/$K-%03d.jpg" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -pix_fmt yuv420p "$OUTDIR/$K.mp4" && echo "Video: $OUTDIR/$K.mp4"
done
rm -rf "$TMP"
