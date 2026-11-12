import AppKit
import AVFoundation
import Foundation

/// Reprezentuje jeden načtený videoklip včetně jeho časového a obrazového ořezu.
struct VideoClip: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileSizeBytes: Int64
    let duration: CMTime
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let displaySize: CGSize
    let nominalFrameRate: Float
    let hasAudio: Bool
    let estimatedDataRate: Float

    var trimStart: Double
    var trimEnd: Double
    var cropRect: CGRect
    var cropAspectRatio: AspectRatioPreset = .original
    var thumbnails: [NSImage]

    init(
        id: UUID = UUID(),
        url: URL,
        fileName: String,
        fileSizeBytes: Int64,
        duration: CMTime,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        displaySize: CGSize,
        nominalFrameRate: Float,
        hasAudio: Bool,
        estimatedDataRate: Float,
        thumbnails: [NSImage] = []
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.duration = duration
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        self.displaySize = displaySize
        self.nominalFrameRate = nominalFrameRate
        self.hasAudio = hasAudio
        self.estimatedDataRate = estimatedDataRate
        self.trimStart = 0
        self.trimEnd = max(0.1, duration.seconds)
        self.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        self.thumbnails = thumbnails
    }

    var durationSeconds: Double {
        max(0.1, duration.seconds)
    }

    var trimmedDuration: Double {
        max(0.1, trimEnd - trimStart)
    }

    var croppedDisplaySize: CGSize {
        CGSize(
            width: max(2, displaySize.width * cropRect.width),
            height: max(2, displaySize.height * cropRect.height)
        )
    }

    var isTrimmed: Bool {
        trimStart > 0.02 || trimEnd < (durationSeconds - 0.02)
    }

    var isCropped: Bool {
        abs(cropRect.origin.x) > 0.002
            || abs(cropRect.origin.y) > 0.002
            || abs(cropRect.width - 1.0) > 0.002
            || abs(cropRect.height - 1.0) > 0.002
    }
}
