#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --show-sdk-path)"
BUILD="$ROOT/build"
APP="$BUILD/Cookie Save.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
ICONSET="$BUILD/AppIcon.iconset"
SRC_ICON="$ROOT/Resources/AppIcon.png"
DEST="/Users/nickolasenglebright/Desktop/Projects/Grok Apps/Cookie Save.app"

echo "SDK: $SDK"
rm -rf "$APP" "$ICONSET"
mkdir -p "$MACOS" "$RES" "$ICONSET"

if [[ -f "$SRC_ICON" ]]; then
  for spec in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    sips -z "$size" "$size" "$SRC_ICON" --out "$ICONSET/$name" >/dev/null
  done
  iconutil --convert icns --output "$RES/AppIcon.icns" "$ICONSET"
fi

cp "$ROOT/Resources/catalog.json" "$RES/catalog.json"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

echo "Compiling Cookie Save…"
swiftc -parse-as-library -O -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -sdk "$SDK" \
  -framework SwiftUI \
  -framework AppKit \
  -o "$MACOS/CookieSave" \
  "$ROOT"/Sources/*.swift

codesign --force --deep --sign - \
  --identifier com.nickolasenglebright.cookiesave \
  "$APP"

rm -rf "$DEST"
cp -R "$APP" "$DEST"
chown -R nickolasenglebright:staff "$ROOT" "$DEST"

echo
echo "Built $DEST"
