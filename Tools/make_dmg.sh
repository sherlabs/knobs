#!/bin/bash
# Builds a drag-to-Applications disk image from the notarized build/Knobs.app, then signs,
# notarizes and staples it. Run after Tools/notarize.sh. Same env as notarize.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGN_IDENTITY:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_KEY_PATH:?}" "${APPLE_API_ISSUER:?}"
VERSION="${1:?version}"
DMG="build/Knobs-${VERSION}-macOS.dmg"
STAGE="$(mktemp -d)"
cp -R build/Knobs.app "$STAGE/Knobs.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Knobs" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
