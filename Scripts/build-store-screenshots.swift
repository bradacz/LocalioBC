// Compose App Store artwork from real, unmodified app-content captures.
// Only the macOS title bar (including the screen-sharing indicator) is excluded.
import AppKit
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let shots: [(String, String, String)] = [
    ("editor", "Quick video crops. Made simple.", "Rychlý ořez. Bez složitostí."),
    ("crop", "One crop. Every clip.", "Jeden výřez. Všechny klipy."),
    ("export", "Export together. Or separately.", "Export společně. Nebo zvlášť.")
]
for language in ["en", "cs"] {
    let locale = language == "en" ? "en-US" : "cs"
    for (index, shot) in shots.enumerated() {
        let source = root.appendingPathComponent("AppStore/screenshots/raw/\(language)-\(shot.0).png")
        guard let image = NSImage(contentsOf: source) else { fatalError("Missing capture: \(source.path)") }
        let context = CGContext(data: nil, width: 1280, height: 800, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.scaleBy(x: 0.5, y: 0.5)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSColor(srgbRed: 0.965, green: 0.957, blue: 0.929, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 2560, height: 1600).fill()
        let ink = NSColor(srgbRed: 0.1, green: 0.12, blue: 0.17, alpha: 1)
        ("LOCALIOBC  /  macOS" as NSString).draw(at: NSPoint(x: 112, y: 1504), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0.2, green: 0.32, blue: 0.77, alpha: 1)])
        ((language == "en" ? shot.1 : shot.2) as NSString).draw(at: NSPoint(x: 108, y: 1393), withAttributes: [
            .font: NSFont.systemFont(ofSize: 76, weight: .bold), .foregroundColor: ink])
        // The captured window is 1180 logical points wide with a 31-point title bar.
        let titleBar = 31 * image.size.width / 1180
        let sourceRect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height - titleBar)
        let scale = min(2336 / sourceRect.width, 1270 / sourceRect.height)
        let size = NSSize(width: sourceRect.width * scale, height: sourceRect.height * scale)
        let destination = NSRect(x: (2560 - size.width) / 2, y: 65, width: size.width, height: size.height)
        NSGraphicsContext.current?.imageInterpolation = .high
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.13)
        shadow.shadowBlurRadius = 26; shadow.shadowOffset = NSSize(width: 0, height: -9)
        NSGraphicsContext.saveGraphicsState(); shadow.set()
        NSColor.white.setFill(); NSBezierPath(roundedRect: destination, xRadius: 14, yRadius: 14).fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: destination, xRadius: 14, yRadius: 14).addClip()
        image.draw(in: destination, from: sourceRect, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.black.withAlphaComponent(0.09).setStroke()
        NSBezierPath(roundedRect: destination, xRadius: 14, yRadius: 14).stroke()
        NSGraphicsContext.restoreGraphicsState()
        let output = root.appendingPathComponent("AppStore/screenshots/\(locale)/0\(index + 1)-\(shot.0).png")
        let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
        print(output.path)
    }
}
