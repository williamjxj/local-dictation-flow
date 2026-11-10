#!/bin/zsh
set -eu
cd "${0:A:h:h}"
MODULE_CACHE="$PWD/build/module-cache-$(printf '%s' "$PWD" | shasum -a 256 | cut -c1-12)"
mkdir -p "$MODULE_CACHE"
swiftc -module-cache-path "$MODULE_CACHE" Sources/TextInsertion.swift Sources/LocalResources.swift tests/swift/main.swift -framework AppKit -framework Carbon -o build/insertion-tests
./build/insertion-tests
python3 -m unittest discover -s tests -v
