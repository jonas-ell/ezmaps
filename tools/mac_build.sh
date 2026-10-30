#!/bin/bash
# Build auf dem Mac (wird vom Gate mit „build“ aufgerufen, siehe App/MAC_ZUGANG_NEUE_APP.md).
# Unsigniert für den Simulator + swift test für EzMapsCore.
set -u
cd "$(dirname "$0")/.."
if [ -f tools/.do_scene_assets ]; then
  rm -f tools/.do_scene_assets
  swift tools/export_villager_scn.swift Assets/Generated/PixelQuest/3d || exit 1
  for asset in Assets/Generated/PixelQuest/3d/villager-house*.scn; do
    echo "SCN_ASSET_BEGIN $(basename "$asset")"
    base64 -i "$asset"
    echo "SCN_ASSET_END"
  done
  exit 0
fi
echo "=== EzMaps Build $(date '+%Y-%m-%d %H:%M:%S') ==="
command -v xcodegen >/dev/null || { echo "xcodegen fehlt (brew install xcodegen)"; exit 1; }

# GM-043: Pricedown (Name „Neon City“) nur lokal – Desktop-Lizenz, nie im Repo (GM-035). Ohne Datei nimmt die App Anton.
if [ -f "$HOME/EzMapsPrivate/Fonts/pricedown.otf" ]; then cp "$HOME/EzMapsPrivate/Fonts/pricedown.otf" App/Fonts/Pricedown.otf && echo "Pricedown aus ~/EzMapsPrivate übernommen"; fi

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

