#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="光标回航"
SOURCE_APP="$ROOT_DIR/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"

if [[ ! -d "$SOURCE_APP" ]]; then
    "$ROOT_DIR/scripts/build_app.sh"
fi

if [[ -d "$TARGET_APP" ]]; then
    echo "$TARGET_APP already exists. Quit it and remove it before installing a rebuilt copy." >&2
    exit 2
fi

ditto "$SOURCE_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
xattr -dr com.apple.provenance "$TARGET_APP" 2>/dev/null || true
codesign --verify --deep --strict "$TARGET_APP"

echo "$TARGET_APP"
