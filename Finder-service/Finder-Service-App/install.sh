#!/bin/bash
# Build (if required), install in ~/Applications and register the service
set -euo pipefail
cd "$(dirname "$0")"

NAME="Remove-quarantine"
DEST="$HOME/Applications"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

[ -d "build/$NAME.app" ] || ./build.sh

mkdir -p "$DEST"
rm -rf "$DEST/$NAME.app"
cp -R "build/$NAME.app" "$DEST/"

"$LSREG" -f "$DEST/$NAME.app"
open "$DEST/$NAME.app"          # opens in the background and quits by itself after 10 s
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "Installed in: $DEST/$NAME.app"
echo "Check that 'Remove quarantine' is enabled in:"
echo "  System Settings > Keyboard > Keyboard Shortcuts > Services > Files and Folders"
