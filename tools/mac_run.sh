#!/bin/bash
# Ein Befehl vom Windows-PC (Git Bash): aktuellen Commit auf den Mac schicken und bauen.
#   bash tools/mac_run.sh          → prüfen, aufräumen, Code schicken, bauen
#   bash tools/mac_run.sh log      → letztes Build-Log holen
# Nutzt den eigenen EzMaps-Zugang (Host mac-ezmaps, Schlüssel ~/.ssh/ezmaps_mac) – NIE den alten Schlüssel
# der anderen App (dessen Gate würde „slop app appstore“ überschreiben). Einrichtung: docs/MAC_EINRICHTEN.md
set -u
H=mac-ezmaps
cd "$(dirname "$0")/.."

if [ "${1:-}" = "log" ]; then ssh "$H" log; exit $?; fi

echo "1/4 Verbindung prüfen …"
P=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$H" ping 2>&1)
if [ "$P" != "ok" ]; then
  echo "Mac nicht erreichbar oder Gate fehlt: $P"
  echo "→ Mac wach? Tailscale an? Einrichtung nach docs/MAC_EINRICHTEN.md erledigt?"
  exit 1
fi
if [ -n "$(git status --porcelain -- App Core project.yml tools/mac_build.sh)" ]; then
  echo "Hinweis: Es gibt nicht committete Änderungen in App/, Core/ oder project.yml – gebaut wird nur der letzte Commit ($(git rev-parse --short HEAD))."
fi
echo "2/4 Projektordner auf dem Mac leeren …"; ssh "$H" clean || exit 1
# git archive: nur Dateien aus dem Repo (keine Schriften, keine Geheimnisse), Zeilenenden LF laut .gitattributes
echo "3/4 Commit $(git rev-parse --short HEAD) schicken …"
git archive --format=tar HEAD App Core Resources project.yml tools/mac_build.sh | ssh "$H" extract || exit 1
echo "4/4 Bauen (xcodegen, xcodebuild, swift test) – das dauert beim ersten Mal wegen MapLibre länger …"
ssh "$H" build
STATUS=$?
echo "Ende, Exit $STATUS. Volles Log: bash tools/mac_run.sh log"
exit $STATUS
