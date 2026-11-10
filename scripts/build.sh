#!/bin/zsh
set -eu
cd "${0:A:h:h}"
APP="$PWD/build/Local Dictation Flow.app"
MODULE_CACHE="$PWD/build/module-cache-$(printf '%s' "$PWD" | shasum -a 256 | cut -c1-12)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$MODULE_CACHE"
swiftc -module-cache-path "$MODULE_CACHE" -O -swift-version 5 Sources/*.swift -o "$APP/Contents/MacOS/Local Dictation Flow.new" -framework AppKit -framework AVFoundation -framework Carbon
mv "$APP/Contents/MacOS/Local Dictation Flow.new" "$APP/Contents/MacOS/Local Dictation Flow"
cp Info.plist "$APP/Contents/Info.plist"
cp engine.py "$APP/Contents/Resources/engine.py"
printf '%s' "$PWD" > "$APP/Contents/Resources/project-path"
ICONSET="$PWD/build/AppIcon.iconset"
mkdir -p "$ICONSET"
swift -module-cache-path "$MODULE_CACHE" scripts/make-icon.swift "$PWD/build/AppIcon.png"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" build/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" build/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier dev.localflow.desktop "$APP"
printf 'Built %s\n' "$APP"
