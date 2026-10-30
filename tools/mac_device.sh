#!/bin/bash
# App vom Mac auf das iPhone „Jonas“ laden – vom Windows-PC (Git Bash):  bash tools/mac_device.sh
# Ablauf in tools/mac_build.sh (Marker .do_device). iPhone vorher entsperren; einmalig per Kabel koppeln und Entwicklermodus an.
set -u
H=mac-ezmaps
cd "$(dirname "$0")/.."
P=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$H" ping 2>&1)
[ "$P" = "ok" ] || { echo "Mac nicht erreichbar: $P (VPN wie Mullvad aus? Tailscale an?)"; exit 1; }
TMP=$(mktemp -d); mkdir -p "$TMP/src"
git archive --format=tar HEAD App Core Resources project.yml tools/mac_build.sh | tar -x -C "$TMP/src"
# GM-067: Villager-Häuser (Bilder aus dem Spiel, vom Nutzer) nur lokal, nie im öffentlichen Repo – für Test-Builds mitschicken
for d in App/Assets.xcassets/PixelQuest/px-house-*.imageset App/Assets.xcassets/PixelQuest/px-sky.imageset; do [ -d "$d" ] && cp -r "$d" "$TMP/src/App/Assets.xcassets/PixelQuest/"; done
# GM-092: 3D-Villager-Häuser (Codex, nur lokal) ins App-Bundle
mkdir -p "$TMP/src/App/Models"; cp Assets/Generated/PixelQuest/3d/villager-house-*.scn "$TMP/src/App/Models/" 2>/dev/null
# GM-045: Pricedown (Neon-City-Name) nur aus der lokalen Datei mitschicken, nie aus Git. Desktop-Lizenz: Bilder/Videos und eigener Test ok,
# für den Store-Build (mac_archive.sh, nur Git-Dateien) braucht es die App-Lizenz.
[ -f tools/prototype/fonts/pricedown.otf ] && cp tools/prototype/fonts/pricedown.otf "$TMP/src/App/Fonts/Pricedown.otf"
touch "$TMP/src/tools/.do_device"
ssh "$H" clean >/dev/null || exit 1
tar -cf - -C "$TMP/src" . | ssh "$H" extract || exit 1
rm -rf "$TMP"   # keine Marker liegen lassen
ssh "$H" build
