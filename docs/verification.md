# Verification

## Completed on this Mac

- Native Swift/AppKit production-optimized build passed (`scripts/build.sh`).
- Ad-hoc application signature verified with `codesign --verify --deep --strict`.
- Local Dictation Flow launched; Computer Use inspected the actual native window and confirmed language/mode controls, model paths, Record/Cancel, Accessibility and Copy controls.
- Six worker regression tests passed: conservative bilingual filler removal, missing speech model reporting, missing rewrite model fallback, rejection of language loss, silence skipping inference, and decimal preservation during sentence grouping.
- Large-v3 GGML model download identity verified against publisher metadata: SHA-256 `64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2`.
- Installed whisper.cpp ran with Metal access on local generated speech fixtures. English output: “Please send the revised report tomorrow morning. The meeting starts at 9.30.” Chinese output: “请明天上午发送修改后的报告,会议9点半开始。” Results are saved in `tests/english-result.json` and `tests/chinese-result.json`.
- English inference also passed under a macOS sandbox profile explicitly denying all network operations, including child processes (`tests/offline.sb`, `tests/offline-result.json`).
- Bilingual Qwen rewriting also passed with all network operations denied: “Please send the report tomorrow. 我们明天开会。” (`tests/offline-rewrite-result.json`).
- Existing Qwen2.5 7B GGUF loaded and generated text using local llama.cpp. Initial mixed-language editing translated Chinese; a language-preservation guard and sentence-wise editing were added. The final test passed without a fallback warning: “Please send the report tomorrow morning. 我们明天九点开会。” (`tests/rewrite-result.json`).

Fixtures use macOS's installed speech voices, not a microphone. They establish integration functionality, not representative dictation accuracy or Wispr parity. No broad accuracy benchmark has been performed.

## Interactive acceptance checks

The user enabled Microphone and Accessibility. Real microphone capture and local transcription were observed. Text appeared in TextEdit during the session, but the user subsequently reported that automatic insertion did not work. Therefore those observations do **not** establish successful automatic insertion, and the earlier completion claim was premature. The old build reported a combined focus/permission failure, without distinguishing the cause.

A revised build now reports permission, self-target, and foreground-change failures separately. It first tries the focused field’s writable AXSelectedText attribute, then falls back to paste events addressed to the destination PID. This revision compiles. The user subsequently reported another insertion failure; direct inspection of the running app showed “macOS has not granted this running build Accessibility access.” Reauthorizing the rebuilt app was recommended. A successful post-reauthorization insertion test has not been confirmed. Copy result remains the verified manual fallback interface.

Remaining interactive acceptance checks:

1. After future rebuilds, quit/reopen the app and recheck permissions if macOS requests it.
2. Check clipboard restoration with a known clipboard value; restoration is implemented but not independently observed in the interactive test.
3. Repeat with Chinese, then mixed English/Chinese. Compare Raw, Basic, and Rewrite. Review names and numbers; rewriting is probabilistic.
4. Repeat in a browser textarea and the user's everyday editor or chat app. Avoid sending the text; this check only inserts into a draft.
5. During processing switch to another app or another field. Confirm no automatic paste occurs and the result remains in Local Dictation Flow.
6. Cancellation returned the UI to idle; filesystem cleanup follows the reviewed cancellation path, but the exact temporary directory was not independently inspected during this UI test.
7. Confirm a second hotkey press during processing reports busy rather than starting overlapping inference.
8. Disconnect networking and repeat a recording. Rewriting additionally requires external drive mounted, or a replacement local GGUF path.

Compatibility limits: secure fields are intentionally excluded. Apps can reject synthetic paste; use Copy result. The app sends a paste event but does not claim the destination accepted it. A field's caret can move within the same accessibility element; no cursor-lock guarantee is claimed.

## Reproduction

```sh
./scripts/build.sh
python3 -m unittest discover -s tests -v
python3 engine.py --audio tests/audio/english.wav --language en
python3 engine.py --audio tests/audio/chinese.wav --language zh
/usr/bin/sandbox-exec -f tests/offline.sb /usr/bin/python3 engine.py --audio tests/audio/english.wav --language en
```

Sandboxed coding tools initially could not access Metal; inference verification was run with host access. This is an agent execution restriction, not a requirement for the application to use cloud services.

## Repository snapshot

The user accepted this version as an on-demand offline fallback to Wispr Flow. That workflow decision does not establish successful automatic insertion. Keep the app in the project’s `build/` folder and manually launch it when needed after a reboot. No automatic quota detection, app switching, or login startup is configured.

Synthetic result JSON files are committed as historical inference evidence, not an automated accuracy benchmark. Audio fixtures and build/test logs are generated locally and excluded from Git. To rerun the inference examples above, supply local audio fixtures at the indicated paths; a fresh checkout does not include them.

## Version 0.2 cross-app insertion repair

- Extracted destination capture and insertion into `Sources/TextInsertion.swift`.
- Perplexity, browsers, and recognized terminals use normal Command-V event delivery rather than AX document writes or PID-directed events. Native editors retain the AXSelectedText option.
- Paste waits for Control/Option/Shift/Command to be released, allows clipboard propagation, and conditionally restores the previous clipboard after two seconds.
- Terminal line breaks are flattened and no Enter event is generated. This prevents the app from intentionally submitting a shell command; normal terminal shortcuts and shell behavior remain external to the app.
- Added Control–Option–Shift–Space to insert the existing result at the current focus and a five-second countdown button for switching to a target app.
- The UI shows the actual current Accessibility trust status instead of discovering missing authorization only after transcription.
- Build passed. Seven Swift insertion/resource checks and six Python regression tests passed (`scripts/test.sh`). These checks do not simulate successful OS key delivery.
- Opened the actual 0.2 app: it reports **Automatic insertion disabled**. Live Perplexity and terminal tests are pending the user's reauthorization; no successful insertion is claimed from the build or policy tests alone.

