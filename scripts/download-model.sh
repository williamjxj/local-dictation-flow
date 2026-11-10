#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p models
if [[ -f models/ggml-large-v3-turbo.bin ]]; then
  echo 'Model already exists.'
  exit 0
fi
curl -L --fail --retry 2 --continue-at - -o models/ggml-large-v3-turbo.bin.part 'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo.bin'
echo '1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69  models/ggml-large-v3-turbo.bin.part' | shasum -a 256 -c -
mv models/ggml-large-v3-turbo.bin.part models/ggml-large-v3-turbo.bin
