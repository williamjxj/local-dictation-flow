# Wispr Flow investigation and Local Dictation Flow reconstruction

Target: installed `/Applications/Wispr Flow.app`, version **1.6.1400**. Investigation date: November 7, 2026. Scope: shipped package, selected static code, offline replacement. No Wispr account data, dictation history, or authentication tokens were acquired. Wispr Flow was not patched or executed for this investigation.

## Evidence ledger

| Question | Finding | Evidence / confidence | Status |
|---|---|---|---|
| Packaging | Electron/webpack app with a main process, renderer pages, preload bridge, and native helper integration | Original package manifest and ASAR inventory; REA parent `ev_2d50191d028ac73c1b2e7fdec1c4d9fc1de9a64849f5a7f25151d2dab5551a68` | Answered for installed build |
| Recording | Recorder AudioWorklet buffers Float32 samples in 640-sample chunks, responds to start/stop, flushes partial buffers on stop | `evidence/recorderWorklet.js`, SHA-256 `c2d5eba9275ae7d4831ea4c01fc426fe6c98d31097ac67d2c7ce12583f7029e2`; original REA parent above | Answered statically; microphone rate is not established by this worklet alone |
| Transcription and cleanup | A pipeline builder starts with transcription and alignment, optionally adds formatting; raw mode omits formatting | Focused module 99593, method `pipelineSteps`; focused REA parent `ev_cc124ec0848b82a6d54415bc2e3e049473fa6fa0c5e3d3ea1e203330cf5048a0` | Answered statically for this path |
| Local vs remote inference | The selected client code serializes audio/audio packets, language preferences, and context for a remote request; it includes a Baseten request path and fallback `/llm/asr` and `/llm/asr_audio_chunks` calls | Module 99593 `serializeFlowRequest`, `sendFlowRequest`, `_runOpenAIFallback`; module 65744 `transcribeOpenAI` and `transcribeOpenAIAudioChunks`; focused REA parent above | Remote paths observed in code; actual traffic and deployed server models unknown |
| Why contextual formatting can work | Request construction includes app identity, surrounding text, accessibility/OCR-derived words, dictionary terms, and personalization settings | Module 99593 `serializeFlowRequest`; focused REA parent above | Fields observed statically; which settings are active on this Mac is unknown |
| Insertion | Main bundle constructs a payload containing text and sends a `PasteText` helper request, with error handling | `evidence/index.js`, search anchor `captureKeystrokeTrace` adjacent to `PasteText`; schema declares `PasteTextPayload` | Native-helper boundary observed; internal helper implementation and app compatibility unverified |
| Usage limits | Main bundle contains weekly word-limit notifications with subscription/bonus-related branches | Search anchors `weekly_words_limit_alert_bonus_title`, `weekly_words_limit_alert_bonus_body` | Client notification behavior partially answered; exact entitlement accounting and server enforcement unresolved |
| Exact speech/format models | Client naming and fallback methods are insufficient to identify all current deployed weights or prompts | No server artifacts or runtime capture supplied | Unresolved; not claimed |

## Identity and limitations

Original ASAR SHA-256: `21a397cc8be184193741ff36fdbb6c800cf6b9371359b529483d293110f30054`.

Extracted main bundle SHA-256: `5c2a6c203dabef6b30adf482f0cf40f4f492a06917a5444a7ab58abfd6250d4d`.

REA's initial analysis rejected mismatched declared hashes for unpacked native members. A subsequent pass explicitly used `record-and-continue`, retaining those contradictions. Affected files: SQLite addon, Jabra connector, and panel activation addon. Signing or packaging changes are a possible explanation, not a verified cause. These bytes are not trusted as integrity-verified.

The 10.6 MB main bundle exhausted REA's default source-worker heap. It was not repeatedly reanalyzed. Two webpack method factories were extracted with Babel's parser without executing any target code, wrapped in an inert object expression, and analyzed separately. `evidence/focused/provenance.json` records original JavaScript string start/end offsets (UTF-16 units), not original UTF-8 byte offsets. Factory 65744 starts at 3824527 and ends at 3921229; factory 99593 starts at 3921230 and ends at 3935691. The wrapper changes the artifact digest and does not resolve webpack imports. Focused REA semantic coverage is partial and bounded; dynamic calls and cross-module behavior remain unknown.

Full exported REA records: local-only `evidence/rea-bundle.json` (four records), excluded from Git together with extracted Wispr sources. A checkout contains this findings ledger and artifact hashes, not the original code or complete evidence payloads. Summary IDs: `ev_d02054aaa7ae56c2673cc6e7c7bb72f9fd7264a135bc4fadfed50b8e38192b34` and `ev_dc9b8359d64490ddfebac8cba5dc071b3d8c5a1abd186b5ffdf7f80c27c71cd5`. The ledger above combines REA results with direct inspection of the extracted inert source. Direct source findings are explicitly distinguished from REA's completed source coverage.

## Reconstruction choices

Local Dictation Flow implements the useful sequence as **hotkey → native microphone recording → local Whisper large-v3 Turbo → optional cleanup/local Qwen → destination paste**. This is original implementation code. It uses no Wispr service or authentication, and has no account, word counter, subscription gate, or metered API.

- Native AppKit replaces Electron for the menu-bar app and preferences window.
- AVAudioRecorder produces mono 16 kHz PCM16 WAV.
- Carbon registers Control–Option–Space as a toggle hotkey.
- Installed whisper.cpp performs multilingual recognition with beam size 5. Its generated punctuation is retained. English and Chinese can be selected explicitly; auto mode is also available. Code-switched speech accuracy requires real-user evaluation.
- Basic cleanup conservatively removes English `um/uh/erm` and standalone Chinese `嗯/呃`. Meaningful words such as `然后` are preserved.
- Optional installed llama.cpp with the existing Qwen2.5 7B Instruct GGUF edits locally. It can still change meaning; Basic is the default. Failed rewriting retains the basic transcript and reports a warning.
- Insertion first uses the focused field’s writable AXSelectedText attribute. Its fallback uses the macOS clipboard and Command-V events addressed to the destination process; clipboard restoration is conditional on it not having changed. Destination application/field changes and secure text fields prevent automatic insertion. Copy remains available. Some applications reject synthetic paste; universal app compatibility is not claimed.
- No OCR, screen capture, surrounding-text collection, telemetry, or cloud fallback was added.

Whisper.cpp documents Apple Silicon acceleration in its [official repository](https://github.com/ggml-org/whisper.cpp). Model source: [ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp). Selected model: 1,624,555,275 bytes, SHA-256 `1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69`, matching the publisher's `x-linked-etag` response at revision `5359861c739e955e79d9a303bcbc70fb988958b1`.

## Verification scope

See `verification.md` and the JSON results under `tests/`. Successful build and generated-speech inference establish that the code compiles and models run. They do not establish real microphone quality, arbitrary app insertion, global hotkey behavior, or Wispr-equivalent accuracy. Those require the interactive permission-dependent acceptance checks.
