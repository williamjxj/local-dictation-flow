#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p models
if [[ -f models/ggml-large-v3.bin ]]; then
  echo 'Model already exists.'
  exit 0
fi
curl -L --fail --retry 2 --continue-at - -o models/ggml-large-v3.bin.part 'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3.bin'
echo '64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2  models/ggml-large-v3.bin.part' | shasum -a 256 -c -
mv models/ggml-large-v3.bin.part models/ggml-large-v3.bin
