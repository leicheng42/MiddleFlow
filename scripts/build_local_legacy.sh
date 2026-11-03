#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IDENTITY="${MIDDLEFLOW_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  echo "Set MIDDLEFLOW_SIGN_IDENTITY to the existing Apple Development identity."
  exit 1
fi

./scripts/build_app.sh

SOURCE="build/MiddleFlow.app"
TARGET="build/MiddleFlow-legacy.app"
if [[ -e "$TARGET" ]]; then
  mv "$TARGET" "$TARGET.previous.$(date +%Y%m%d%H%M%S)"
fi
ditto "$SOURCE" "$TARGET"
mv "$TARGET/Contents/MacOS/MiddleFlow" "$TARGET/Contents/MacOS/MiddleOptionBridge"

/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.leicheng.middle-option-bridge' "$TARGET/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable MiddleOptionBridge' "$TARGET/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName MiddleFlow' "$TARGET/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName MiddleFlow' "$TARGET/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 2.0.0' "$TARGET/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 1' "$TARGET/Contents/Info.plist"

codesign --force --options runtime --timestamp=none \
  --identifier local.leicheng.middle-option-bridge \
  --sign "$IDENTITY" "$TARGET"
codesign --verify --deep --strict --verbose=2 "$TARGET"
codesign -dv --verbose=4 "$TARGET" 2>&1 | rg 'Identifier|Authority|TeamIdentifier|CDHash|flags'
echo "Built legacy-compatible app: $TARGET"
