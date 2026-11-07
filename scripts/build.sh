#!/bin/zsh
set -eu
cd "${0:A:h:h}"
APP="$PWD/build/Local Flow.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/module-cache
swiftc -module-cache-path "$PWD/build/module-cache" -O -swift-version 5 Sources/LocalFlow.swift -o "$APP/Contents/MacOS/Local Flow" -framework AppKit -framework AVFoundation -framework Carbon
cp Info.plist "$APP/Contents/Info.plist"
printf '%s' "$PWD" > "$APP/Contents/Resources/project-path"
codesign --force --sign - --identifier dev.localflow.desktop "$APP"
printf 'Built %s\n' "$APP"
