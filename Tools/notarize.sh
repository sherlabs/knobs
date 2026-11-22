#!/bin/bash
# Signs (Developer ID + hardened runtime), notarizes and staples build/GlowBar.app,
# then writes build/GlowBar-<version>-macOS.zip. Run ./build.sh first.
#
# Required env:
#   SIGN_IDENTITY       e.g. "Developer ID Application: Your Name (TEAMID)"
#   APPLE_API_KEY_ID    App Store Connect API key id
#   APPLE_API_KEY_PATH  path to AuthKey_<id>.p8
#   APPLE_API_ISSUER    issuer UUID
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGN_IDENTITY:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_KEY_PATH:?}" "${APPLE_API_ISSUER:?}"
VERSION="${1:-1.0.0}"
APP="build/GlowBar.app"
SUBMIT_ZIP="build/GlowBar-submit.zip"
FINAL_ZIP="build/GlowBar-${VERSION}-macOS.zip"

codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

rm -f "$SUBMIT_ZIP"
ditto -c -k --keepParent "$APP" "$SUBMIT_ZIP"
xcrun notarytool submit "$SUBMIT_ZIP" --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose "$APP"

rm -f "$FINAL_ZIP" "$SUBMIT_ZIP"
ditto -c -k --keepParent "$APP" "$FINAL_ZIP"
shasum -a 256 "$FINAL_ZIP" | tee "$FINAL_ZIP.sha256"
