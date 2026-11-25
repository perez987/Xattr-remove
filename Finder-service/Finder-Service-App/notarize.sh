#!/bin/bash
# Notarize and staple build/Remove-quarantine.app, then create a zip to distribute.
# One-time setup (stores the credentials in the keychain):
#   xcrun notarytool store-credentials "notary-profile" --apple-id "you@example.com" --team-id "TEAMID"
# Use another profile name with: NOTARY_PROFILE=name ./notarize.sh
set -euo pipefail
cd "$(dirname "$0")"

NAME="Remove-quarantine"
APP="build/$NAME.app"
PROFILE="${NOTARY_PROFILE:-notary-profile}"

[ -d "$APP" ] || { echo "Run ./build.sh first"; exit 1; }

SIGNINFO=$(codesign -dv --verbose=2 "$APP" 2>&1 || true)
if [[ "$SIGNINFO" != *"Authority=Developer ID Application"* ]]; then
    echo "The app is not signed with a Developer ID Application certificate."
    echo "Run ./build.sh (or SIGN_IDENTITY=\"Developer ID Application: ...\" ./build.sh)"
    exit 1
fi

ZIP="build/$NAME-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Sending to Apple's notary service (may take a few minutes)..."
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
rm -f "$ZIP"

# Attach the notarization ticket to the app (works offline for the user)
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

DIST="build/$NAME.zip"
rm -f "$DIST"
ditto -c -k --keepParent "$APP" "$DIST"
echo "Ready to distribute: $DIST"
