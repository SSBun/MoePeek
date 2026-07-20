#!/bin/bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.1"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
BUILD_DATE="$(date +%Y-%m-%d)"
APP_NAME="MoePeek"
ARCHIVE_PATH="$PROJECT_ROOT/build/${APP_NAME}.xcarchive"
APP_PATH="$PROJECT_ROOT/build/app"
DISK_DIR="$PROJECT_ROOT/disk"
DMG_NAME="${APP_NAME}-v${VERSION}-${BUILD_DATE}.dmg"
DMG_PATH="$DISK_DIR/$DMG_NAME"

echo "==> Setting version to $VERSION"
sed -i '' "s/\"MARKETING_VERSION\": \".*\"/\"MARKETING_VERSION\": \"$VERSION\"/" "$PROJECT_ROOT/Project.swift"

echo "==> Generating Xcode project"
cd "$PROJECT_ROOT"
tuist generate

echo "==> Building release archive"
xcodebuild archive \
    -workspace "${APP_NAME}.xcworkspace" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    VALIDATE_STRINGS_FILES_WHILE_COPYING=NO

echo "==> Preparing app bundle"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH"
ditto "$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app" "$APP_PATH/${APP_NAME}.app"

echo "==> Creating DMG"
mkdir -p "$DISK_DIR"
rm -f "$DMG_PATH"

if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 160 \
        --icon "${APP_NAME}.app" 180 170 \
        --app-drop-link 480 170 \
        --hide-extension "${APP_NAME}.app" \
        "$DMG_PATH" \
        "$APP_PATH/"
else
    echo "create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

[[ -f "$DMG_PATH" ]] || { echo "DMG was not created: $DMG_PATH"; exit 1; }
hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH"

echo "==> Done: $DMG_PATH"
