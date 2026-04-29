#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT_DIR/Resources/AppIcon.iconset"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"
SOURCE_ICON="$ROOT_DIR/Resources/AppIconSource.png"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16 "$SOURCE_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$SOURCE_ICON" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "$ICNS"