### Project relocation follow-up

The project was moved from `local-flow` to `local-dictation-flow` after the first 0.2 build. Inspection found its recorded worker path still pointed to the old directory. The app now resolves the project from its bundle's parent build directory and migrates a missing old default model path to the relocated default. Compiler module caches are keyed by project path so a moved cache cannot break the next build. Rebuilt at the current path; 7 Swift checks and 6 Python tests passed. The actual running window shows the corrected model path, but still reports Accessibility disabled for this final build. Live cross-app verification remains pending reauthorization at the new path.

### Final permission repair and insertion test boundary

With the user's explicit approval, removed the stale Accessibility entry and added the current app from the renamed project directory through System Settings. The running app subsequently displayed **Automatic insertion enabled**; this verifies actual AX trust, not only the Settings switch.

Prepared a synthetic bilingual string in the result view and exercised the application's countdown insertion path. The app reported sending paste to Tabby, while Perplexity's input remained empty. Native automation's apparent Perplexity focus did not match the system foreground destination, so this is not a successful Perplexity test. No Enter key was generated. The Computer Use tool explicitly refused access to Tabby for safety reasons; no terminal contents or successful terminal insertion could be verified. Stopped automated countdown testing and requested physical-user tests with Control–Option–Shift–Space in Perplexity and the user's chosen terminal. Cross-app success remains unconfirmed until those results are observed/reported.

### Focus handoff follow-up

The user's subsequent terminal/TUI failure was accompanied by a live app status of `Destination changed`, so the attempt was rejected before paste delivery. Added last-external-app tracking and a visible destination label. Starting recording from the dictation window uses that remembered target; after processing, if the dictation app itself is foreground, it activates the selected target before insertion. If another external app is foreground, insertion remains paused and the status now names both applications. The retry hotkey also uses the remembered target when invoked from the app window. The revised build compiles; cross-app behavior remains pending a physical-user test. Updating its Accessibility entry encountered a macOS Touch ID unlock prompt and was handed to the user; no credentials were requested or entered by the agent.

## Version 0.3 floating launcher (November 9, 2026)

User request: stop depending on remembering scattered source directories to open or close the app. Chosen implementation: a native floating launcher with an Applications installation, retaining system-wide dictation scope rather than restricting it to Chrome.

- Added a draggable 410×92-point `NSPanel` with a nonactivating style. It cannot become key or main. Record, Settings, Hide, and Quit are exposed as accessible controls.
- Default launch and application-reopen show the floating bar. Settings open only through the gear, menu, or Command–Comma. Dock presence is enabled; closing settings does not terminate the app.
- Menu-bar controls can restore a hidden floating bar. Saved positions outside connected screens are discarded for a visible default position.
- The worker is bundled. The installer copies the default Whisper model into a fixed Application Support directory with publisher-checksum verification. Valid custom model paths remain supported.
- Native build, 8 Swift policy/resource checks, and 6 Python regression tests passed in staging. Offscreen rendering generated Ready, Recording, Processing, Permission-needed, and Settings previews. The render harness asserts the panel cannot become key/main and uses the nonactivating style. These checks do not simulate a physical mouse click into another application.
- Existing cross-app insertion limitations remain; no Perplexity or OpenCode/TUI acceptance success is inferred from the new launcher tests.
- No Chrome extension, login item, or cloud dependency was added. The intended use remains Wispr-first, local fallback on demand.

Final installation check: `/Applications/Local Dictation Flow.app` is version 0.3.0, has a valid ad-hoc signature, and bundles a byte-identical copy of `engine.py` plus its icon. The installed speech-model copy passed SHA-256 verification and has the expected 3,095,033,483-byte size. The app was launched successfully. OS window metadata confirmed the installed process uses regular Dock activation and has a visible 410×92-point floating control window. No startup login item was added. This launch check inspected only this application's process/window metadata; it did not perform a Perplexity or terminal input test.

## Push-to-talk hotkey

- **Control–Option–Space** now registers both Carbon pressed and released events: press starts recording; release stops it and begins local transcription. No second press is needed.
- The floating **Record** button remains click-to-toggle. A hotkey press still stops a recording that the button started.
- `PushToTalkState` ignores duplicate press events while held and releases that do not own the active recording, including permission-request races and button-started stops.
- 19 Swift policy/resource/push-to-talk assertions and 6 Python regression tests pass. The app was rebuilt, ad-hoc signed, and reinstalled to `/Applications`.
- Physical key-down/key-up acceptance with the installed app was not simulated by the agent; that final check requires holding the real hotkey.

## Internal Turbo model migration

Moved the existing external drive Turbo weights into the internal model directory after byte-for-byte SHA-256 verification, retaining large-v3. Verified both preference updates before removing the external file. The installed worker passed English and Chinese inference with network operations denied. A matching short English baseline measured 3.14 s for large-v3 versus 1.75 s for Turbo; this is a single-fixture measurement. See `docs/model-storage.md` and `tests/turbo-model-results.json`. No executable rebuild or signing change was made. OpenSuperWhisper's `fluidaudio` engine selection and Local Dictation Flow's Rewrite mode were preserved.
