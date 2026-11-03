#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f Resources/MiddleFlow.icns ]]; then
  python3 scripts/generate_icon.py
  iconutil -c icns Resources/MiddleFlow.iconset -o Resources/MiddleFlow.icns
fi

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec project.yml
  xcodebuild \
    -project MiddleFlow.xcodeproj \
    -scheme MiddleFlow \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build
  SOURCE_APP="build/DerivedData/Build/Products/Release/MiddleFlow.app"
else
  swift build -c release --arch arm64 --arch x86_64 --product MiddleFlow
  BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
  SOURCE_APP="build/MiddleFlow.app"
  rm -rf "$SOURCE_APP"
  mkdir -p "$SOURCE_APP/Contents/MacOS" "$SOURCE_APP/Contents/Resources"
  cp "$BIN_PATH/MiddleFlow" "$SOURCE_APP/Contents/MacOS/MiddleFlow"
  cp Resources/Info.plist "$SOURCE_APP/Contents/Info.plist"
  cp Resources/MiddleFlow.icns "$SOURCE_APP/Contents/Resources/MiddleFlow.icns"
fi

APP="build/MiddleFlow.app"
rm -rf "$APP"
mkdir -p build
cp -R "$SOURCE_APP" "$APP"

IDENTITY="${MIDDLEFLOW_SIGN_IDENTITY:-}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built: $APP"
