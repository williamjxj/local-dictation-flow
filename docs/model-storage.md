# Local speech model storage

Both Whisper files now reside on the internal Mac disk:

`~/Library/Application Support/Local Dictation Flow/models/`

| File | Use | Bytes |
|---|---|---:|
| `ggml-large-v3-turbo.bin` | Selected by Local Dictation Flow for lower-latency dictation | 1,624,555,275 |
| `ggml-large-v3.bin` | Retained as an optional accuracy-focused alternative | 3,095,033,483 |

The Turbo file was moved from an external drive. Its copied SHA-256 matched the original before the external file was removed: `1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69`. Header metadata and successful whisper.cpp inference identify the Turbo decoder as 4 layers; the retained large-v3 decoder has 32 layers. No new model download was required.

Both apps were gracefully closed before migration. Updated and verified preference keys:

- `dev.localflow.desktop`: `model` → internal `ggml-large-v3-turbo.bin`.
- `ru.starmel.OpenSuperWhisper`: `selectedWhisperModelPath` → the same internal Turbo file.

OpenSuperWhisper's existing selected engine is `fluidaudio`. That engine choice was preserved; the updated Whisper path takes effect when its Whisper engine is selected. Its Application Support directory still links to the external drive; this migration moved only the Whisper model, not all of that app's data.

Local Dictation Flow's Rewrite mode was also preserved. Speech transcription now uses internal Turbo weights, while optional Qwen rewriting still requires the configured model on the external drive. Basic mode avoids that extra rewrite stage. No app rebuild or code-signature change was needed for this model-path switch.

## Verification

The installed app's bundled worker ran under a network-denying sandbox on existing synthetic speech fixtures. Turbo produced nonempty, correct English and Chinese sample transcripts. English Turbo took 1.75 seconds; the matching large-v3 run took 3.14 seconds. Chinese Turbo took 1.41 seconds. These include worker/model startup and are single short-fixture observations, not a broad performance or accuracy benchmark. Full synthetic outputs are in `tests/turbo-model-results.json`.

To switch back, quit Local Dictation Flow, change its model path to `ggml-large-v3.bin` in the same internal folder, and save/use that selection. The two files are different models, not duplicates. Neither is automatically downloaded by the running app; the source project's explicit download/install scripts remain separate setup operations.
