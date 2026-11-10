# AGENTS.md

macOS-only offline dictation app: Swift/AppKit launcher plus a stdlib-only Python worker. No package manifest, bundler, CI, or XCTest suite — everything runs through shell scripts.

## Commands

- `./scripts/test.sh` — full verification: compiles the Swift policy/config/resource/push-to-talk sources into `build/insertion-tests`, runs 23 assertions, then `python3 -m unittest discover -s tests -v` (8 tests).
- Single Python test: `python3 -m unittest tests.test_engine.CleanupTests.test_silence_never_invokes_whisper -v`
- `./scripts/build.sh` — development app at `build/Local Dictation Flow.app`. Compiles all `Sources/*.swift` together with `swiftc`; requires Xcode command-line tools.
- `./scripts/install.sh` — builds, copies the Turbo model once into Application Support (checksum-verified), backs up any existing app, installs to `/Applications/Local Dictation Flow.app`. Never downloads.
- `./scripts/download-model.sh` — first checkout only; downloads `ggml-large-v3-turbo.bin` into `models/`.
- Direct worker run: `python3 engine.py --audio <wav> --language en` (needs `/opt/homebrew/bin/whisper-cli`).

## Architecture

- `engine.py` is copied into the app bundle at build time and run via `/usr/bin/python3`. Editing it does **not** change an installed app until rebuild + reinstall.
- `Sources/LocalDictationFlow.swift` is the entrypoint (app delegate, settings, recording, insertion). `FloatingControls.swift` is the nonactivating floating panel; `TextInsertion.swift` holds destination/paste policy; `PushToTalkState.swift` owns hold/release ownership of a hotkey recording; `LocalResources.swift` resolves project path and model.
- Control–Option–Space is push-to-talk: press starts, release transcribes. The floating Record button is still click-to-toggle, and a hotkey press stops a button-started recording.
- The bundle identifier `dev.localflow.desktop` must stay stable — it keys UserDefaults, permissions, and install identity.
- Runtime processing is sequential child processes: whisper.cpp, then optionally llama.cpp. No cloud/network path.

## Models and signing gotchas

- The code default is `ggml-large-v3-turbo.bin` in `~/Library/Application Support/Local Dictation Flow/models/`. The Turbo model is the only supported Whisper weight; the deprecated large-v3 weight is no longer referenced by scripts, code, tests, or docs.
- Local absolute paths live in the gitignored `.env` (`LOCAL_DICTATION_REWRITE_MODEL`, `LOCAL_DICTATION_WHISPER_MODEL`); `.env.example` is the committed template. Settings/UserDefaults and shell environment variables take precedence. Rewrite failure falls back to Basic with a warning.
- Builds are ad-hoc signed (`codesign --sign -`). Rebuilding changes the signature and can invalidate Accessibility; re-authorize the installed `/Applications` app, not a dev build.

## Test and repo quirks

- `tests/audio/*` and most `tests/*-result.txt` are gitignored, so a fresh checkout has no audio fixtures; inference commands in `docs/verification.md` require regenerating them locally.
- `tests/swift/main.swift` is a standalone executable using `fatalError`, not XCTest. Add insertion/resource regressions there.
- Committed JSON under `tests/` is historical inference evidence, not an automated benchmark; don't overwrite it casually.
- `models/`, `build/`, and `evidence/*` (except `evidence/artifact-identities.json`) are local-only. Never commit extracted Wispr code or full REA exports.
- Cross-app insertion is not universally verified (notably Perplexity and terminals). Treat `docs/verification.md` as the source of truth for acceptance status; do not infer success from passing unit tests.
