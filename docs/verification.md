# Verification

## Completed on this Mac

- Native Swift/AppKit production-optimized build passed (`scripts/build.sh`).
- Ad-hoc application signature verified with `codesign --verify --deep --strict`.
- Local Flow launched; Computer Use inspected the actual native window and confirmed language/mode controls, model paths, Record/Cancel, Accessibility and Copy controls.
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
5. During processing switch to another app or another field. Confirm no automatic paste occurs and the result remains in Local Flow.
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
