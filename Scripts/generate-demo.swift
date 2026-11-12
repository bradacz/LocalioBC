// Synthetic, original demonstration footage for public screenshots.
// Run: swift Scripts/generate-demo.swift /tmp/LocalioBC-demo.mov
import AppKit
import AVFoundation
import CoreVideo

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/tmp/LocalioBC-demo.mov")
if FileManager.default.fileExists(atPath: output.path) {
    fatalError("Destination exists. Choose a new path to preserve existing footage.")
}
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: 1280, AVVideoHeightKey: 720])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: 1280, kCVPixelBufferHeightKey as String: 720])
writer.add(input)
guard writer.startWriting() else { throw writer.error! }
writer.startSession(atSourceTime: .zero)
let deadline = Date().addingTimeInterval(30)
for frame in 0..<120 {
    while !input.isReadyForMoreMediaData {
        guard writer.status == .writing, Date() < deadline else { writer.cancelWriting(); fatalError("Encoder unavailable or timed out") }
        Thread.sleep(forTimeInterval: 0.002)
    }
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, 1280, 720, kCVPixelFormatType_32ARGB,
        [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &buffer)
    let pixelBuffer = buffer!
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: 1280, height: 720,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    color(0xf4eedf).setFill(); NSRect(x: 0, y: 0, width: 1280, height: 720).fill()
    color(0x151515).setFill(); NSRect(x: 72, y: 72, width: 1136, height: 576).fill()
    color(0x3157c8).setFill(); NSRect(x: 56, y: 88, width: 1136, height: 576).fill()
    color(0xf0c646).setFill(); NSBezierPath(ovalIn: NSRect(x: 880, y: 390, width: 380, height: 380)).fill()
    color(0xe9652a).setFill(); NSRect(x: 930, y: 88, width: 262, height: 240).fill()
    let white = color(0xf4eedf)
    ("LOCALIOBUZZ PRESENTS" as NSString).draw(at: NSPoint(x: 104, y: 574), withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .semibold), .foregroundColor: white])
    ("LocalioBC" as NSString).draw(at: NSPoint(x: 96, y: 350), withAttributes: [
        .font: NSFont.systemFont(ofSize: 116, weight: .black), .foregroundColor: white])
    ("Your videos. Your frame." as NSString).draw(at: NSPoint(x: 104, y: 284), withAttributes: [
        .font: NSFont.systemFont(ofSize: 36, weight: .medium), .foregroundColor: white])
    ("TRIM  /  CROP  /  COMPRESS" as NSString).draw(at: NSPoint(x: 104, y: 164), withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 22, weight: .semibold), .foregroundColor: white])
    color(0x151515).setFill()
    let triangle = NSBezierPath(); triangle.move(to: NSPoint(x: 1020, y: 146)); triangle.line(to: NSPoint(x: 1020, y: 262)); triangle.line(to: NSPoint(x: 1120, y: 204)); triangle.close(); triangle.fill()
    NSGraphicsContext.restoreGraphicsState()
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 24)) else { throw writer.error! }
}
input.markAsFinished()
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
guard finished.wait(timeout: .now() + 15) == .success, writer.status == .completed else {
    writer.cancelWriting(); fatalError("Could not finalize demonstration footage")
}
print(output.path)
