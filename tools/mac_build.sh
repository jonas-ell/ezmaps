#!/bin/bash
# Build auf dem Mac (wird vom Gate mit „build“ aufgerufen, siehe App/MAC_ZUGANG_NEUE_APP.md).
# Unsigniert für den Simulator + swift test für EzMapsCore.
set -u
cd "$(dirname "$0")/.."
echo "=== EzMaps Build $(date '+%Y-%m-%d %H:%M:%S') ==="
command -v xcodegen >/dev/null || { echo "xcodegen fehlt (brew install xcodegen)"; exit 1; }

xcodegen generate || { echo "xcodegen ist fehlgeschlagen"; exit 1; }
xcodebuild -project EzMaps.xcodeproj -scheme EzMaps \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build > /tmp/ezmaps_xcb.log 2>&1
APP=$?
grep -E "error:|warning: .*(EzMaps|App/)|BUILD SUCCEEDED|BUILD FAILED" /tmp/ezmaps_xcb.log | head -60
echo "--- xcodebuild Exit: $APP"

# GM-020: wie ▶ in Xcode – signiert für einen echten Simulator (Signieren lokal, kein Schlüsselbund nötig)
SIM=$(xcrun simctl list devices available | grep -E "iPhone 1[5-9]" | head -1 | sed -E 's/^ *([^(]+) \(.*//' | sed 's/ *$//')
echo "--- Simulator: ${SIM:-keiner gefunden}"
if [ -n "$SIM" ]; then
  xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination "platform=iOS Simulator,name=$SIM"     -configuration Debug build > /tmp/ezmaps_xcb_signed.log 2>&1
  SIGNED=$?
  grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" /tmp/ezmaps_xcb_signed.log | head -40
  echo "--- signierter Simulator-Build Exit: $SIGNED"
else SIGNED=1; fi
[ $APP -eq 0 ] && APP=$SIGNED

(cd Core && swift test > /tmp/ezmaps_test.log 2>&1)
TEST=$?
grep -E "error:|failed|passed|Executed|Test Suite 'All tests'" /tmp/ezmaps_test.log | tail -40
echo "--- swift test Exit: $TEST"

[ $APP -eq 0 ] && [ $TEST -eq 0 ] && echo "ALLES OK" || echo "FEHLER (Details: /tmp/ezmaps_xcb.log, /tmp/ezmaps_test.log)"
exit $(( APP != 0 || TEST != 0 ))
