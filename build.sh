#!/bin/bash
# Builds build/SideQuest.app. `./build.sh install` copies it to /Applications and starts it.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/SideQuest.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Universal binary: Apple Silicon + Intel.
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos13.0 -o "build/SideQuest-$arch" mac/main.swift -framework AppKit -framework WebKit -framework Carbon
done
lipo -create build/SideQuest-arm64 build/SideQuest-x86_64 -output "$APP/Contents/MacOS/SideQuest"
rm build/SideQuest-arm64 build/SideQuest-x86_64
cp mac/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"
if [ "${1:-}" = "zip" ]; then
  rm -rf build/zip SideQuest-Mac.zip
  mkdir -p "build/zip/SideQuest Arcade"
  cp -R "$APP" "build/zip/SideQuest Arcade/"
  cp mac/READ-ME-FIRST.txt "build/zip/SideQuest Arcade/"
  ditto -c -k --keepParent "build/zip/SideQuest Arcade" SideQuest-Mac.zip
  echo "Zipped SideQuest-Mac.zip"
fi

if [ "${1:-}" = "install" ]; then
  pkill -x SideQuest || true
  rm -rf /Applications/SideQuest.app
  cp -R "$APP" /Applications/
  open /Applications/SideQuest.app
  echo "Installed /Applications/SideQuest.app"
fi
