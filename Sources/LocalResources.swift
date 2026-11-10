import Foundation

struct LocalResources {
  static func projectPath(bundleURL: URL, recordedPath: String) -> String {
    let adjacent = bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: adjacent.appendingPathComponent("engine.py").path) {
      return adjacent.path
    }
    return recordedPath
  }

  static func modelPath(saved: String?, project: String, supportDirectory: URL? = nil) -> String {
    let support = supportDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Local Dictation Flow")
    let installed = support.appendingPathComponent("models/ggml-large-v3-turbo.bin").path
    if (saved == nil || saved?.isEmpty == true || saved?.hasSuffix("/models/ggml-large-v3-turbo.bin") == true), FileManager.default.fileExists(atPath: installed) {
      return installed
    }
    let current = URL(fileURLWithPath: project).appendingPathComponent("models/ggml-large-v3-turbo.bin").path
    guard let saved = saved, !saved.isEmpty else { return current }
    if FileManager.default.fileExists(atPath: saved) { return saved }
    if saved.hasSuffix("/models/ggml-large-v3-turbo.bin"), FileManager.default.fileExists(atPath: current) { return current }
    return saved
  }
}
