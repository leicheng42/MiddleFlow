#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-2.0.1}"
if [[ "${PACKAGE_SKIP_BUILD:-0}" != "1" ]]; then
  ./scripts/build_app.sh
fi

mkdir -p dist
rm -rf "dist/MiddleFlow-${VERSION}-macOS-universal.zip" "dist/MiddleFlow-${VERSION}-macOS-universal.dmg"
ditto -c -k --keepParent build/MiddleFlow.app "dist/MiddleFlow-${VERSION}-macOS-universal.zip"

DMG_ROOT="build/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R build/MiddleFlow.app "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "MiddleFlow" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "dist/MiddleFlow-${VERSION}-macOS-universal.dmg"

(
  cd dist
  find . -maxdepth 1 -type f -name "MiddleFlow-${VERSION}-*" -print \
    | sed 's#^./##' \
    | sort \
    | xargs shasum -a 256 > SHA256SUMS
)
echo "Packaged in dist/"
