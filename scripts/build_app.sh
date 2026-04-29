#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="旋转跳跃我闭着眼"
EXECUTABLE_NAME="CursorScreenSwitcher"
CONFIGURATION="${1:-release}"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION"

"$ROOT_DIR/scripts/make_icon.sh"

BUILD_DIR="$ROOT_DIR/.build/$CONFIGURATION"
APP_DIR="$ROOT_DIR/$APP_NAME.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true
xattr -dr com.apple.provenance "$APP_DIR" 2>/dev/null || true

echo "$APP_DIR"
