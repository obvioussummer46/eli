#!/bin/sh
# App Store screenshots, from the app's own demo mode.
#
#   Tools/screenshots.sh build      build the app and put it on both simulators, in demo mode
#   Tools/screenshots.sh shot NAME  capture the current screen of both simulators as NAME
#   Tools/screenshots.sh frame      turn every raw capture into a captioned App Store image
#
# Sizes: iPhone 17 Pro Max → 1320×2868 (Apple's 6.9" slot, covers every
# iPhone); iPad Pro 13" → 2064×2752 (the 13" slot, covers every iPad).
# The app is launched with `-demo` (see App/DemoMode.swift): invented pupil,
# invented school, no network — nothing from a real account can appear.
#
# Tabs are tapped by hand (or with the Simulator MCP tool) between `shot`
# calls; `xcrun simctl` cannot tap.
set -e
cd "$(dirname "$0")/.."
IPHONE="${IPHONE_UDID:-469844CA-D5CD-4441-9519-546BC542630E}"   # iPhone 17 Pro Max
IPAD="${IPAD_UDID:-987C9899-BA93-4242-832A-42F0A83EE38A}"       # iPad Pro 13-inch (M5)
RAW=Docs/AppStore/raw
OUT=Docs/AppStore/screenshots
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/SchulportalMobile.app
BUNDLE=de.schulportalmobile.app

case "$1" in
  build)
    for UD in "$IPHONE" "$IPAD"; do
      xcrun simctl boot "$UD" 2>/dev/null || true
      # German system UI (status bar date, system buttons).
      xcrun simctl spawn "$UD" defaults write .GlobalPreferences AppleLanguages -array de-DE
      xcrun simctl spawn "$UD" defaults write .GlobalPreferences AppleLocale -string de_DE
    done
    xcodebuild -project SchulportalMobile.xcodeproj -scheme SchulportalMobile \
      -destination "platform=iOS Simulator,id=$IPHONE" -derivedDataPath build/DerivedData build \
      | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
    for UD in "$IPHONE" "$IPAD"; do
      xcrun simctl install "$UD" "$APP"
      xcrun simctl status_bar "$UD" override --time "18:30" --batteryState charged --batteryLevel 100 \
        --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
      xcrun simctl terminate "$UD" "$BUNDLE" 2>/dev/null || true
      xcrun simctl launch "$UD" "$BUNDLE" -demo
    done
    ;;
  shot)
    [ -n "$2" ] || { echo "usage: $0 shot NAME"; exit 1; }
    mkdir -p "$RAW"
    xcrun simctl io "$IPHONE" screenshot "$RAW/iphone-$2.png" >/dev/null 2>&1
    xcrun simctl io "$IPAD" screenshot "$RAW/ipad-$2.png" >/dev/null 2>&1
    ls -la "$RAW"/*-"$2".png
    ;;
  frame)
    mkdir -p "$OUT"
    # name|headline|subline — one line per screenshot, in App Store order.
    while IFS='|' read -r name head sub; do
      for device in iphone ipad; do
        src="$RAW/$device-$name.png"
        [ -f "$src" ] || continue
        swift Tools/frame-screenshots.swift "$src" "$OUT/$device-$name.png" "$head" "$sub"
        echo "framed $OUT/$device-$name.png"
      done
    done <<'CAPTIONS'
01-heute|Alles für morgen auf einen Blick|Vertretungen, nächste Stunde, offene Aufgaben und Termine
02-aufgaben|Hausaufgaben abhaken|Ein Tipp – und der Haken landet auch im Schulportal
03-plan|Der Stundenplan, endlich lesbar|Tag oder Woche – und mit einem Tipp im iOS-Kalender
04-essen|Mensa und Guthaben|Speiseplan, bestellte Gerichte und Kontoauszug
05-mehr|Deine Schule, deine Links|Portal, AGs, Fehlzeiten, Widgets – alles unter „Mehr“
CAPTIONS
    ;;
  *)
    sed -n '2,15p' "$0"
    ;;
esac
