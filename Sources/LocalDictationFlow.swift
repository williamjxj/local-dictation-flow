import AppKit
import AVFoundation
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate, AVAudioRecorderDelegate {
  var item: NSStatusItem!
  var recorder: AVAudioRecorder?
  var hotKey: EventHotKeyRef?
  var window: NSWindow!
  var statusLabel: NSTextField!
  var resultView: NSTextView!
  var language: NSPopUpButton!
  var mode: NSPopUpButton!
  var modelPath: NSTextField!
  var rewritePath: NSTextField!
  var recordButton: NSButton!
  var target: NSRunningApplication?
  var targetElement: AXUIElement?
  var busy = false
  var audioURL: URL?
  var project: String = ""
  let defaults = UserDefaults.standard

  func applicationDidFinishLaunching(_ notification: Notification) {
    let marker = Bundle.main.url(forResource: "project-path", withExtension: nil)!
    project = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.title = "◉ Flow"
    let menu = NSMenu()
    menu.addItem(withTitle: "Start / stop dictation    ⌃⌥Space", action: #selector(toggle), keyEquivalent: "")
    menu.addItem(withTitle: "Open Local Dictation Flow", action: #selector(showWindow), keyEquivalent: "")
    menu.addItem(withTitle: "Cancel dictation", action: #selector(cancel), keyEquivalent: "")
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
    menu.items.forEach { $0.target = self }
    item.menu = menu
    let mainMenu = NSMenu()
    let applicationMenu = NSMenu()
    let quitItem = applicationMenu.addItem(withTitle: "Quit Local Dictation Flow", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    let applicationItem = NSMenuItem()
    applicationItem.submenu = applicationMenu
    mainMenu.addItem(applicationItem)
    NSApp.mainMenu = mainMenu
    buildWindow()
    registerHotKey()
    showWindow()
  }

  func registerHotKey() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let pointer = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
      guard let context = context else { return OSStatus(eventNotHandledErr) }
      let app = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
      DispatchQueue.main.async { app.toggle() }
      return noErr
    }, 1, &spec, pointer, nil)
    let id = EventHotKeyID(signature: 0x4C464C57, id: 1)
    let result = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKey)
    if result != noErr { setStatus("Hotkey unavailable (\(result)). Use the menu or Record button.") }
  }

  func buildWindow() {
    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 650), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Local Dictation Flow · Offline dictation"
    window.center()
    window.isReleasedWhenClosed = false
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false
    window.contentView!.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -24)
    ])
    let title = NSTextField(labelWithString: "Your voice. On your Mac.")
    title.font = .systemFont(ofSize: 27, weight: .semibold)
    stack.addArrangedSubview(title)
    let intro = NSTextField(wrappingLabelWithString: "Press Control–Option–Space to start, then press again to finish. Keep the destination text field focused. Audio and text stay on this Mac.")
    stack.addArrangedSubview(intro)
    language = NSPopUpButton()
    language.addItems(withTitles: ["Auto · English / 中文", "English", "中文"])
    language.selectItem(at: defaults.integer(forKey: "language"))
    mode = NSPopUpButton()
    mode.addItems(withTitles: ["Basic · remove fillers", "Raw · preserve transcript", "Rewrite · local Qwen"])
    mode.selectItem(at: defaults.integer(forKey: "mode"))
    for popup in [language!, mode!] { popup.target = self; popup.action = #selector(saveSettings) }
    let choices = NSStackView(views: [language, mode]); choices.spacing = 12
    stack.addArrangedSubview(choices)
    stack.addArrangedSubview(NSTextField(labelWithString: "Whisper model · multilingual large-v3"))
    modelPath = NSTextField(string: defaults.string(forKey: "model") ?? project + "/models/ggml-large-v3.bin")
    stack.addArrangedSubview(modelPath)
    stack.addArrangedSubview(NSTextField(labelWithString: "Rewrite model · local GGUF (optional, external drive must be connected)"))
    rewritePath = NSTextField(string: defaults.string(forKey: "rewriter") ?? "/Volumes/external drive/ollama/models/blobs/sha256-2bada8a7450677000f678be90653b85d364de7db25eb5ea54136ada5f3933730")
    stack.addArrangedSubview(rewritePath)
    recordButton = NSButton(title: "Record", target: self, action: #selector(toggle))
    let permission = NSButton(title: "Enable Accessibility", target: self, action: #selector(accessibility))
    let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
    let controls = NSStackView(views: [recordButton, cancelButton, permission]); controls.spacing = 10
    stack.addArrangedSubview(controls)
    statusLabel = NSTextField(wrappingLabelWithString: "Ready. First use requires microphone permission. Accessibility enables insertion into other apps.")
    statusLabel.textColor = .secondaryLabelColor
    stack.addArrangedSubview(statusLabel)
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.borderType = .bezelBorder
    resultView = NSTextView()
    resultView.font = .systemFont(ofSize: 16)
    resultView.isEditable = true
    resultView.isVerticallyResizable = true
    resultView.autoresizingMask = [.width]
    scroll.documentView = resultView
    stack.addArrangedSubview(scroll)
    scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
    let copy = NSButton(title: "Copy result", target: self, action: #selector(copyResult))
    stack.addArrangedSubview(copy)
  }

  @objc func saveSettings() {
    defaults.set(language.indexOfSelectedItem, forKey: "language")
    defaults.set(mode.indexOfSelectedItem, forKey: "mode")
    defaults.set(modelPath.stringValue, forKey: "model")
    defaults.set(rewritePath.stringValue, forKey: "rewriter")
  }
  @objc func accessibility() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }
  @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
  func setStatus(_ text: String) { statusLabel.stringValue = text }
  @objc func copyResult() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(resultView.string, forType: .string)
    setStatus("Result copied.")
  }
  @objc func toggle() {
    if busy { setStatus("Still transcribing. Your recording is being processed locally."); return }
    if recorder != nil { finish(); return }
    saveSettings()
    target = NSWorkspace.shared.frontmostApplication
    targetElement = nil
    if let destination = target, AXIsProcessTrusted() {
      var element: CFTypeRef?
      if AXUIElementCopyAttributeValue(AXUIElementCreateApplication(destination.processIdentifier), kAXFocusedUIElementAttribute as CFString, &element) == .success,
         let element = element {
        targetElement = (element as! AXUIElement)
      }
    }
    guard FileManager.default.fileExists(atPath: modelPath.stringValue) else {
      setStatus("Model not found. Run scripts/download-model.sh or choose an existing multilingual Whisper model."); showWindow(); return
    }
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: start()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { allowed in
        DispatchQueue.main.async {
          if allowed { self.start() } else { self.setStatus("Microphone permission denied. Enable it in System Settings → Privacy & Security → Microphone.") }
        }
      }
    default: setStatus("Enable microphone access in System Settings → Privacy & Security → Microphone."); showWindow()
    }
  }
  func start() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("local-flow-" + UUID().uuidString)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
      let url = directory.appendingPathComponent("dictation.wav")
      let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000.0, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
      let audio = try AVAudioRecorder(url: url, settings: settings)
      audio.delegate = self
      guard audio.record() else { throw NSError(domain: "LocalFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not start microphone recording."]) }
      audioURL = url; recorder = audio
      item.button?.title = "🔴 Recording"
      recordButton.title = "Stop and transcribe"
      setStatus("Recording locally… press Control–Option–Space to finish.")
    } catch { setStatus(error.localizedDescription) }
  }
  @objc func cancel() {
    guard !busy else { setStatus("Processing is in progress; the result will remain available here."); return }
    recorder?.stop(); recorder = nil
    if let url = audioURL { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    audioURL = nil
    item.button?.title = "◉ Flow"; recordButton.title = "Record"
    setStatus("Cancelled. Recording deleted.")
  }
  func finish() {
    recorder?.stop(); recorder = nil
    guard let url = audioURL else { return }
    busy = true
    recordButton.isEnabled = false
    item.button?.title = "◌ Processing"
    setStatus("Transcribing on this Mac… large-v3 prioritizes accuracy and may take a while.")
    let lang = ["auto", "en", "zh"][max(0, language.indexOfSelectedItem)]
    let cleanup = ["basic", "raw", "rewrite"][max(0, mode.indexOfSelectedItem)]
    let args = [project + "/engine.py", "--audio", url.path, "--model", modelPath.stringValue, "--language", lang, "--mode", cleanup, "--rewrite-model", rewritePath.stringValue]
    DispatchQueue.global(qos: .userInitiated).async {
      defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
      process.arguments = args
      let pipe = Pipe(); process.standardOutput = pipe
      process.standardError = FileHandle.nullDevice
      do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let object = (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        DispatchQueue.main.async {
          self.busy = false; self.recordButton.isEnabled = true; self.recordButton.title = "Record"; self.item.button?.title = "◉ Flow"
          if let error = object["error"] as? String { self.setStatus(error); self.showWindow(); return }
          guard let text = object["text"] as? String else { self.setStatus("No transcript returned."); return }
          self.resultView.string = text
          if text.isEmpty { self.setStatus("No speech detected."); return }
          let warning = object["warning"] as? String
          self.insert(text, warning: warning)
        }
      } catch {
        DispatchQueue.main.async {
          self.busy = false; self.recordButton.isEnabled = true; self.recordButton.title = "Record"; self.item.button?.title = "◉ Flow"
          self.setStatus(error.localizedDescription)
        }
      }
    }
  }
  func insert(_ text: String, warning: String?) {
    let prefix = warning.map { $0 + " " } ?? ""
    guard AXIsProcessTrusted() else {
      setStatus(prefix + "Transcript ready. macOS has not granted this running build Accessibility access. Quit/reopen Local Dictation Flow, then recheck its Accessibility switch; use Copy result meanwhile.")
      return
    }
    guard let destination = target, destination.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
      setStatus(prefix + "Transcript ready. Recording began in Local Dictation Flow. Start with the hotkey while your destination text field is focused; use Copy result for this recording.")
      return
    }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.processIdentifier else {
      setStatus(prefix + "Transcript ready. The foreground app changed from \(destination.localizedName ?? "the destination"). Use Copy result; keep the destination focused during the next recording.")
      return
    }
    // Never paste into a secure field or a different application after processing.
    let app = AXUIElementCreateApplication(destination.processIdentifier)
    var focused: CFTypeRef?
    if AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
       let focused = focused {
      let element = focused as! AXUIElement
      if let original = targetElement, !CFEqual(original, element) {
        setStatus("Transcript ready. Destination field changed; use Copy result."); return
      }
      var subrole: CFTypeRef?
      AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
      if (subrole as? String) == kAXSecureTextFieldSubrole {
        setStatus("Transcript ready. Secure text fields require manual copy."); return
      }
      // Prefer the focused field's native insertion API. This avoids clipboard
      // timing and synthetic keyboard-event restrictions in standard editors.
      var writable = DarwinBoolean(false)
      if AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &writable) == .success,
         writable.boolValue,
         AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
        setStatus(prefix + "Inserted into \(destination.localizedName ?? "destination") using Accessibility.")
        return
      }
    }
    let board = NSPasteboard.general
    let saved = board.pasteboardItems?.map { entry in entry.types.compactMap { type in entry.data(forType: type).map { (type, $0) } } } ?? []
    board.clearContents(); board.setString(text, forType: .string)
    let change = board.changeCount
    let source = CGEventSource(stateID: .combinedSessionState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
    let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
    down?.flags = .maskCommand; up?.flags = .maskCommand
    down?.postToPid(destination.processIdentifier); up?.postToPid(destination.processIdentifier)
    setStatus((warning.map { $0 + " " } ?? "") + "Sent paste to \(destination.localizedName ?? "destination"). Result retained below.")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      guard board.changeCount == change else { return }
      board.clearContents()
      let items = saved.map { entries -> NSPasteboardItem in
        let item = NSPasteboardItem(); entries.forEach { item.setData($0.1, forType: $0.0) }; return item
      }
      board.writeObjects(items)
    }
  }
  @objc func quit() { if !busy { cancel(); NSApp.terminate(nil) } else { setStatus("Wait for local processing to finish before quitting.") } }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
