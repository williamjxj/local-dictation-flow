import AppKit
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: 1024, height: 1024)
let shape = NSBezierPath(roundedRect: rect.insetBy(dx: 36, dy: 36), xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.18, alpha: 1), ending: NSColor(calibratedRed: 0.04, green: 0.32, blue: 0.36, alpha: 1))!.draw(in: shape, angle: -45)
let glow = NSBezierPath(ovalIn: NSRect(x: 205, y: 205, width: 614, height: 614))
NSColor(calibratedRed: 0.15, green: 0.90, blue: 0.79, alpha: 0.16).setFill(); glow.fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 417, y: 400, width: 190, height: 350), xRadius: 95, yRadius: 95).fill()
let arc = NSBezierPath()
arc.move(to: NSPoint(x: 332, y: 510)); arc.line(to: NSPoint(x: 332, y: 450))
arc.curve(to: NSPoint(x: 692, y: 450), controlPoint1: NSPoint(x: 332, y: 220), controlPoint2: NSPoint(x: 692, y: 220))
arc.line(to: NSPoint(x: 692, y: 510)); arc.lineWidth = 43; arc.lineCapStyle = .round
NSColor(calibratedRed: 0.3, green: 0.97, blue: 0.83, alpha: 1).setStroke(); arc.stroke()
let stand = NSBezierPath(); stand.move(to: NSPoint(x: 512, y: 275)); stand.line(to: NSPoint(x: 512, y: 220)); stand.move(to: NSPoint(x: 420, y: 220)); stand.line(to: NSPoint(x: 604, y: 220)); stand.lineWidth = 43; stand.lineCapStyle = .round; stand.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
