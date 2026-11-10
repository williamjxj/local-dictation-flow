import AppKit
import AVFoundation
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate, AVAudioRecorderDelegate {
  var item: NSStatusItem!
  var floating: FloatingControls!
  var workerPath: String = ""
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
  var target: InsertionTarget?
  var lastExternalApplication: NSRunningApplication?
  var activationObserver: NSObjectProtocol?
  var destinationLabel: NSTextField!
  let inserter = TextInserter()
  var permissionLabel: NSTextField!
  var insertCountdown: Timer?
  var retryHotKey: EventHotKeyRef?
  var pushToTalk = PushToTalkState()
  var busy = false
  var quitWhenFinished = false
  var audioURL: URL?
  var project: String = ""
  let defaults = UserDefaults.standard

  func applicationDidFinishLaunching(_ notification: Notification) {
    rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
    activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
      self?.rememberExternalApplication(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
    }
    let marker = Bundle.main.url(forResource: "project-path", withExtension: nil)!
    let recordedPath = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""
    project = LocalResources.projectPath(bundleURL: Bundle.main.bundleURL, recordedPath: recordedPath)
    let bundledWorker = Bundle.main.resourceURL?.appendingPathComponent("engine.py").path
    workerPath = bundledWorker.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil } ?? project + "/engine.py"
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.title = "◉ Flow"
    let menu = NSMenu()
    menu.addItem(withTitle: "Start / stop dictation    ⌃⌥Space", action: #selector(toggle), keyEquivalent: "")
    menu.addItem(withTitle: "Show / hide floating controls", action: #selector(toggleFloating), keyEquivalent: "")
    menu.addItem(withTitle: "Settings and transcript…", action: #selector(showWindow), keyEquivalent: "")
    menu.addItem(withTitle: "Cancel dictation", action: #selector(cancel), keyEquivalent: "")
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
    menu.items.forEach { $0.target = self }
    item.menu = menu
    let mainMenu = NSMenu()
    let applicationMenu = NSMenu()
    let controlsItem = applicationMenu.addItem(withTitle: "Show Floating Controls", action: #selector(showFloating), keyEquivalent: "l")
    controlsItem.target = self
    let settingsItem = applicationMenu.addItem(withTitle: "Settings…", action: #selector(showWindow), keyEquivalent: ",")
    settingsItem.target = self
    let quitItem = applicationMenu.addItem(withTitle: "Quit Local Dictation Flow", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    let applicationItem = NSMenuItem()
    applicationItem.submenu = applicationMenu
    mainMenu.addItem(applicationItem)
    NSApp.mainMenu = mainMenu
    buildWindow()
    setupFloating()
    updateDestinationLabel()
    registerHotKey()
    refreshPermissions()
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshPermissions() }
    showFloating()
  }

  func registerHotKey() {
    let specs = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]
    let pointer = Unmanaged.passUnretained(self).toOpaque()
    _ = specs.withUnsafeBufferPointer { buffer in
      InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
        guard let context = context else { return OSStatus(eventNotHandledErr) }
        let app = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
        var pressed = EventHotKeyID()
        if let event = event { GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed) }
        let kind = event.map { GetEventKind($0) } ?? UInt32(kEventHotKeyPressed)
        let isPress = kind == UInt32(kEventHotKeyPressed)
        DispatchQueue.main.async {
          if pressed.id == 2 {
            if isPress { app.insertAtCurrentFocus() }
          } else if isPress {
            app.hotKeyPressed()
          } else {
            app.hotKeyReleased()
          }
        }
        return noErr
      }, 2, buffer.baseAddress, pointer, nil)
    }
    let id = EventHotKeyID(signature: 0x4C464C57, id: 1)
    let result = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKey)
    let retryID = EventHotKeyID(signature: 0x4C464C57, id: 2)
    RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey | shiftKey), retryID, GetApplicationEventTarget(), 0, &retryHotKey)
    if result != noErr { setStatus("Hotkey unavailable (\(result)). Use the menu or Record button.") }
  }

  func buildWindow() {
    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Local Dictation Flow · Settings"
    window.contentView?.wantsLayer = true
    window.contentView?.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
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
    let intro = NSTextField(wrappingLabelWithString: "Hold Control–Option–Space while speaking, then release to finish. Keep the destination text field focused. Audio and text stay on this Mac.")
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
    destinationLabel = NSTextField(wrappingLabelWithString: "")
    stack.addArrangedSubview(destinationLabel)
    stack.addArrangedSubview(NSTextField(labelWithString: "Whisper model · multilingual large-v3"))
    modelPath = NSTextField(string: LocalResources.modelPath(saved: defaults.string(forKey: "model"), project: project))
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
    permissionLabel = NSTextField(wrappingLabelWithString: "")
    stack.addArrangedSubview(permissionLabel)
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
    let insert = NSButton(title: "Insert result in 5 seconds…", target: self, action: #selector(insertAfterCountdown))
    let showControls = NSButton(title: "Show floating controls", target: self, action: #selector(showFloating))
    let actions = NSStackView(views: [copy, insert, showControls]); actions.spacing = 10
    stack.addArrangedSubview(actions)
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
  func setStatus(_ text: String) { statusLabel.stringValue = text; refreshFloating() }
  func setupFloating() {
    floating = FloatingControls()
    floating.record = { [weak self] in self?.toggle() }
    floating.settings = { [weak self] in self?.showWindow() }
    floating.quit = { [weak self] in self?.quit() }
  }
  func refreshFloating() {
    floating?.update(recording: recorder != nil, busy: busy, destination: lastExternalApplication?.localizedName, permission: AXIsProcessTrusted(), message: statusLabel?.stringValue ?? "")
  }
  @objc func showFloating() { refreshFloating(); floating?.show() }
  @objc func toggleFloating() {
    if floating.panel.isVisible { floating.panel.orderOut(nil) } else { showFloating() }
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showFloating(); return false }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    for (title, action) in [("Show Floating Controls", #selector(showFloating)), ("Settings and Transcript", #selector(showWindow))] {
      let item = menu.addItem(withTitle: title, action: action, keyEquivalent: ""); item.target = self
    }
    return menu
  }
  @objc func copyResult() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(resultView.string, forType: .string)
    setStatus("Result copied.")
  }
  @objc func toggle() {
    if busy { setStatus("Still transcribing. Your recording is being processed locally."); return }
    if recorder != nil { finish(); return }
    beginRecording(fromHotKey: false)
  }
  func hotKeyPressed() {
    if busy { setStatus("Still transcribing. Your recording is being processed locally."); return }
    if recorder != nil {
      if !pushToTalk.ownsRecording { finish() }
      return
    }
    guard pushToTalk.press() else { return }
    beginRecording(fromHotKey: true)
  }
  func hotKeyReleased() {
    guard pushToTalk.release() else { return }
    finish()
  }
  func beginRecording(fromHotKey: Bool) {
    insertCountdown?.invalidate(); insertCountdown = nil
    saveSettings()
    target = selectedDestination()
    updateDestinationLabel()
    guard FileManager.default.fileExists(atPath: modelPath.stringValue) else {
      if fromHotKey { pushToTalk.failedToStart() }
      setStatus("Model not found. Run scripts/download-model.sh or choose an existing multilingual Whisper model."); showWindow(); return
    }
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: start(fromHotKey: fromHotKey)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { allowed in
        DispatchQueue.main.async {
          if allowed {
            guard !fromHotKey || self.pushToTalk.isHeld else { self.pushToTalk.failedToStart(); return }
            self.start(fromHotKey: fromHotKey)
          } else {
            if fromHotKey { self.pushToTalk.failedToStart() }
            self.setStatus("Microphone permission denied. Enable it in System Settings → Privacy & Security → Microphone.")
          }
        }
      }
    default:
      if fromHotKey { pushToTalk.failedToStart() }
      setStatus("Enable microphone access in System Settings → Privacy & Security → Microphone."); showWindow()
    }
  }
  func start(fromHotKey: Bool = false) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("local-flow-" + UUID().uuidString)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
      let url = directory.appendingPathComponent("dictation.wav")
      let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000.0, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
      let audio = try AVAudioRecorder(url: url, settings: settings)
      audio.delegate = self
      guard audio.record() else { throw NSError(domain: "LocalFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not start microphone recording."]) }
      audioURL = url; recorder = audio
      if fromHotKey { pushToTalk.didStartRecording() }
      item.button?.title = "🔴 Recording"
      recordButton.title = "Stop and transcribe"
      setStatus(fromHotKey ? "Recording locally… release Control–Option–Space to finish." : "Recording locally… click Stop and transcribe to finish.")
    } catch {
      if fromHotKey { pushToTalk.failedToStart() }
      setStatus(error.localizedDescription)
    }
  }
  @objc func cancel() {
    guard !busy else { setStatus("Processing is in progress; the result will remain available here."); return }
    insertCountdown?.invalidate(); insertCountdown = nil
    pushToTalk.recordingEnded()
    recorder?.stop(); recorder = nil
    if let url = audioURL { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    audioURL = nil
    item.button?.title = "◉ Flow"; recordButton.title = "Record"
    setStatus("Cancelled. Recording deleted.")
  }
  func finish() {
    pushToTalk.recordingEnded()
    recorder?.stop(); recorder = nil
    guard let url = audioURL else { return }
    busy = true
    recordButton.isEnabled = false
    item.button?.title = "◌ Processing"
    setStatus("Transcribing on this Mac… large-v3 prioritizes accuracy and may take a while.")
    let lang = ["auto", "en", "zh"][max(0, language.indexOfSelectedItem)]
    let cleanup = ["basic", "raw", "rewrite"][max(0, mode.indexOfSelectedItem)]
    let args = [workerPath, "--audio", url.path, "--model", modelPath.stringValue, "--language", lang, "--mode", cleanup, "--rewrite-model", rewritePath.stringValue]
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
          if self.quitWhenFinished { NSApp.terminate(nil); return }
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
          if self.quitWhenFinished { NSApp.terminate(nil); return }
          self.busy = false; self.recordButton.isEnabled = true; self.recordButton.title = "Record"; self.item.button?.title = "◉ Flow"
          self.setStatus(error.localizedDescription)
        }
      }
    }
  }
  func rememberExternalApplication(_ app: NSRunningApplication?) {
    guard let app = app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
          !["com.apple.systempreferences", "com.apple.finder"].contains(app.bundleIdentifier ?? "") else { return }
    lastExternalApplication = app
    updateDestinationLabel()
  }
  func updateDestinationLabel() {
    guard destinationLabel != nil else { return }
    destinationLabel.stringValue = "Input destination: " + (lastExternalApplication?.localizedName ?? "Click your chat/editor first")
    refreshFloating()
  }
  func selectedDestination() -> InsertionTarget? {
    if let current = NSWorkspace.shared.frontmostApplication,
       current.processIdentifier != ProcessInfo.processInfo.processIdentifier {
      rememberExternalApplication(current)
    }
    return InsertionTarget.capture(application: lastExternalApplication)
  }
  func refreshPermissions() {
    guard permissionLabel != nil else { return }
    let enabled = AXIsProcessTrusted()
    permissionLabel.stringValue = enabled ? "✓ Automatic insertion enabled · Retry result: Control–Option–Shift–Space" : "⚠ Automatic insertion disabled · Enable Accessibility for this app build."
    permissionLabel.textColor = enabled ? .secondaryLabelColor : .systemOrange
    refreshFloating()
  }
  func insert(_ text: String, warning: String?) {
    let destination = target
    let performInsertion = { [weak self] in
      self?.inserter.insert(text, into: destination) { [weak self] message in
        self?.setStatus((warning.map { $0 + " " } ?? "") + message)
      }
    }
    if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
       let destination = destination, !destination.application.isTerminated {
      guard destination.application.activate(options: []) else {
        setStatus("Could not return to the destination. Focus it and press Control–Option–Shift–Space."); return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { performInsertion() }
    } else { performInsertion() }
  }
  @objc func insertAtCurrentFocus() {
    guard !busy, recorder == nil else { setStatus("Finish recording or processing before inserting a result."); return }
    insertCountdown?.invalidate(); insertCountdown = nil
    target = selectedDestination()
    insert(resultView.string, warning: nil)
  }
  @objc func insertAfterCountdown() {
    guard !busy, recorder == nil else { setStatus("Finish recording or processing first."); return }
    guard !resultView.string.isEmpty else { setStatus("No result to insert yet."); return }
    guard AXIsProcessTrusted() else { refreshPermissions(); setStatus("Enable Accessibility first, then retry this result without recording again."); return }
    insertCountdown?.invalidate()
    var remaining = 5
    setStatus("Focus your chat or terminal input. Inserting in 5 seconds…")
    insertCountdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
      guard let self = self else { timer.invalidate(); return }
      remaining -= 1
      if remaining == 0 { timer.invalidate(); self.insertCountdown = nil; self.insertAtCurrentFocus() }
      else { self.setStatus("Focus your chat or terminal input. Inserting in \(remaining) seconds…") }
    }
  }
  @objc func quit() {
    if busy { quitWhenFinished = true; setStatus("Quitting after the current transcription finishes…"); return }
    cancel(); NSApp.terminate(nil)
  }
}
@main
struct LocalDictationFlowMain {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    if let flag = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > flag + 1 {
      app.setActivationPolicy(.prohibited)
      let output = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
      try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
      delegate.project = Bundle.main.resourceURL?.path ?? ""
      delegate.buildWindow()
      delegate.setupFloating()
      delegate.updateDestinationLabel()
      delegate.refreshPermissions()
      precondition(!delegate.floating.panel.canBecomeKey && !delegate.floating.panel.canBecomeMain)
      precondition(delegate.floating.panel.styleMask.contains(.nonactivatingPanel))
      precondition(delegate.applicationShouldTerminateAfterLastWindowClosed(app) == false)
      for (name, recording, busy, permission) in [("floating-ready", false, false, true), ("floating-recording", true, false, true), ("floating-processing", false, true, true), ("floating-permission", false, false, false)] {
        delegate.floating.update(recording: recording, busy: busy, destination: "Perplexity", permission: permission, message: "Preview")
        savePreview(delegate.floating.panel.contentView!, to: output.appendingPathComponent(name + ".png"))
      }
      savePreview(delegate.window.contentView!, to: output.appendingPathComponent("settings.png"))
      print("Rendered five previews; nonactivating and lifecycle checks passed")
      return
    }
    app.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) { app.run() }
  }
}

private func savePreview(_ view: NSView, to path: URL) {
  view.layoutSubtreeIfNeeded()
  guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("Cannot render preview") }
  view.cacheDisplay(in: view.bounds, to: bitmap)
  guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode preview") }
  try! data.write(to: path)
}
