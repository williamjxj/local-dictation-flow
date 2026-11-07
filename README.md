# Local Flow

Offline English/Chinese dictation for macOS, built for an M3 Pro with 18 GB RAM. No account, API key, word quota, or runtime network service.

## Daily workflow

Use **Wispr Flow as the default**. When its usage allowance runs out, open Local Flow as the offline fallback. Switching is manual; Local Flow does not monitor Wispr's quota or switch automatically. Quit Local Flow when finished if you do not want its hotkey active.

Keep the app at `/Users/<local-user>/rea-work/local-flow/build/Local Flow.app`; moving it to Applications is not required. Keep the project directory in place because the app references its worker and model files here.

After a Mac restart, open Local Flow once when needed. **Control–Option–Space controls recording only while Local Flow is running**; it does not launch the application. Automatic login launch is optional and is not configured for this on-demand workflow. Closing the window leaves Local Flow running in the menu bar; choose **◉ Flow → Quit** to exit.

## Dictation

Open **`build/Local Flow.app`**. Press **Control–Option–Space** while a destination text field is focused, speak, then press again. Keep that field focused while the local model processes your audio.

1. Allow Microphone when prompted.
2. Enable Local Flow in **System Settings → Privacy & Security → Accessibility** for automatic insertion. After rebuilding, macOS may reject the old permission: quit Local Flow, remove its old Accessibility entry, add the current app from `build/`, enable it, then reopen.
3. Choose Auto, English, or 中文. Basic cleanup is the default; Raw preserves the transcript and Rewrite uses the local Qwen model.
4. If focus changes, permissions are unavailable, or the destination rejects paste, open Local Flow and use **Copy result**.

In this local workspace, the multilingual large-v3 model is already downloaded into `models/`. Model weights and generated builds are excluded from Git. Optional rewriting reuses Qwen2.5 7B on the connected external drive. You can edit either model path in the window. English/Chinese sentences retain their language; automatic mixed-language recognition may need an explicit language selection for best results.

## Build and checks

```sh
./scripts/build.sh
open 'build/Local Flow.app'
python3 -m unittest discover -s tests -v
python3 engine.py --audio path/to/mono-16khz.wav --language auto --mode basic
```

For a fresh checkout, install whisper.cpp and optional llama.cpp, then run `./scripts/download-model.sh`. Build with the Xcode command-line Swift compiler. See [runtime requirements](docs/resources.md).

Keep the project directory in place: the current development app references its worker and models here. It is ad-hoc signed and does not install a background service. To remove it, quit it and delete this project; remove its permissions in System Settings if desired.

[Wispr evidence and findings](docs/investigation.md) · [Verification and remaining checks](docs/verification.md)

The reconstruction follows observed feature patterns but does not reproduce Wispr's remote models, prompts, or context-aware formatting. Local inference trades cloud dependency for processing time and memory usage. Model output can contain errors; review names, numbers, and rewritten text.

## Current version status

Local microphone transcription, bilingual model inference, and cleanup are verified. Automatic insertion is implemented using the native Accessibility text-field API with a targeted paste fallback. The last inspected running build reported missing Accessibility authorization; successful cross-app insertion after reauthorizing that build has not been confirmed. **Copy result → paste manually** remains available.

Git stores the app source, scripts, docs, regression tests, synthetic inference result samples, and artifact hashes. Model weights, compiled apps, extracted Wispr code, full REA exports, recordings, and debug logs remain local and are not committed. No Git remote or automatic startup is configured by this project.
