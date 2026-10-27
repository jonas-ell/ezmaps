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
touch "$TMP/src/tools/.do_device"
ssh "$H" clean >/dev/null || exit 1
tar -cf - -C "$TMP/src" . | ssh "$H" extract || exit 1
rm -rf "$TMP"   # keine Marker liegen lassen
ssh "$H" build
