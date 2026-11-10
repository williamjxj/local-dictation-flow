import AppKit

final class DictationPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class FloatingBackdrop: NSView {
  override func draw(_ dirtyRect: NSRect) {
    let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 20, yRadius: 20)
    NSColor(calibratedRed: 0.055, green: 0.095, blue: 0.12, alpha: 0.97).setFill(); shape.fill()
    NSColor(calibratedRed: 0.3, green: 0.9, blue: 0.8, alpha: 0.28).setStroke(); shape.lineWidth = 1; shape.stroke()
  }
}

private final class FloatingRecordButton: NSButton {
  override func draw(_ dirtyRect: NSRect) {
    let color = isEnabled ? (bezelColor ?? .systemTeal) : NSColor.darkGray
    color.withAlphaComponent(isHighlighted ? 0.75 : 1).setFill()
    NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10).fill()
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
    let text = (title == "Record" ? "● " : title == "Stop" ? "■ " : "") + title
    (text as NSString).draw(in: NSRect(x: 0, y: (bounds.height - 17) / 2, width: bounds.width, height: 20), withAttributes: attributes)
  }
}

private final class FloatingIconButton: NSButton {
  override func draw(_ dirtyRect: NSRect) {
    if isHighlighted { NSColor.white.withAlphaComponent(0.15).setFill(); NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill() }
    let symbol = image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white]))
    symbol?.draw(in: bounds.insetBy(dx: 5, dy: 3))
  }
}

final class FloatingControls: NSObject, NSWindowDelegate {
  let panel: DictationPanel
  private let defaults: UserDefaults
  private let recordButton: NSButton
  private let status: NSTextField
  private let destination: NSTextField
  private var didPosition = false
  var record: (() -> Void)?
  var settings: (() -> Void)?
  var quit: (() -> Void)?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    panel = DictationPanel(contentRect: NSRect(x: 0, y: 0, width: 410, height: 92), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    recordButton = FloatingRecordButton(title: "Record", target: nil, action: nil)
    status = NSTextField(labelWithString: "Ready · ⌃⌥Space")
    destination = NSTextField(labelWithString: "Click your input field, then record")
    super.init()
    panel.delegate = self
    panel.title = "Local Dictation Flow · Floating Controls"
    panel.level = .floating
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isMovableByWindowBackground = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.appearance = NSAppearance(named: .darkAqua)
    let background = FloatingBackdrop(frame: NSRect(x: 0, y: 0, width: 410, height: 92))
    background.wantsLayer = true
    background.layer?.cornerRadius = 20
    background.layer?.masksToBounds = true
    panel.contentView = background

    let title = NSTextField(labelWithString: "LOCAL DICTATION FLOW")
    title.font = .systemFont(ofSize: 10, weight: .bold)
    title.textColor = .systemTeal
    status.font = .systemFont(ofSize: 15, weight: .semibold)
    status.textColor = .white
    status.lineBreakMode = .byTruncatingTail
    destination.font = .systemFont(ofSize: 11)
    destination.textColor = NSColor(white: 0.85, alpha: 1)
    destination.lineBreakMode = .byTruncatingTail
    let labels = NSStackView(views: [title, status, destination])
    labels.orientation = .vertical
    labels.alignment = .leading
    labels.spacing = 4
    labels.translatesAutoresizingMaskIntoConstraints = false
    background.addSubview(labels)
    NSLayoutConstraint.activate([
      labels.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
      labels.centerYAnchor.constraint(equalTo: background.centerYAnchor),
      labels.widthAnchor.constraint(equalToConstant: 202)
    ])
    recordButton.target = self
    recordButton.action = #selector(recordClicked)
    recordButton.bezelStyle = .rounded
    recordButton.bezelColor = .systemTeal
    recordButton.contentTintColor = .black
    recordButton.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Record dictation")
    recordButton.imagePosition = .imageLeading
    recordButton.setAccessibilityLabel("Start or stop dictation")
    recordButton.toolTip = "Hold to talk · Control–Option–Space"
    let gear = symbol("gearshape", label: "Open settings and transcript", action: #selector(settingsClicked))
    let hide = symbol("minus", label: "Hide floating controls; keep app running", action: #selector(hideClicked))
    let power = symbol("power", label: "Quit Local Dictation Flow", action: #selector(quitClicked))
    let utilities = NSStackView(views: [gear, hide, power])
    utilities.spacing = 6
    let actions = NSStackView(views: [recordButton, utilities])
    actions.orientation = .vertical
    actions.spacing = 7
    actions.translatesAutoresizingMaskIntoConstraints = false
    background.addSubview(actions)
    NSLayoutConstraint.activate([
      actions.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -15),
      actions.centerYAnchor.constraint(equalTo: background.centerYAnchor),
      recordButton.widthAnchor.constraint(equalToConstant: 132)
    ])
  }

  private func symbol(_ name: String, label: String, action: Selector) -> NSButton {
    let button = FloatingIconButton(image: NSImage(systemSymbolName: name, accessibilityDescription: label)!, target: self, action: action)
    button.isBordered = false
    button.toolTip = label
    button.setAccessibilityLabel(label)
    button.widthAnchor.constraint(equalToConstant: 28).isActive = true
    button.heightAnchor.constraint(equalToConstant: 22).isActive = true
    return button
  }
  func show() {
    if !didPosition {
      let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
      var point = NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.minY + 45)
      if defaults.object(forKey: "floatingX") != nil {
        let saved = NSPoint(x: defaults.double(forKey: "floatingX"), y: defaults.double(forKey: "floatingY"))
        let rect = NSRect(origin: saved, size: panel.frame.size)
        if NSScreen.screens.contains(where: { $0.visibleFrame.contains(rect) }) { point = saved }
      }
      panel.setFrameOrigin(point)
      didPosition = true
    }
    panel.orderFrontRegardless()
  }
  func update(recording: Bool, busy: Bool, destination name: String?, permission: Bool, message: String) {
    recordButton.needsDisplay = true
    recordButton.title = busy ? "Processing…" : recording ? "Stop" : "Record"
    recordButton.isEnabled = !busy
    recordButton.bezelColor = recording ? .systemRed : .systemTeal
    recordButton.image = NSImage(systemSymbolName: recording ? "stop.fill" : "mic.fill", accessibilityDescription: nil)
    status.stringValue = message.hasPrefix("Quitting after") ? "Finishing, then quitting…" : recording ? "Recording · release keys or Stop" : busy ? "Processing on your Mac…" : !permission ? "Accessibility needed" : "Ready · ⌃⌥Space"
    destination.stringValue = name.map { "To: " + $0 } ?? "Click your input field, then record"
    panel.contentView?.toolTip = message
  }
  func windowDidMove(_ notification: Notification) {
    guard didPosition else { return }
    defaults.set(panel.frame.origin.x, forKey: "floatingX")
    defaults.set(panel.frame.origin.y, forKey: "floatingY")
  }
  @objc private func recordClicked() { record?() }
  @objc private func settingsClicked() { settings?() }
  @objc private func hideClicked() { panel.orderOut(nil) }
  @objc private func quitClicked() { quit?() }
}
