# Local Dictation Flow runtime resources

| Resource | Required | Purpose |
|---|---|---|
| macOS on Apple Silicon | Yes | Native UI, microphone, global hotkey, Metal |
| Swift compiler / Xcode command-line tools | Build only | Compile AppKit application |
| System Python 3 | Yes | Offline inference worker, standard library only |
| `/opt/homebrew/bin/whisper-cli` | Yes | Local multilingual speech recognition |
| Local Whisper GGML weights | One selected model | Internal Turbo selected (1.62 GB); large-v3 retained (3.10 GB) |
| `/opt/homebrew/bin/llama-cli` | Rewrite only | Local text editing |
| Qwen2.5 7B Instruct GGUF | Rewrite only | Existing 4.7 GB model on external drive |
| Microphone permission | Recording only | macOS controlled access |
| Accessibility permission | Automatic insertion only | Native AXSelectedText insertion or standard Command-V event delivery for web/terminal inputs |
| Network, accounts, API keys | No at runtime | No cloud inference or fallback |
| Docker, database server, Node dependencies | No | Not used |

Whisper (currently Turbo) and Qwen run sequentially in child processes, releasing the speech model before text rewriting starts. No service needs to keep both loaded. Actual performance depends on other applications' memory pressure. External model storage must remain mounted for rewriting.

Storage: installed speech model in `~/Library/Application Support/Local Dictation Flow/models/`, development weights in `models/`; temporary recordings in a private temporary directory, removed after processing/cancel; current transcript in application memory and the editable result view; settings in macOS UserDefaults. No dictation history or credentials are written by Local Dictation Flow. Temporary transcript files created by the worker are removed on normal completion. A process crash can leave temporary files until OS cleanup.

The installed app contains its worker script and icon. Its default speech-model copy lives in Application Support and survives source-folder renames. Development builds can still resolve resources relative to the project and recorded build path. Optional rewriting continues to depend on the configured external GGUF path. This is an ad-hoc signed local build, without an Apple distribution signature.

## Launch and permissions

The normal installation is `/Applications/Local Dictation Flow.app`. Open it through Applications, Spotlight, or its Dock icon. Launch shows a draggable nonactivating floating bar; settings are opened through its gear. Minus hides the bar without quitting; Power or Command–Q quits. A pending transcription finishes before quitting, without inserting its result. Closing settings does not quit. No login item, background service, or automatic quota switching is configured.

`./scripts/install.sh` builds the app, copies the existing speech model once to Application Support with SHA-256 verification, and installs the bundle. Existing installed app bundles are kept as timestamped backups. This requires write access to Applications and the user's Application Support directory. It does not download any software. `iconutil` and `sips` (built into macOS) generate the app icon at build time.

Recompiling changes the ad-hoc signature. If Accessibility is missing, quit old copies, remove the old permission entry, add `/Applications/Local Dictation Flow.app`, enable it, and reopen. Microphone and Accessibility are independent. Opening/closing controls does not require rebuilding or changing permissions.
