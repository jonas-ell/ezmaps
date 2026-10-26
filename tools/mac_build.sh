#!/bin/bash
# Build auf dem Mac (wird vom Gate mit „build“ aufgerufen, siehe App/MAC_ZUGANG_NEUE_APP.md).
# Unsigniert für den Simulator + swift test für EzMapsCore.
set -u
cd "$(dirname "$0")/.."
echo "=== EzMaps Build $(date '+%Y-%m-%d %H:%M:%S') ==="
command -v xcodegen >/dev/null || { echo "xcodegen fehlt (brew install xcodegen)"; exit 1; }

# GM-021: Archiv für den App Store (Marker tools/.do_archive, geschickt von tools/mac_archive.sh).
# Mit zusätzlichem Marker tools/.do_upload wird hochgeladen, sonst nur signiert exportiert (Probe).
# Schlüsselbund und API-Schlüssel wie in App/MAC_ZUGANG_NEUE_APP.md Abschnitt 6 (gilt für alle Apps des Teams).
if [ -f tools/.do_archive ]; then
  rm -f tools/.do_archive
  UPLOAD=0; [ -f tools/.do_upload ] && UPLOAD=1; rm -f tools/.do_upload
  KC="$HOME/Library/Keychains/mimic-build.keychain-db"
  security unlock-keychain -p "$(cat "$HOME/.mimic-build-kc")" "$KC" || { echo "Schlüsselbund gesperrt"; exit 1; }
  security set-keychain-settings -t 3600 "$KC"
  P8=$(ls "$HOME/.appstoreconnect/private_keys/"AuthKey_*.p8 | head -1)
  KEYID=$(basename "$P8" .p8); KEYID=${KEYID#AuthKey_}
  AUTH=(-authenticationKeyPath "$P8" -authenticationKeyID "$KEYID" -authenticationKeyIssuerID "$(cat "$HOME/.appstoreconnect/issuer_id")")
  xcodegen generate >/dev/null || exit 1
  rm -rf build/EzMaps.xcarchive build/export; mkdir -p build
  echo "Archiviere $(grep -m1 MARKETING_VERSION project.yml | sed 's/#.*//') Build $(grep -m1 CURRENT_PROJECT_VERSION project.yml) …"
  xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination 'generic/platform=iOS' -configuration Release \
    -archivePath build/EzMaps.xcarchive -allowProvisioningUpdates "${AUTH[@]}" archive > /tmp/ezmaps_archive.log 2>&1 \
    || { grep -E "error:" /tmp/ezmaps_archive.log | head -30; tail -n 30 /tmp/ezmaps_archive.log; echo "ARCHIV FEHLGESCHLAGEN"; exit 1; }
  echo "ARCHIV OK"
  # Prüfungen aus docs/VEROEFFENTLICHUNG.md: App-Icon und Datenschutz-Manifest im Paket, keine CarPlay-Berechtigung ohne Freigabe
  APP=build/EzMaps.xcarchive/Products/Applications/EzMaps.app
  ls "$APP" | grep -E "AppIcon|PrivacyInfo|Assets.car" | sed 's/^/  im Paket: /'
  codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q carplay && echo "  WARNUNG: CarPlay-Berechtigung im Store-Build" || echo "  CarPlay-Berechtigung: nicht enthalten (richtig, solange Apple sie nicht erteilt hat)"
  DEST=export; [ $UPLOAD -eq 1 ] && DEST=upload
  cat > build/exportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>8L66DP544P</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>$DEST</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath build/EzMaps.xcarchive -exportPath build/export \
    -exportOptionsPlist build/exportOptions.plist -allowProvisioningUpdates "${AUTH[@]}" > /tmp/ezmaps_export.log 2>&1
  STATUS=$?; tail -n 25 /tmp/ezmaps_export.log
  ls -l build/export/*.ipa 2>/dev/null | awk '{print "  IPA: " $5 " Bytes"}'
  if [ $UPLOAD -eq 1 ]; then [ $STATUS -eq 0 ] && echo "UPLOAD OK" || echo "UPLOAD FEHLGESCHLAGEN"
  else [ $STATUS -eq 0 ] && echo "EXPORT OK (nicht hochgeladen)" || echo "EXPORT FEHLGESCHLAGEN"; fi
  exit $STATUS
fi

# GM-021: App-Store-Screenshots (Marker tools/.do_screens, geschickt von tools/mac_screens.sh).
# Simulator „iPhone … Pro Max“ (6,9″ = 1320 × 2868), Standort Idstein, Deutsch, Statusleiste 9:41.
# Die Bilder gehen als base64 zwischen ===SHOT name=== und ===END=== über die Ausgabe zurück (das Gate kann nur Text).
if [ -f tools/.do_screens ]; then
  rm -f tools/.do_screens
  xcodegen generate >/dev/null || { echo "xcodegen ist fehlgeschlagen"; exit 1; }
  LINE=$(xcrun simctl list devices available | grep -E "^ +iPhone 1[6-9] Pro Max" | head -1)
  SID=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
  [ -n "$SID" ] || { echo "Kein Simulator „iPhone … Pro Max“ gefunden"; xcrun simctl list devices available | grep iPhone; exit 1; }
  echo "Simulator: $LINE"
  xcrun simctl boot "$SID" 2>/dev/null; xcrun simctl bootstatus "$SID" -b >/dev/null
  xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination "id=$SID" -configuration Debug \
    -derivedDataPath build/dd build > /tmp/ezmaps_shots_build.log 2>&1 || { grep -E "error:" /tmp/ezmaps_shots_build.log | head -30; echo "BUILD FAILED"; exit 1; }
  APPDIR=build/dd/Build/Products/Debug-iphonesimulator/EzMaps.app
  BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APPDIR/Info.plist")
  xcrun simctl uninstall "$SID" "$BID" 2>/dev/null
  xcrun simctl install "$SID" "$APPDIR" || exit 1
  xcrun simctl privacy "$SID" grant location "$BID"
  xcrun simctl location "$SID" set 50.21712,8.25734   # Bahnhof Idstein
  xcrun simctl status_override "$SID" --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  OUT=/tmp/ezshots; rm -rf "$OUT"; mkdir -p "$OUT"
  # Zustand:Wartezeit in Sekunden (Kacheln und Routen kommen aus dem Netz)
  for ENTRY in karte:10 suche:9 vorschau:14 navigation:26 einstellungen:6; do
    NAME=${ENTRY%%:*}; WAIT=${ENTRY##*:}
    xcrun simctl terminate "$SID" "$BID" 2>/dev/null
    xcrun simctl launch "$SID" "$BID" -EZShot "$NAME" -AppleLanguages "(de)" -AppleLocale de_DE >/dev/null || { echo "Start fehlgeschlagen: $NAME"; continue; }
    sleep "$WAIT"
    xcrun simctl io "$SID" screenshot --type=png "$OUT/$NAME.png" >/dev/null 2>&1 && echo "Bild: $NAME ($(stat -f%z "$OUT/$NAME.png") Bytes)"
  done
  xcrun simctl status_override "$SID" clear
  for F in "$OUT"/*.png; do
    echo "===SHOT $(basename "$F" .png)==="; base64 -i "$F"; echo "===END==="
  done
  echo "SCREENSHOTS FERTIG"
  exit 0
fi

xcodegen generate || { echo "xcodegen ist fehlgeschlagen"; exit 1; }
xcodebuild -project EzMaps.xcodeproj -scheme EzMaps \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build > /tmp/ezmaps_xcb.log 2>&1
APP=$?
grep -E "error:|warning: .*(EzMaps|App/)|BUILD SUCCEEDED|BUILD FAILED" /tmp/ezmaps_xcb.log | head -60
echo "--- xcodebuild Exit: $APP"

# GM-020: wie ▶ in Xcode – signiert für einen echten Simulator (Signieren lokal, kein Schlüsselbund nötig)
SIM=$(xcrun simctl list devices available | grep -E "^ +iPhone" | head -1)
SIMID=$(echo "$SIM" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
echo "--- Simulator: ${SIM:-keiner gefunden}"
if [ -n "$SIMID" ]; then
  xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination "id=$SIMID"     -configuration Debug build > /tmp/ezmaps_xcb_signed.log 2>&1
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
