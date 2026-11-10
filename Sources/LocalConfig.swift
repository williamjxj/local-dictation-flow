import Foundation

struct LocalConfig {
  static func value(_ key: String, project: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
    if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
      return value
    }
    let path = URL(fileURLWithPath: project).appendingPathComponent(".env").path
    return values(at: path)[key]
  }

  static func values(at path: String) -> [String: String] {
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
    var result: [String: String] = [:]
    for raw in contents.split(whereSeparator: \.isNewline) {
      var line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty || line.hasPrefix("#") { continue }
      if line.hasPrefix("export ") {
        line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
      }
      guard let separator = line.firstIndex(of: "=") else { continue }
      let key = line[..<separator].trimmingCharacters(in: .whitespaces)
      var value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
      let doubleQuoted = value.hasPrefix("\"") && value.hasSuffix("\"")
      let singleQuoted = value.hasPrefix("'") && value.hasSuffix("'")
      if value.count >= 2, doubleQuoted || singleQuoted {
        value = String(value.dropFirst().dropLast())
      }
      if !key.isEmpty { result[String(key)] = value }
    }
    return result
  }
}
