import AVFoundation
import Foundation
import UniformTypeIdentifiers

enum VideoCodecOption: String, CaseIterable, Identifiable, Equatable {
    case h264 = "H.264"
    case hevc = "HEVC (H.265)"

    var id: String { rawValue }

    var avCodec: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .hevc: return .hevc
        }
    }

    var codecEfficiencyFactor: Double {
        switch self {
        case .h264: return 1.0
        case .hevc: return 0.68
        }
    }

    var shortHint: String {
        switch self {
        case .h264: return tr("Nejširší kompatibilita")
        case .hevc: return tr("Menší velikost souboru")
        }
    }
}

enum OutputContainer: String, CaseIterable, Identifiable, Equatable {
    case mp4 = "MP4"
    case mov = "MOV"

    var id: String { rawValue }

    var avFileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        }
    }

    var utType: UTType {
        switch self {
        case .mp4: return .mpeg4Movie
        case .mov: return .quickTimeMovie
        }
    }

    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        }
    }
}

enum OutputResolutionLimit: String, CaseIterable, Identifiable, Equatable {
    case original = "Původní"
    case p1080 = "Max 1080p"
    case p720 = "Max 720p"
    case p480 = "Max 480p"

    var id: String { rawValue }

    var maxLongEdge: CGFloat? {
        switch self {
        case .original: return nil
        case .p1080: return 1920
        case .p720: return 1280
        case .p480: return 854
        }
    }
}

enum CompressionMode: String, CaseIterable, Identifiable, Equatable {
    case passthrough = "Beze ztráty"
    case preset = "Kvalita"
    case targetSize = "Cílová velikost"

    var id: String { rawValue }
}

enum QualityPreset: String, CaseIterable, Identifiable, Equatable {
    case high = "Vysoká"
    case balanced = "Vyvážená"
    case compact = "Malá"
    case tiny = "Extra malá"

    var id: String { rawValue }

    var bitsPerPixel: Double {
        switch self {
        case .high: return 0.13
        case .balanced: return 0.075
        case .compact: return 0.04
        case .tiny: return 0.02
        }
    }
}

enum ExportMode: String, CaseIterable, Identifiable {
    case merged, separate
    var id: String { rawValue }
    var title: String { self == .merged ? tr("Spojit do jednoho videa") : tr("Každý klip samostatně") }
}

enum ExportSettingsError: LocalizedError {
    case targetSizeTooSmall(minimumMB: Double)

    var errorDescription: String? {
        switch self {
        case .targetSizeTooSmall(let minimumMB):
            return String(format: tr("Pro tuto délku je potřeba alespoň %.1f MB. Zvyšte cílovou velikost nebo video zkraťte."), ceil(minimumMB * 10) / 10)
        }
    }
}

struct ExportSettings: Equatable {
    private static let minimumVideoBitrate = 150_000
    private static let targetMediaBudgetFraction = 0.94
    var removeAudio = false
    var codec: VideoCodecOption = .h264
    var container: OutputContainer = .mp4
    var resolutionLimit: OutputResolutionLimit = .original
    var compressionMode: CompressionMode = .preset
    var qualityPreset: QualityPreset = .balanced
    var targetSizeMB: Double = 25.0

    /// Určí, zda lze použít okamžitý export bez překódování.
    func canUsePassthrough(for clips: [VideoClip]) -> Bool {
        guard compressionMode == .passthrough,
              clips.count == 1,
              let clip = clips.first,
              !clip.isCropped,
              resolutionLimit == .original else {
            return false
        }
        return true
    }

    func includesAudio(for clips: [VideoClip]) -> Bool {
        !removeAudio && clips.contains(where: \.hasAudio)
    }

    /// Spočítá cílové sudé rozlišení výstupu pro zadanou sadu klipů.
    func resolveOutputSize(for clips: [VideoClip]) -> CGSize {
        guard let first = clips.first else {
            return CGSize(width: 1920, height: 1080)
        }

        var size = first.croppedDisplaySize
        if let maxEdge = resolutionLimit.maxLongEdge {
            let currentLong = max(size.width, size.height)
            if currentLong > maxEdge {
                let scale = maxEdge / currentLong
                size = CGSize(width: size.width * scale, height: size.height * scale)
            }
        }

        return Self.evenDimensions(size)
    }

