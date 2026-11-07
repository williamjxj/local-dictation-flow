# Local Flow runtime resources

| Resource | Required | Purpose |
|---|---|---|
| macOS on Apple Silicon | Yes | Native UI, microphone, global hotkey, Metal |
| Swift compiler / Xcode command-line tools | Build only | Compile AppKit application |
| System Python 3 | Yes | Offline inference worker, standard library only |
| `/opt/homebrew/bin/whisper-cli` | Yes | Local multilingual speech recognition |
| Whisper large-v3 GGML weights | Yes | Approximately 3.1 GB on disk; downloaded once |
| `/opt/homebrew/bin/llama-cli` | Rewrite only | Local text editing |
| Qwen2.5 7B Instruct GGUF | Rewrite only | Existing 4.7 GB model on external drive |
| Microphone permission | Recording only | macOS controlled access |
| Accessibility permission | Automatic insertion only | Native AXSelectedText insertion, with destination-targeted Command-V fallback |
| Network, accounts, API keys | No at runtime | No cloud inference or fallback |
| Docker, database server, Node dependencies | No | Not used |

Large-v3 and Qwen run sequentially in child processes, releasing the speech model before text rewriting starts. No service needs to keep both loaded. Actual performance depends on other applications' memory pressure. External model storage must remain mounted for rewriting.

Storage: speech model in `models/`; temporary recordings in a private temporary directory, removed after processing/cancel; current transcript in application memory and the editable result view; settings in macOS UserDefaults. No dictation history or credentials are written by Local Flow. Temporary transcript files created by the worker are removed on normal completion. A process crash can leave temporary files until OS cleanup.

The built app currently references this project's path. Keep this folder in place and rebuild after moving it. It is a local development build, ad-hoc signed, without an Apple distribution signature.

## Launch and permissions

The chosen installation is the app inside `build/`; the project stays at `/Users/<local-user>/rea-work/local-flow`. Wispr Flow is the primary app; Local Flow is opened manually when needed as an offline fallback. No login item or background service is installed. Launch once after each reboot when needed; the recording hotkey cannot launch a stopped app.

Recompiling changes this ad-hoc signed build. If macOS reports that the running build lacks Accessibility access, quit it, remove its previous entry in Privacy & Security → Accessibility, add the current `build/Local Flow.app`, enable it, and reopen. Microphone and Accessibility permissions are independent.
