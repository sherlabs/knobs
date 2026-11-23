#!/bin/bash
# Signs (Developer ID + hardened runtime), notarizes and staples build/Knobs.app,
# then writes build/Knobs-<version>-macOS.zip. Run ./build.sh first.
#
# Required env:
#   SIGN_IDENTITY       e.g. "Developer ID Application: Your Name (TEAMID)"
#   APPLE_API_KEY_ID    App Store Connect API key id
#   APPLE_API_KEY_PATH  path to AuthKey_<id>.p8
#   APPLE_API_ISSUER    issuer UUID
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGN_IDENTITY:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_KEY_PATH:?}" "${APPLE_API_ISSUER:?}"
VERSION="${1:-2.0.0}"
APP="build/Knobs.app"
SUBMIT_ZIP="build/Knobs-submit.zip"
FINAL_ZIP="build/Knobs-${VERSION}-macOS.zip"

# build.sh signs the helper and app inside-out when SIGN_IDENTITY is set.
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
