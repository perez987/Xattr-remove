#!/bin/bash
# Uninstall Remove-quarantine.app and its service
NAME="Remove-quarantine"
APP="$HOME/Applications/$NAME.app"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

"$LSREG" -u "$APP" 2>/dev/null || true
rm -rf "$APP"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true
killall Finder 2>/dev/null || true
echo "Removed: $APP"
