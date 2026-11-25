#!/bin/bash
# Build Remove-quarantine.app (universal: Apple Silicon + Intel) in ./build
set -euo pipefail
cd "$(dirname "$0")"

NAME="Remove-quarantine"
APP="build/$NAME.app"

rm -rf build
mkdir -p "$APP/Contents/MacOS" build/obj

for ARCH in arm64 x86_64; do
    xcrun swiftc -O -target "$ARCH-apple-macos13.0" \
        -o "build/obj/$NAME-$ARCH" Sources/main.swift
done
lipo -create -output "$APP/Contents/MacOS/$NAME" build/obj/$NAME-arm64 build/obj/$NAME-x86_64
rm -rf build/obj

cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Localizations (service menu title): en.lproj, es.lproj...
mkdir -p "$APP/Contents/Resources"
for LPROJ in Resources/*.lproj; do
    if [ -d "$LPROJ" ]; then cp -R "$LPROJ" "$APP/Contents/Resources/"; fi
done

# Icon: generate AppIcon.icns from AppIcon.png (1024x1024)
if [ -f AppIcon.png ]; then
    mkdir -p "$APP/Contents/Resources"
    ICONSET="build/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for SIZE in 16 32 128 256 512; do
        sips -z $SIZE $SIZE AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
        D2=$((SIZE * 2))
        sips -z $D2 $D2 AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
fi

# Signing
# SIGN_IDENTITY: if not set, use the first "Developer ID Application" identity
# found in the keychain; if there is none (or SIGN_IDENTITY="-"), sign ad hoc.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')
fi
if [ -n "${SIGN_IDENTITY:-}" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    # Hardened runtime + secure timestamp: required for notarization
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
    echo "Signed with: $SIGN_IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "Ad-hoc signed (local use only)"
fi
codesign --verify --strict --verbose=2 "$APP"

echo "$APP has been built"
lipo -archs "$APP/Contents/MacOS/$NAME"
