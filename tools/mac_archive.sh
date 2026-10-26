#!/bin/bash
# App-Store-Archiv auf dem Mac bauen – vom Windows-PC (Git Bash):
#   bash tools/mac_archive.sh            → archivieren + signiert exportieren (Probe, lädt NICHT hoch)
#   bash tools/mac_archive.sh --upload   → archivieren + zu App Store Connect hochladen (nur auf ausdrückliche Ansage des Nutzers)
# Vorher: Bundle-ID registriert, App in App Store Connect angelegt, CURRENT_PROJECT_VERSION in project.yml erhöht (docs/VEROEFFENTLICHUNG.md).
set -u
H=mac-ezmaps
cd "$(dirname "$0")/.."
P=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$H" ping 2>&1)
[ "$P" = "ok" ] || { echo "Mac nicht erreichbar: $P (VPN wie Mullvad aus? Tailscale an?)"; exit 1; }
TMP=$(mktemp -d); mkdir -p "$TMP/src"
git archive --format=tar HEAD App Core Resources project.yml tools/mac_build.sh | tar -x -C "$TMP/src"
touch "$TMP/src/tools/.do_archive"
[ "${1:-}" = "--upload" ] && touch "$TMP/src/tools/.do_upload" && echo "ACHTUNG: Es wird zu App Store Connect hochgeladen."
ssh "$H" clean >/dev/null || exit 1
tar -cf - -C "$TMP/src" . | ssh "$H" extract || exit 1
rm -rf "$TMP"   # keine Marker liegen lassen (sonst löst der nächste extract denselben Lauf aus)
ssh "$H" build
