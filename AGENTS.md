# AGENTS.md

macOS-only offline dictation app: Swift/AppKit launcher plus a stdlib-only Python worker. No package manifest, bundler, CI, or XCTest suite — everything runs through shell scripts.

## Commands

- `./scripts/test.sh` — full verification: compiles `Sources/TextInsertion.swift Sources/LocalResources.swift tests/swift/main.swift` into `build/insertion-tests`, runs 8 assertions, then `python3 -m unittest discover -s tests -v` (6 tests).
- Single Python test: `python3 -m unittest tests.test_engine.CleanupTests.test_silence_never_invokes_whisper -v`
- `./scripts/build.sh` — development app at `build/Local Dictation Flow.app`. Compiles all `Sources/*.swift` together with `swiftc`; requires Xcode command-line tools.
- `./scripts/install.sh` — builds, copies the large-v3 model once into Application Support (checksum-verified), backs up any existing app, installs to `/Applications/Local Dictation Flow.app`. Never downloads.
- `./scripts/download-model.sh` — first checkout only; downloads large-v3 into `models/`.
- Direct worker run: `python3 engine.py --audio <wav> --language en` (needs `/opt/homebrew/bin/whisper-cli`).

## Architecture

- `engine.py` is copied into the app bundle at build time and run via `/usr/bin/python3`. Editing it does **not** change an installed app until rebuild + reinstall.
- `Sources/LocalDictationFlow.swift` is the entrypoint (app delegate, settings, recording, insertion). `FloatingControls.swift` is the nonactivating floating panel; `TextInsertion.swift` holds destination/paste policy; `LocalResources.swift` resolves project path and model.
- The bundle identifier `dev.localflow.desktop` must stay stable — it keys UserDefaults, permissions, and install identity.
- Runtime processing is sequential child processes: whisper.cpp, then optionally llama.cpp. No cloud/network path.

## Models and signing gotchas

- The code default is `ggml-large-v3.bin` in `~/Library/Application Support/Local Dictation Flow/models/`. README/docs also describe an internal Turbo model, but Turbo is only reachable through a saved custom model path (UserDefaults on this machine) — it is neither bundled nor auto-selected by the build/install scripts.
- Rewrite mode hard-codes `/Volumes/external drive/...` as the GGUF path (`engine.py` and settings). It requires that drive mounted unless the path is changed; rewrite failure falls back to Basic with a warning.
- Builds are ad-hoc signed (`codesign --sign -`). Rebuilding changes the signature and can invalidate Accessibility; re-authorize the installed `/Applications` app, not a dev build.

## Test and repo quirks

- `tests/audio/*` and most `tests/*-result.txt` are gitignored, so a fresh checkout has no audio fixtures; inference commands in `docs/verification.md` require regenerating them locally.
- `tests/swift/main.swift` is a standalone executable using `fatalError`, not XCTest. Add insertion/resource regressions there.
- Committed JSON under `tests/` is historical inference evidence, not an automated benchmark; don't overwrite it casually.
- `models/`, `build/`, and `evidence/*` (except `evidence/artifact-identities.json`) are local-only. Never commit extracted Wispr code or full REA exports.
- Cross-app insertion is not universally verified (notably Perplexity and terminals). Treat `docs/verification.md` as the source of truth for acceptance status; do not infer success from passing unit tests.
