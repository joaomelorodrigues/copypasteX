#!/bin/zsh
# Builds a downloadable copypasteX release: a universal app (Apple silicon + Intel) in a DMG and
# a zip, plus SHA-256 checksums, all in dist/.
#
#   scripts/release.sh 1.0.0
#
# The app is signed ad hoc and not notarized, so macOS asks people to approve it the first time
# they open it. The release notes explain how.
set -euo pipefail

VERSION=${1:?usage: scripts/release.sh <version>}
ROOT=${0:A:h:h}
BUILD="$ROOT/build/release"
DIST="$ROOT/dist"
APP="$BUILD/Build/Products/Release/copypasteX.app"
NAME="copypasteX-$VERSION"

rm -rf "${BUILD:?}" "${DIST:?}"
mkdir -p "$DIST"

echo "Building copypasteX $VERSION…"
xcodebuild -project "$ROOT/copypasteX.xcodeproj" -scheme copypasteX -configuration Release \
  -derivedDataPath "$BUILD" MARKETING_VERSION="$VERSION" ONLY_ACTIVE_ARCH=NO -quiet build

codesign --verify --strict "$APP"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/copypasteX")"

echo "Packaging…"
# The DMG has an Applications shortcut, so installing is a drag.
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/copypasteX.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "copypasteX $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov -quiet "$DIST/$NAME.dmg"

ditto -c -k --keepParent "$APP" "$DIST/$NAME.zip"

(cd "$DIST" && shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS.txt)

echo "Done:"
ls -lh "$DIST"
