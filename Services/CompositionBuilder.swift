import AVFoundation
import CoreGraphics
import Foundation

enum CompositionBuilderError: LocalizedError {
    case noClips
    case missingVideoTrack(String)
    case invalidTimeRange(String)

    var errorDescription: String? {
        switch self {
        case .noClips:
            return tr("Nejsou vybrány žádné videoklipy.")
        case .missingVideoTrack(let fileName):
            return tr("Soubor %@ neobsahuje obrazovou stopu.", fileName)
        case .invalidTimeRange(let fileName):
            return tr("Neplatný časový rozsah u klipu %@.", fileName)
        }
    }
}

struct BuiltComposition: @unchecked Sendable {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let renderSize: CGSize
    let targetFPS: Float
    let totalDuration: Double
    let hasAudio: Bool
}

enum CompositionBuilder {
    /// Sestaví sjednocenou AV kompozici pro více klipů včetně korekce rotace, ořezu a časového zkrácení.
    static func build(clips: [VideoClip], settings: ExportSettings) async throws -> BuiltComposition {
        guard !clips.isEmpty else {
            throw CompositionBuilderError.noClips
        }

        let outputSize = settings.resolveOutputSize(for: clips)
        let maxFPS = clips.map(\.nominalFrameRate).max() ?? 30.0
        let targetFPS = max(15.0, min(60.0, maxFPS > 0 ? maxFPS : 30.0))

        let composition = AVMutableComposition()
        let anyAudio = settings.includesAudio(for: clips)
        let compositionAudioTrack: AVMutableCompositionTrack? = anyAudio
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil

        var instructions: [AVMutableVideoCompositionInstruction] = []
        var insertCursor = CMTime.zero
        var actualHasAudio = false

        for clip in clips {
            let asset = AVURLAsset(url: clip.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = videoTracks.first else {
                throw CompositionBuilderError.missingVideoTrack(clip.fileName)
            }
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)

            let videoTrackRange = try await sourceVideoTrack.load(.timeRange)
            let naturalSize = try await sourceVideoTrack.load(.naturalSize)
            let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

            let startSec = max(videoTrackRange.start.seconds, clip.trimStart)
            let endSec = min(videoTrackRange.end.seconds, clip.trimEnd)
            guard endSec - startSec >= 0.03 else {
                throw CompositionBuilderError.invalidTimeRange(clip.fileName)
            }

            let trimStart = CMTime(seconds: startSec, preferredTimescale: 600)
            let trimEnd = CMTime(seconds: endSec, preferredTimescale: 600)
            let trimRange = CMTimeRange(start: trimStart, end: trimEnd)

            guard let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw CompositionBuilderError.missingVideoTrack(clip.fileName)
            }

            try compVideoTrack.insertTimeRange(trimRange, of: sourceVideoTrack, at: insertCursor)

            if let compAudioTrack = compositionAudioTrack {
                if let sourceAudioTrack = audioTracks.first {
                    let audioTrackRange = try await sourceAudioTrack.load(.timeRange)
                    let insertedAudio = try insertAudio(
                        from: sourceAudioTrack, availableRange: audioTrackRange,
                        trimRange: trimRange, into: compAudioTrack, at: insertCursor
                    )
                    actualHasAudio = actualHasAudio || insertedAudio
                } else {
                    compAudioTrack.insertEmptyTimeRange(
                        CMTimeRange(start: insertCursor, duration: trimRange.duration)
                    )
                }
            }

            let layerInstruction = makeLayerInstruction(
                for: compVideoTrack,
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                normalizedCrop: clip.cropRect,
                applyCropRect: clip.isCropped,
                outputSize: outputSize,
                at: insertCursor
            )

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: insertCursor, duration: trimRange.duration)
            instruction.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)

            insertCursor = CMTimeAdd(insertCursor, trimRange.duration)
        }

        if !actualHasAudio, let compAudioTrack = compositionAudioTrack {
            composition.removeTrack(compAudioTrack)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = outputSize
        videoComposition.frameDuration = CMTime(
            value: 1000,
            timescale: CMTimeScale(max(15_000, Int((Double(targetFPS) * 1000.0).rounded())))
        )
        videoComposition.instructions = instructions

        return BuiltComposition(
            composition: composition,
            videoComposition: videoComposition,
            renderSize: outputSize,
            targetFPS: targetFPS,
            totalDuration: max(0.05, insertCursor.seconds),
            hasAudio: actualHasAudio
        )
    }

    /// Zachová polohu dostupného zvuku uvnitř střihu včetně úvodního a koncového ticha.
    @discardableResult
    static func insertAudio(
        from sourceTrack: AVAssetTrack,
        availableRange: CMTimeRange,
        trimRange: CMTimeRange,
        into destinationTrack: AVMutableCompositionTrack,
        at cursor: CMTime
    ) throws -> Bool {
        let audioRange = trimRange.intersection(availableRange)
        guard audioRange.isValid, !audioRange.isEmpty, audioRange.duration.seconds > 0.01 else {
            destinationTrack.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: trimRange.duration))
            return false
        }
        let leadingSilence = CMTimeSubtract(audioRange.start, trimRange.start)
        let audioStart = CMTimeAdd(cursor, leadingSilence)
        if leadingSilence > .zero {
            destinationTrack.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: leadingSilence))
        }
        try destinationTrack.insertTimeRange(audioRange, of: sourceTrack, at: audioStart)
        let trailingSilence = CMTimeSubtract(trimRange.end, audioRange.end)
        if trailingSilence > .zero {
            destinationTrack.insertEmptyTimeRange(
                CMTimeRange(start: CMTimeAdd(audioStart, audioRange.duration), duration: trailingSilence)
            )
        }
        return true
    }

    @MainActor
    static func buildPreviewPlayerItem(clips: [VideoClip], settings: ExportSettings) async throws -> AVPlayerItem {
        let built = try await build(clips: clips, settings: settings)
        let item = AVPlayerItem(asset: built.composition)
        item.videoComposition = built.videoComposition
        return item
    }

    private static func makeLayerInstruction(
        for track: AVMutableCompositionTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        normalizedCrop: CGRect,
        applyCropRect: Bool,
        outputSize: CGSize,
        at startTime: CMTime
    ) -> AVMutableVideoCompositionLayerInstruction {
        let rawOrientedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let normalizeOrigin = CGAffineTransform(
            translationX: -rawOrientedRect.origin.x,
            y: -rawOrientedRect.origin.y
        )
        let orientedTransform = preferredTransform.concatenating(normalizeOrigin)
        let displaySize = CGSize(
            width: max(2, abs(rawOrientedRect.width)),
            height: max(2, abs(rawOrientedRect.height))
        )

        let clampedX = max(0.0, min(0.99, normalizedCrop.origin.x))
        let clampedY = max(0.0, min(0.99, normalizedCrop.origin.y))
        let clampedW = max(0.01, min(1.0 - clampedX, normalizedCrop.width))
        let clampedH = max(0.01, min(1.0 - clampedY, normalizedCrop.height))

        let cropInDisplay = CGRect(
            x: clampedX * displaySize.width,
            y: clampedY * displaySize.height,
            width: max(2, clampedW * displaySize.width),
            height: max(2, clampedH * displaySize.height)
        )

        let scale = min(outputSize.width / cropInDisplay.width, outputSize.height / cropInDisplay.height)
        let scaledWidth = cropInDisplay.width * scale
        let scaledHeight = cropInDisplay.height * scale
        let offsetX = (outputSize.width - scaledWidth) / 2.0
        let offsetY = (outputSize.height - scaledHeight) / 2.0

        let finalTransform = orientedTransform
            .concatenating(CGAffineTransform(translationX: -cropInDisplay.origin.x, y: -cropInDisplay.origin.y))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layerInstruction.setTransform(finalTransform, at: startTime)

        if applyCropRect {
            let naturalCrop = cropInDisplay.applying(orientedTransform.inverted())
            let fullNaturalBounds = CGRect(origin: .zero, size: naturalSize)
            let clampedNaturalCrop = naturalCrop.intersection(fullNaturalBounds)
            if !clampedNaturalCrop.isNull && !clampedNaturalCrop.isEmpty {
                layerInstruction.setCropRectangle(clampedNaturalCrop, at: startTime)
            }
        }

        return layerInstruction
    }
}
