#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
OUTPUT_DIR=${1:-${PROJECT_DIR}/dist}
APP_DIR=${OUTPUT_DIR}/TopNest.app

cd "$PROJECT_DIR"
mkdir -p .cache/clang .cache/swiftpm
CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.cache/clang" SWIFTPM_CACHE_PATH="$PROJECT_DIR/.cache/swiftpm" swift build -c release --disable-sandbox --scratch-path "$PROJECT_DIR/.build" -debug-info-format none
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/TopNest" "$APP_DIR/Contents/MacOS/TopNest"
cp "Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/TopNest.icns" "$APP_DIR/Contents/Resources/TopNest.icns"
codesign --force --sign - "$APP_DIR"
echo "$APP_DIR"
