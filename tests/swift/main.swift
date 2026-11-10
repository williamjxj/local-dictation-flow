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
try Data().write(to: root.appendingPathComponent("models/ggml-large-v3.bin"))
expect(LocalResources.projectPath(bundleURL: root.appendingPathComponent("build/App.app"), recordedPath: "/old-project") == root.path, "Renamed project must resolve relative to the app")
expect(LocalResources.modelPath(saved: "/old-project/models/ggml-large-v3.bin", project: root.path, supportDirectory: root.appendingPathComponent("support")) == root.appendingPathComponent("models/ggml-large-v3.bin").path, "Default model path must migrate after project rename")
let support = root.appendingPathComponent("support")
try FileManager.default.createDirectory(at: support.appendingPathComponent("models"), withIntermediateDirectories: true)
try Data().write(to: support.appendingPathComponent("models/ggml-large-v3.bin"))
expect(LocalResources.modelPath(saved: root.appendingPathComponent("models/ggml-large-v3.bin").path, project: root.path, supportDirectory: support) == support.appendingPathComponent("models/ggml-large-v3.bin").path, "Installed default model must survive project moves")
print("8 insertion and resource checks passed")