    static func evenDimensions(_ size: CGSize) -> CGSize {
        let evenW = max(2, Int((size.width / 2.0).rounded()) * 2)
        let evenH = max(2, Int((size.height / 2.0).rounded()) * 2)
        return CGSize(width: evenW, height: evenH)
    }

    func resolvedAudioBitrate(totalDuration: Double) -> Int {
        if compressionMode == .targetSize {
            let totalBits = max(1.0, targetSizeMB) * 1_000_000.0 * 8.0
            let totalBps = totalBits / max(0.5, totalDuration)
            if totalBps < 600_000 {
                return 96_000
            }
        }
        if compressionMode == .preset && qualityPreset == .tiny {
            return 96_000
        }
        return 128_000
    }

    func resolvedVideoBitrate(
        outputSize: CGSize,
        fps: Float,
        totalDuration: Double,
        hasAudio: Bool
    ) -> Int {
        let audioBps = hasAudio && !removeAudio ? resolvedAudioBitrate(totalDuration: totalDuration) : 0

        switch compressionMode {
        case .passthrough:
            // Bezpečný fallback pro případ, kdy passthrough není možný (např. jiný kontejner).
            let clampedFps = Double(max(15.0, min(60.0, fps)))
            let pixelsPerSecond = Double(outputSize.width * outputSize.height) * clampedFps
            let bitrate = pixelsPerSecond * QualityPreset.high.bitsPerPixel * codec.codecEfficiencyFactor
            return max(500_000, min(40_000_000, Int(bitrate)))
        case .targetSize:
            let safeDuration = max(0.5, totalDuration)
            let targetBytes = max(1.0, targetSizeMB) * 1_000_000.0
            // 6% rezerva na MP4/MOV kontejner a kolísání VBR
            let totalBudgetBps = (targetBytes * 8.0 * Self.targetMediaBudgetFraction) / safeDuration
            let videoBps = Int(totalBudgetBps) - audioBps
            return max(Self.minimumVideoBitrate, min(40_000_000, videoBps))
        case .preset:
            let clampedFps = Double(max(15.0, min(60.0, fps)))
            let pixelsPerSecond = Double(outputSize.width * outputSize.height) * clampedFps
            let bitrate = pixelsPerSecond * qualityPreset.bitsPerPixel * codec.codecEfficiencyFactor
            return max(250_000, min(30_000_000, Int(bitrate)))
        }
    }

    func validateTargetSize(for clips: [VideoClip]) throws {
        guard compressionMode == .targetSize, !clips.isEmpty else { return }
        let duration = clips.reduce(0.0) { $0 + $1.trimmedDuration }
        let audioBps = includesAudio(for: clips) ? resolvedAudioBitrate(totalDuration: duration) : 0
        let minimumMB = Double(Self.minimumVideoBitrate + audioBps) * max(0.5, duration)
            / (8 * Self.targetMediaBudgetFraction * 1_000_000)
        if max(1, targetSizeMB) < minimumMB {
            throw ExportSettingsError.targetSizeTooSmall(minimumMB: minimumMB)
        }
    }

    func estimatedOutputBytes(for clips: [VideoClip]) -> Int64 {
        let totalDuration = clips.reduce(0.0) { $0 + $1.trimmedDuration }
        guard totalDuration > 0 else { return 0 }

        if canUsePassthrough(for: clips), let clip = clips.first {
            let ratio = clip.trimmedDuration / clip.durationSeconds
            return max(1, Int64(Double(clip.fileSizeBytes) * ratio))
        }

        let outputSize = resolveOutputSize(for: clips)
        let fps = clips.map(\.nominalFrameRate).max() ?? 30
        let hasAudio = includesAudio(for: clips)
        let videoBps = resolvedVideoBitrate(
            outputSize: outputSize,
            fps: fps,
            totalDuration: totalDuration,
            hasAudio: hasAudio
        )
        let audioBps = hasAudio && !removeAudio ? resolvedAudioBitrate(totalDuration: totalDuration) : 0
        let overheadFactor = compressionMode == .targetSize ? 1 / Self.targetMediaBudgetFraction : 1.03
        let totalBytes = (Double(videoBps + audioBps) / 8.0) * totalDuration * overheadFactor
        return max(1, Int64(totalBytes))
    }
}
