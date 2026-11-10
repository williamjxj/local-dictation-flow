#!/bin/zsh
# Install the launcher and one stable copy of its speech model. No downloads.
set -eu
cd "${0:A:h:h}"
DESTINATION="${1:-/Applications/Local Dictation Flow.app}"
SUPPORT="$HOME/Library/Application Support/Local Dictation Flow"
./scripts/build.sh
if [[ ! -f "$SUPPORT/models/ggml-large-v3.bin" ]]; then
  if [[ ! -f models/ggml-large-v3.bin ]]; then
    print -u2 'Speech model missing. Run scripts/download-model.sh, then rerun install.sh.'
    exit 1
  fi
  mkdir -p "$SUPPORT/models"
  cp -p models/ggml-large-v3.bin "$SUPPORT/models/ggml-large-v3.bin.part"
  printf '%s  %s\n' '64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2' "$SUPPORT/models/ggml-large-v3.bin.part" | shasum -a 256 -c -
  mv "$SUPPORT/models/ggml-large-v3.bin.part" "$SUPPORT/models/ggml-large-v3.bin"
fi
if [[ -e "$DESTINATION" ]]; then
  BACKUP="$DESTINATION.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$DESTINATION" "$BACKUP"
  printf 'Previous app kept at %s\n' "$BACKUP"
fi
ditto 'build/Local Dictation Flow.app' "$DESTINATION"
codesign --verify --deep --strict "$DESTINATION"
printf 'Installed %s\n' "$DESTINATION"
