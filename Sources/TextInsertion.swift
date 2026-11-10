import AppKit
import Carbon

struct InsertionRules {
  static func isTerminal(_ bundleID: String) -> Bool {
    let id = bundleID.lowercased()
    return ["com.apple.terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "org.tabby", "net.kovidgoyal.kitty", "org.alacritty", "dev.warp.warp-stable"].contains(id)
  }

  static func text(_ text: String, for bundleID: String) -> String {
    let trimmed = text.trimmingCharacters(in: .newlines)
    // Never submit a shell command by pasting a transcript's line breaks.
    return isTerminal(bundleID) ? trimmed.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ") : trimmed
  }

  static func prefersPaste(_ bundleID: String) -> Bool {
    let id = bundleID.lowercased()
    return isTerminal(id) || ["ai.perplexity.mac", "com.google.chrome", "com.microsoft.edgemac", "com.apple.safari", "org.mozilla.firefox", "com.microsoft.vscode"].contains(id)
  }
}

struct InsertionTarget {
  let application: NSRunningApplication
  let element: AXUIElement?

  static func capture() -> InsertionTarget? {
    return capture(application: NSWorkspace.shared.frontmostApplication)
  }

  static func capture(application: NSRunningApplication?) -> InsertionTarget? {
    guard let app = application, !app.isTerminated,
          app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute as CFString, &value)
    let element = result == .success && value != nil ? (value as! AXUIElement) : nil
    return InsertionTarget(application: app, element: element)
  }
}

final class TextInserter {
  func insert(_ original: String, into target: InsertionTarget?, completion: @escaping (String) -> Void) {
    guard AXIsProcessTrusted() else {
      completion("Automatic insertion needs Accessibility permission for this build. Enable Accessibility, then use Insert result again without re-recording.")
      return
    }
    guard let target = target else {
      completion("No destination selected. Click Insert result, then focus your chat or terminal during the countdown.")
      return
    }
    let app = target.application
    guard !app.isTerminated, NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
      let current = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown app"
      completion("Input paused: target is \(app.localizedName ?? "destination"), foreground is \(current). Focus the target and press Control–Option–Shift–Space to retry.")
      return
    }
    guard !IsSecureEventInputEnabled() else {
      completion("Secure keyboard input is active. Use Copy result and paste manually.")
      return
    }
    var value: CFTypeRef?
    let focusedResult = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute as CFString, &value)
    let focused: AXUIElement? = focusedResult == .success && value != nil ? (value as! AXUIElement) : nil
    if let focused = focused {
      var subrole: CFTypeRef?
      AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subrole)
      if (subrole as? String) == kAXSecureTextFieldSubrole {
        completion("Password fields require manual copy."); return
      }
      if let originalElement = target.element, !CFEqual(originalElement, focused) {
        completion("Input field changed. Focus the intended field and press Control–Option–Shift–Space to retry."); return
      }
    }
    let text = InsertionRules.text(original, for: app.bundleIdentifier ?? "")
    guard !text.isEmpty else { completion("No result to insert."); return }
    // AX writes work for native editors, but can miss web input events or terminal input.
    if !InsertionRules.prefersPaste(app.bundleIdentifier ?? ""), let focused = focused {
      var writable = DarwinBoolean(false)
      if AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &writable) == .success,
         writable.boolValue,
         AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
        completion("Inserted into \(app.localizedName ?? "destination")."); return
      }
    }
    // Wait for the dictation shortcut's Control/Option keys to be released.
    paste(text, app: app, target: target, attempt: 0, completion: completion)
  }

  private func paste(_ text: String, app: NSRunningApplication, target: InsertionTarget, attempt: Int, completion: @escaping (String) -> Void) {
    let held = CGEventSource.flagsState(.combinedSessionState).intersection([.maskControl, .maskAlternate, .maskShift, .maskCommand])
    if !held.isEmpty {
      guard attempt < 40 else { completion("Release modifier keys, then retry Insert result."); return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.paste(text, app: app, target: target, attempt: attempt + 1, completion: completion) }
      return
    }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
      completion("Focus changed before paste. Use Insert result to retry."); return
    }
    let board = NSPasteboard.general
    let saved = board.pasteboardItems?.map { item in item.types.compactMap { type in item.data(forType: type).map { (type, $0) } } } ?? []
    board.clearContents()
    guard board.setString(text, forType: .string) else { completion("Clipboard unavailable. Use Copy result."); return }
    let change = board.changeCount
    // HID/session delivery allows the app's normal Command-V handler to process
    // web contenteditable and terminal input, unlike direct-to-PID key events.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      guard board.changeCount == change,
            NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
        completion("Clipboard or destination changed before paste. Use Insert result to retry.")
        self.restore(saved, ifUnchanged: change)
        return
      }
      let source = CGEventSource(stateID: .hidSystemState)
      guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
        completion("Keyboard event unavailable. Use Copy result."); self.restore(saved, ifUnchanged: change); return
      }
      down.flags = .maskCommand
      up.flags = .maskCommand
      down.post(tap: .cghidEventTap)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        up.post(tap: .cghidEventTap)
        completion("Paste sent to \(app.localizedName ?? "destination"). No Enter key was sent.")
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.restore(saved, ifUnchanged: change) }
    }
  }

  private func restore(_ saved: [[(NSPasteboard.PasteboardType, Data)]], ifUnchanged change: Int) {
    let board = NSPasteboard.general
    guard board.changeCount == change else { return }
    board.clearContents()
    board.writeObjects(saved.map { entries -> NSPasteboardItem in
      let item = NSPasteboardItem()
      entries.forEach { item.setData($0.1, forType: $0.0) }
      return item
    })
  }
}
