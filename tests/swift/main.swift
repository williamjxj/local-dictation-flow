import Foundation

func expect(_ condition: Bool, _ message: String) {
  if !condition { fatalError(message) }
}
expect(InsertionRules.text("echo hello\nrm example\r\n", for: "com.mitchellh.ghostty") == "echo hello rm example", "Terminal dictation must never contain command-submitting newlines")
expect(InsertionRules.text("First line\n第二行\n", for: "ai.perplexity.mac") == "First line\n第二行", "Chat paragraphs must be preserved")
expect(InsertionRules.prefersPaste("ai.perplexity.mac"), "Perplexity needs its normal paste handler")
expect(InsertionRules.prefersPaste("org.tabby"), "Terminal must bypass AX document writes")
expect(!InsertionRules.prefersPaste("com.apple.TextEdit"), "Native editor can use AX insertion")
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root.appendingPathComponent("models"), withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
try Data().write(to: root.appendingPathComponent("engine.py"))
try Data().write(to: root.appendingPathComponent("models/ggml-large-v3-turbo.bin"))
expect(LocalResources.projectPath(bundleURL: root.appendingPathComponent("build/App.app"), recordedPath: "/old-project") == root.path, "Renamed project must resolve relative to the app")
expect(LocalResources.modelPath(saved: "/old-project/models/ggml-large-v3-turbo.bin", project: root.path, supportDirectory: root.appendingPathComponent("support")) == root.appendingPathComponent("models/ggml-large-v3-turbo.bin").path, "Default model path must migrate after project rename")
let support = root.appendingPathComponent("support")
try FileManager.default.createDirectory(at: support.appendingPathComponent("models"), withIntermediateDirectories: true)
try Data().write(to: support.appendingPathComponent("models/ggml-large-v3-turbo.bin"))
expect(LocalResources.modelPath(saved: root.appendingPathComponent("models/ggml-large-v3-turbo.bin").path, project: root.path, supportDirectory: support) == support.appendingPathComponent("models/ggml-large-v3-turbo.bin").path, "Installed default model must survive project moves")

var push = PushToTalkState()
expect(push.press(), "First push-to-talk press starts recording")
push.didStartRecording()
expect(!push.press(), "A repeated press while held must not restart recording")
expect(push.release(), "Releasing the hotkey finishes the recording")
expect(!push.release(), "A release without a matching press is ignored")

var releasedEarly = PushToTalkState()
expect(releasedEarly.press(), "Press is accepted before permission resolves")
expect(!releasedEarly.release(), "Release before recording starts must not finish")
releasedEarly.didStartRecording()
expect(!releasedEarly.ownsRecording, "A late start must not own a recording whose key was released")

var failed = PushToTalkState()
expect(failed.press(), "Press is accepted before a start failure")
failed.failedToStart()
expect(!failed.release(), "A failed start must not finish on release")

var buttonStopped = PushToTalkState()
expect(buttonStopped.press(), "Press is accepted before a button stop")
buttonStopped.didStartRecording()
buttonStopped.recordingEnded()
expect(!buttonStopped.release(), "Release must not finish a recording stopped elsewhere")

let configRoot = root.appendingPathComponent("config-project")
try FileManager.default.createDirectory(at: configRoot, withIntermediateDirectories: true)
try "LOCAL_DICTATION_REWRITE_MODEL='/tmp/qwen model.gguf'\nexport LOCAL_DICTATION_WHISPER_MODEL=\"/tmp/whisper.bin\"\n# comment\n".write(to: configRoot.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
expect(LocalConfig.value("LOCAL_DICTATION_REWRITE_MODEL", project: configRoot.path, environment: [:]) == "/tmp/qwen model.gguf", "Quoted .env paths must load")
expect(LocalConfig.value("LOCAL_DICTATION_WHISPER_MODEL", project: configRoot.path, environment: [:]) == "/tmp/whisper.bin", "Exported .env paths must load")
expect(LocalConfig.value("LOCAL_DICTATION_REWRITE_MODEL", project: configRoot.path, environment: ["LOCAL_DICTATION_REWRITE_MODEL": "/override/model.gguf"]) == "/override/model.gguf", "Process environment must override .env")
expect(LocalConfig.value("MISSING", project: configRoot.path, environment: [:]) == nil, "Missing keys must stay nil")

print("23 push-to-talk, config, insertion, and resource checks passed")
