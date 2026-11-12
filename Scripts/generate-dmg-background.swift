// Render the branded installer background at Retina resolution.
import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 840,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: 640, height: 420)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let ink = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)
let blue = NSColor(srgbRed: 0.19, green: 0.34, blue: 0.78, alpha: 1)
NSColor(srgbRed: 0.96, green: 0.965, blue: 0.975, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 640, height: 420).fill()
NSColor.white.setFill()
let panel = NSBezierPath(roundedRect: NSRect(x: 24, y: 98, width: 592, height: 220), xRadius: 18, yRadius: 18)
panel.fill()
NSColor.black.withAlphaComponent(0.07).setStroke(); panel.lineWidth = 1; panel.stroke()
("LocalioBC" as NSString).draw(at: NSPoint(x: 40, y: 358), withAttributes: [.font: NSFont.systemFont(ofSize: 28, weight: .bold), .foregroundColor: ink])
("Free, open-source video editing for your Mac." as NSString).draw(at: NSPoint(x: 40, y: 335), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: ink.withAlphaComponent(0.55)])
blue.setStroke()
let arrow = NSBezierPath(); arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 296, y: 214)); arrow.line(to: NSPoint(x: 344, y: 214))
arrow.move(to: NSPoint(x: 334, y: 224)); arrow.line(to: NSPoint(x: 344, y: 214)); arrow.line(to: NSPoint(x: 334, y: 204)); arrow.stroke()
let instruction = "Drag LocalioBC to Applications"
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: ink]
let width = (instruction as NSString).size(withAttributes: attrs).width
(instruction as NSString).draw(at: NSPoint(x: (640 - width) / 2, y: 61), withAttributes: attrs)
("macOS 14+  ·  Apple Silicon & Intel" as NSString).draw(at: NSPoint(x: 208, y: 35), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: ink.withAlphaComponent(0.5)])
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