# GM-045: App auf das iPhone „Jonas“ laden (Marker tools/.do_device, geschickt von tools/mac_device.sh).
# iPhone muss mit dem Mac gekoppelt sein (einmal per Kabel, „Vertrauen“) und den Entwicklermodus an haben.
# CarPlay-Berechtigung ist im Geräte-Build nicht drin (project.yml) – CarPlay im Auto erst nach Apples Freigabe.
if [ -f tools/.do_device ]; then
  rm -f tools/.do_device
  KC="$HOME/Library/Keychains/mimic-build.keychain-db"
  security unlock-keychain -p "$(cat "$HOME/.mimic-build-kc")" "$KC" || { echo "Schlüsselbund gesperrt"; exit 1; }
  security set-keychain-settings -t 3600 "$KC"
  P8=$(ls "$HOME/.appstoreconnect/private_keys/"AuthKey_*.p8 | head -1)
  KEYID=$(basename "$P8" .p8); KEYID=${KEYID#AuthKey_}
  AUTH=(-authenticationKeyPath "$P8" -authenticationKeyID "$KEYID" -authenticationKeyIssuerID "$(cat "$HOME/.appstoreconnect/issuer_id")")
  xcodegen generate >/dev/null || exit 1
  xcrun devicectl list devices --json-output /tmp/ezmaps_devices.json >/dev/null 2>&1
  xcrun devicectl list devices 2>/dev/null | sed 's/^/  /'
  DEV=$(/usr/bin/python3 - <<'PY2'
import json
d = json.load(open("/tmp/ezmaps_devices.json"))["result"]["devices"]
ios = [x for x in d if x.get("hardwareProperties", {}).get("platform") == "iOS"]
pick = [x for x in ios if "jonas" in x.get("deviceProperties", {}).get("name", "").lower()] or ios
print(pick[0]["hardwareProperties"]["udid"] if pick else "")
PY2
)
  [ -n "$DEV" ] || { echo "KEIN IPHONE GEFUNDEN (gekoppelt? entsperrt? im selben WLAN oder per Kabel?)"; exit 1; }
  echo "Gerät: $DEV"
  rm -rf build/device
  xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination "id=$DEV" -configuration Release SWIFT_ACTIVE_COMPILATION_CONDITIONS=EZTEST \
    -derivedDataPath build/device -allowProvisioningUpdates -allowProvisioningDeviceRegistration "${AUTH[@]}" build > /tmp/ezmaps_device.log 2>&1 \
    || { grep -E "error:" /tmp/ezmaps_device.log | head -30; tail -n 20 /tmp/ezmaps_device.log; echo "GERÄTE-BUILD FEHLGESCHLAGEN"; exit 1; }
  echo "GERÄTE-BUILD OK"
  APP=$(ls -d build/device/Build/Products/Release-iphoneos/EzMaps.app)
  xcrun devicectl device install app --device "$DEV" "$APP" 2>&1 | tail -5 || { echo "INSTALLATION FEHLGESCHLAGEN"; exit 1; }
  BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
  xcrun devicectl device process launch --device "$DEV" "$BID" 2>&1 | tail -3
  echo "AUF DEM IPHONE INSTALLIERT ($BID)"
  exit 0
fi

# GM-024: Freigabe „Bedienungshilfen“ vorbereiten (Marker tools/.do_open_privacy): öffnet auf dem Mac-Bildschirm
# die Einstellungsseite und zeigt sshd-keygen-wrapper im Finder. Das Häkchen setzt der Nutzer selbst (macOS-Regel).
if [ -f tools/.do_open_privacy ]; then
  rm -f tools/.do_open_privacy
  open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"     || open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  open -R /usr/libexec/sshd-keygen-wrapper
  echo "Einstellungen und Finder auf dem Mac geöffnet"
  exit 0
fi

# GM-030: Simulationsfahrt ohne Navigation (Marker tools/.do_freedrive, Wegpunkte in tools/drive.txt):
# App starten, CarPlay an, Standort fährt die Wegpunkte ab, alle 4 s ein CarPlay- und ein iPhone-Bild (JPEG).
if [ -f tools/.do_freedrive ]; then
  rm -f tools/.do_freedrive
  xcodegen generate >/dev/null || exit 1
  LINE=$(xcrun simctl list devices available | grep -E "^ +iPhone 1[6-9] Pro Max" | head -1)
  SID=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
  xcrun simctl boot "$SID" 2>/dev/null; xcrun simctl bootstatus "$SID" -b >/dev/null
  xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination "id=$SID" -configuration Debug \
    -derivedDataPath build/dd build > /tmp/ezmaps_drive_build.log 2>&1 || { grep -E "error:" /tmp/ezmaps_drive_build.log | head -20; echo "BUILD FAILED"; exit 1; }
  APPDIR=build/dd/Build/Products/Debug-iphonesimulator/EzMaps.app
  BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APPDIR/Info.plist")
  xcrun simctl install "$SID" "$APPDIR" || exit 1
  xcrun simctl privacy "$SID" grant location "$BID"
  WP=$(cat tools/drive.txt); FIRST=${WP%% *}
  xcrun simctl location "$SID" set "$FIRST"
  caffeinate -u -t 3; open -a Simulator --args -CurrentDeviceUDID "$SID"; sleep 5
  osascript <<'OSA' 2>&1 | sed 's/^/CarPlay: /'
tell application "Simulator" to activate
tell application "System Events" to tell process "Simulator"
  repeat 30 times
    if exists menu bar 1 then exit repeat
    delay 1
  end repeat
  if exists (first window whose name contains "CarPlay") then return "war offen"
  set m to menu "I/O" of menu bar 1
  click menu item "External Displays" of m
  delay 0.5
  click menu item "CarPlay" of menu 1 of menu item "External Displays" of m
end tell
return "an"
OSA
  sleep 4
  xcrun simctl terminate "$SID" "$BID" 2>/dev/null
  xcrun simctl launch "$SID" "$BID" -EZStyle "${DRIVE_STYLE:-neon-city}" -AppleLanguages "(de)" -AppleLocale de_DE >/dev/null  # GM-061: Stil wählbar
  sleep 8
  osascript <<'OSA' 2>&1 | sed 's/^/Antippen: /'
tell application "System Events" to tell process "Simulator"
  set w to first window whose name contains "CarPlay"
  set {px, py} to position of w
  set {ww, wh} to size of w
  set k to ww / 800
  set top to wh - 480 * k
  repeat 3 times
    click at {px + 52 * k, py + top + 200 * k}
    delay 3
  end repeat
end tell
return "ok"
OSA
  sleep 4
  SPEED=${DRIVE_SPEED:-14}   # m/s (14 = 50 km/h, realistisch – die Kamerahöhe hängt vom Tempo ab)
  xcrun simctl location "$SID" start --speed="$SPEED" $WP || { echo "Fahrt konnte nicht starten"; exit 1; }
  OUT=/tmp/ezdrive; rm -rf "$OUT"; mkdir -p "$OUT"
  N=0; END=$(( $(date +%s) + ${DRIVE_SECONDS:-360} ))
  while [ "$(date +%s)" -lt "$END" ]; do
    F=$(printf "%03d" $N)
    xcrun simctl io "$SID" screenshot --display=external --type=jpeg "$OUT/car-$F.jpg" >/dev/null 2>&1
    [ "${DRIVE_PHONE:-1}" = 1 ] && xcrun simctl io "$SID" screenshot --type=jpeg "$OUT/phone-$F.jpg" >/dev/null 2>&1
    N=$((N+1)); sleep "${DRIVE_EVERY:-4}"  # GM-061: Takt und iPhone-Bilder einstellbar (Clip)
  done
  xcrun simctl location "$SID" clear
  echo "Bilder: $N"
  for F in "$OUT"/*.jpg; do [ -s "$F" ] || continue; echo "===SHOT $(basename "$F" .jpg)==="; base64 -i "$F"; echo "===END==="; done
  echo "FAHRT FERTIG"
  exit 0
fi

# GM-029: Test-Screenshots (Marker tools/.do_testshots): kleines iPhone (wie die iPad-Prüfung von Apple, 375 × 667),
# Englisch, Standort verweigert. Ergebnis landet in docs/store/tests/ (nicht für den Store).
if [ -f tools/.do_testshots ]; then
  rm -f tools/.do_testshots
  xcodegen generate >/dev/null || exit 1
  OUT=/tmp/eztests; rm -rf "$OUT"; mkdir -p "$OUT"
  shoot() { # Gerät-ID, Name, Zustand, Sprache, Wartezeit
    xcrun simctl terminate "$1" "$BID" 2>/dev/null
    xcrun simctl launch "$1" "$BID" -EZShot "$3" ${6:+-EZStyle $6} -AppleLanguages "($4)" -AppleLocale "$4" >/dev/null
    sleep "$5"
    xcrun simctl io "$1" screenshot --type=png "$OUT/$2.png" >/dev/null 2>&1 && echo "Bild: $2"
    # GM-030: läuft die App noch? Sonst Absturz melden
    xcrun simctl spawn "$1" launchctl list 2>/dev/null | grep -q "$BID" || echo "ACHTUNG: App läuft nach $2 nicht (Absturz?)"
  }
  prep() { # Gerät-ID → bauen, installieren, Standort
    xcrun simctl boot "$1" 2>/dev/null; xcrun simctl bootstatus "$1" -b >/dev/null
    xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination "id=$1" -configuration Debug \
      -derivedDataPath build/dd build > /tmp/ezmaps_tests_build.log 2>&1 || { grep -E "error:" /tmp/ezmaps_tests_build.log | head -20; return 1; }
    APPDIR=build/dd/Build/Products/Debug-iphonesimulator/EzMaps.app
    BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APPDIR/Info.plist")
    xcrun simctl uninstall "$1" "$BID" 2>/dev/null; xcrun simctl install "$1" "$APPDIR"
    xcrun simctl privacy "$1" grant location "$BID"
    xcrun simctl location "$1" set 50.21712,8.25734
    xcrun simctl status_bar "$1" override --time 9:41 2>/dev/null
    # GM-030: Aufwärmen – erster Start auf frischem Gerät lädt Kacheln und Schrift, danach sind die Bilder vergleichbar
    xcrun simctl launch "$1" "$BID" >/dev/null 2>&1; sleep 20; xcrun simctl terminate "$1" "$BID" 2>/dev/null
  }
  idof() { xcrun simctl list devices available | grep -E "$1" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'; }
  SMALL=$(idof "^ +iPhone SE"); [ -n "$SMALL" ] || SMALL=$(idof "^ +iPhone 1[6-9]e")
  BIG=$(idof "^ +iPhone 1[6-9] Pro Max")
  if [ -n "$SMALL" ]; then
    echo "Kleines Gerät: $(xcrun simctl list devices available | grep "$SMALL" | sed 's/^ *//')"
    prep "$SMALL" && for E in karte:12 suche:10 vorschau:16 navigation:28 einstellungen:8; do shoot "$SMALL" "klein-${E%%:*}" "${E%%:*}" de "${E##*:}"; done
  else echo "Kein kleines iPhone im Simulator"; fi
  if [ -n "$BIG" ]; then
    prep "$BIG" && for E in karte:12 vorschau:16 navigation:28 einstellungen:8; do shoot "$BIG" "en-${E%%:*}" "${E%%:*}" en "${E##*:}"; done
    xcrun simctl privacy "$BIG" revoke location "$BID"
    shoot "$BIG" "verweigert-karte" karte de 8
    xcrun simctl privacy "$BIG" grant location "$BID"
    # GM-051: jeder Stil auf dem großen iPhone (gegen die Referenzen des Nutzers prüfen – Stile nie gleich)
    for ST in classic neon-city wild-west pixel-quest toy-town frontier; do shoot "$BIG" "stil-$ST-karte" karte de 12 "$ST"; shoot "$BIG" "stil-$ST-navigation" navigation de 28 "$ST"; done
  fi
  # GM-030: Absturzberichte der letzten Stunde
  find "$HOME/Library/Logs/DiagnosticReports" -name "EzMaps*" -mmin -60 2>/dev/null | while read -r R; do
    echo "ABSTURZ: $(basename "$R")"; grep -m5 -E '"exception"|Termination|crashed|EXC_' "$R" | head -5
  done
  for F in "$OUT"/*.png; do [ -s "$F" ] || continue; echo "===SHOT $(basename "$F" .png)==="; base64 -i "$F"; echo "===END==="; done
  echo "TESTBILDER FERTIG"
  exit 0
fi

# GM-023: CarPlay-Screenshots (Marker tools/.do_carscreens). Simulator-App öffnen, per AppleScript
# I/O → External Displays → CarPlay einschalten, dann das externe Display fotografieren.
# Braucht einmalig: Systemeinstellungen → Datenschutz → Bedienungshilfen → „sshd-keygen-wrapper“/Terminal erlauben.
if [ -f tools/.do_carscreens ]; then
  rm -f tools/.do_carscreens
  xcodegen generate >/dev/null || exit 1
  LINE=$(xcrun simctl list devices available | grep -E "^ +iPhone 1[6-9] Pro Max" | head -1)
  SID=$(echo "$LINE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
  echo "Simulator: $LINE"
  xcrun simctl boot "$SID" 2>/dev/null; xcrun simctl bootstatus "$SID" -b >/dev/null
  xcodebuild -project EzMaps.xcodeproj -scheme EzMaps -destination "id=$SID" -configuration Debug \
    -derivedDataPath build/dd build > /tmp/ezmaps_shots_build.log 2>&1 || { grep -E "error:" /tmp/ezmaps_shots_build.log | head -20; echo "BUILD FAILED"; exit 1; }
  APPDIR=build/dd/Build/Products/Debug-iphonesimulator/EzMaps.app
  BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APPDIR/Info.plist")
  xcrun simctl install "$SID" "$APPDIR" || exit 1
  xcrun simctl privacy "$SID" grant location "$BID"
  xcrun simctl location "$SID" set 50.21712,8.25734
  caffeinate -u -t 3   # GM-026: Bildschirm wecken (gesperrter Mac: AppleScript kommt nicht an die Fenster)
  # GM-051: gesperrter Bildschirm → AppleScript kann nicht klicken, alle Bilder zeigen den CarPlay-Startbildschirm
  if ioreg -n Root -d1 -a 2>/dev/null | grep -A1 CGSSessionScreenIsLocked | grep -q true; then
    echo "MAC GESPERRT: CarPlay-Bilder brauchen einen entsperrten Mac-Bildschirm (Klicks im CarPlay-Fenster). Übersprungen."
    echo "CARPLAY FERTIG"
    exit 0
  fi
  open -a Simulator --args -CurrentDeviceUDID "$SID"; sleep 6
  osascript <<'OSA' 2>&1 | sed 's/^/AppleScript: /'
tell application "Simulator" to activate
tell application "System Events" to tell process "Simulator"
  -- GM-026: warten, bis der Simulator bereit ist; nur einschalten, wenn das CarPlay-Fenster fehlt (Menüpunkt schaltet um)
  repeat 30 times
    if exists menu bar 1 then exit repeat
    delay 1
  end repeat
  if exists (first window whose name contains "CarPlay") then return "CarPlay-Fenster war schon offen"
  set m to menu "I/O" of menu bar 1
  click menu item "External Displays" of m
  delay 0.5
  click menu item "CarPlay" of menu 1 of menu item "External Displays" of m
end tell
return "CarPlay-Fenster an"
OSA
  sleep 6
  xcrun simctl io "$SID" enumerate 2>&1 | grep -iE "display|carplay|external" | head -8 | sed 's/^/Displays: /'
  OUT=/tmp/ezcar; rm -rf "$OUT"; mkdir -p "$OUT"
  # GM-025: „frei“ = Fahren ohne Route (Hauptzweck im Auto): simulierte Fahrt durch Idstein, ~45 km/h
  xcrun simctl location "$SID" start --speed=12.5 50.21712,8.25734 50.21780,8.25900 50.21930,8.26250 50.22010,8.26520 50.22130,8.26690 50.22230,8.26900 50.22420,8.27100 || echo "Standort-Fahrt nicht möglich"
  # GM-030: mehr CarPlay-Fälle – Ziele-Liste (Knopf „Ziele“ antippen), Ankunft, Fahrt ohne Route nachts nicht nötig
  # GM-061: freie Fahrt in jedem Stil (frei-<stil>), Rest in Neon City
  for ENTRY in frei:14 frei-classic:14 frei-wild-west:14 frei-pixel-quest:14 frei-toy-town:14 frei-frontier:14 vorschau:16 navigation:28 ankunft:30 ziele:8; do
    NAME=${ENTRY%%:*}; WAIT=${ENTRY##*:}
    CSTYLE=neon-city; case "$NAME" in frei-*) CSTYLE=${NAME#frei-};; esac
    xcrun simctl terminate "$SID" "$BID" 2>/dev/null
    [ "$NAME" = "vorschau" ] && { xcrun simctl location "$SID" clear; xcrun simctl location "$SID" set 50.21712,8.25734; }
    STATE=$NAME; [ "$NAME" = "ziele" ] && STATE=karte; case "$NAME" in frei*) STATE=frei;; esac
    xcrun simctl launch "$SID" "$BID" -EZShot "$STATE" -EZStyle "$CSTYLE" -AppleLanguages "(de)" -AppleLocale de_DE >/dev/null
    sleep 6   # GM-026: CarPlay braucht nach dem Neustart der App etwas, sonst geht der Klick ins Leere
    # GM-024: EzMaps im CarPlay-Fenster antippen (Startbildschirm: Icon unter „Nachrichten“, bei 25 % / 58 % des Bildes)
    osascript <<'OSA' 2>&1 | sed 's/^/Antippen: /'
tell application "Simulator" to activate
delay 0.5
tell application "System Events" to tell process "Simulator"
  set w to first window whose name contains "CarPlay"
  set {px, py} to position of w
  set {ww, wh} to size of w
  -- Bildinhalt 800 × 480, unten im Fenster (oben Titelleiste); EzMaps-Symbol in der linken Leiste bei (52, 200)
  set k to ww / 800
  set top to wh - 480 * k
  -- GM-031: dreimal mit Pause (nach dem App-Neustart kommt der erste Tipp oft zu früh); Tipp im Dock stört eine offene App nicht
  repeat 3 times
    click at {px + 52 * k, py + top + 200 * k}
    delay 3
  end repeat
end tell
return "Fenster " & px & "," & py & " " & ww & "x" & wh
OSA
    if [ "$NAME" = "ziele" ]; then
      osascript <<'OSA' 2>&1 | sed 's/^/Ziele: /'
tell application "System Events" to tell process "Simulator"
  set w to first window whose name contains "CarPlay"
  set {px, py} to position of w
  set {ww, wh} to size of w
  set k to ww / 800
  set top to wh - 480 * k
  click at {px + 165 * k, py + top + 44 * k}
end tell
return "ok"
OSA
    fi
    sleep "$WAIT"
    xcrun simctl io "$SID" screenshot --display=external --type=png "$OUT/carplay-$NAME.png" >/dev/null 2>&1 \
      && echo "Bild: carplay-$NAME" || echo "kein externes Display für $NAME"
  done
  for F in "$OUT"/*.png; do [ -s "$F" ] || continue; echo "===SHOT $(basename "$F" .png)==="; base64 -i "$F"; echo "===END==="; done
  echo "CARPLAY FERTIG"
  exit 0
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
  # GM-021: Befehl heißt in Xcode 26 „status_bar … override“
  xcrun simctl status_bar "$SID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || echo "Statusleiste: Überschreiben nicht möglich"
  # iOS-Einführung zum Wischen auf der Tastatur („Speed up your typing …“) nicht zeigen
  xcrun simctl spawn "$SID" defaults write com.apple.Preferences DidShowContinuousPathIntroduction -bool true
  xcrun simctl spawn "$SID" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true
  OUT=/tmp/ezshots; rm -rf "$OUT"; mkdir -p "$OUT"
  # Zustand:Wartezeit in Sekunden (Kacheln und Routen kommen aus dem Netz)
  for ENTRY in karte:10 suche:9 vorschau:14 navigation:26 einstellungen:6 stil:10; do  # GM-050: stil = Stil-Seite (Prüf-Screenshot Käufe)
    NAME=${ENTRY%%:*}; WAIT=${ENTRY##*:}
    xcrun simctl terminate "$SID" "$BID" 2>/dev/null
    xcrun simctl launch "$SID" "$BID" -EZShot "$NAME" -EZStyle neon-city -AppleLanguages "(de)" -AppleLocale de_DE >/dev/null || { echo "Start fehlgeschlagen: $NAME"; continue; }
    sleep "$WAIT"
    xcrun simctl io "$SID" screenshot --type=png "$OUT/$NAME.png" >/dev/null 2>&1 && echo "Bild: $NAME ($(stat -f%z "$OUT/$NAME.png") Bytes)"
  done
  xcrun simctl status_bar "$SID" clear
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
