#!/bin/bash
# Builds Knobs.app: the menu bar app plus its privileged fan helper.
#   ./build.sh                     ad-hoc signed (UI works; the fan helper needs a Developer ID)
#   SIGN_IDENTITY="Developer ID Application: ..." ./build.sh    signed for the helper + notarization
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-2.0.0}"
BUILD="${BUILD:-3}"
# SwiftUI's macros ship with Xcode, not the Command Line Tools.
if [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi

swift build -c release --product Knobs
swift build -c release --product knobs-helper
BIN="$(swift build -c release --show-bin-path)"

APP="build/Knobs.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchDaemons"
cp "$BIN/Knobs" "$APP/Contents/MacOS/Knobs"
cp "$BIN/knobs-helper" "$APP/Contents/MacOS/knobs-helper"

swift Tools/make_icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Library/LaunchDaemons/com.sherlabs.knobs.helper.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.sherlabs.knobs.helper</string>
  <key>BundleProgram</key><string>Contents/MacOS/knobs-helper</string>
  <key>MachServices</key><dict><key>com.sherlabs.knobs.helper</key><true/></dict>
  <key>AssociatedBundleIdentifiers</key><array><string>com.sherlabs.knobs</string></array>
</dict></plist>
PLIST

cat > "$APP/Contents/Info.plist" <<EOF2
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Knobs</string>
  <key>CFBundleDisplayName</key><string>Knobs</string>
  <key>CFBundleIdentifier</key><string>com.sherlabs.knobs</string>
  <key>CFBundleExecutable</key><string>Knobs</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF2

# Sign inside-out: helper first, then the app. (No --deep.)
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --identifier com.sherlabs.knobs.helper --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/knobs-helper"
  codesign --force --options runtime --timestamp --identifier com.sherlabs.knobs --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --identifier com.sherlabs.knobs.helper --sign - "$APP/Contents/MacOS/knobs-helper" >/dev/null 2>&1 || true
  codesign --force --identifier com.sherlabs.knobs --sign - "$APP" >/dev/null 2>&1 || true
  echo "Note: ad-hoc signed. Fan control (the helper) needs SIGN_IDENTITY set to a Developer ID."
fi
echo "Built $APP ($VERSION) — run: open $APP"
