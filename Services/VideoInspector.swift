import AppKit
import AVFoundation
import Foundation

enum VideoInspectorError: LocalizedError {
    case missingVideoTrack
    case unreadableAsset(String)

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            return tr("Vybraný soubor neobsahuje žádnou obrazovou stopu.")
        case .unreadableAsset(let message):
            return tr("Nepodařilo se načíst video: %@", message)
        }
    }
}

private struct InspectedVideoData: Sendable {
    let fileSizeBytes: Int64
    let duration: CMTime
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let displaySize: CGSize
    let nominalFrameRate: Float
    let hasAudio: Bool
    let estimatedDataRate: Float
    let thumbnailCGImages: [CGImage]
}

enum VideoInspector {
    /// Načte metadata videoklipu včetně správné orientace a náhledových snímků pro timeline.
    @MainActor
    static func loadClip(from url: URL, thumbnailCount: Int = 12) async throws -> VideoClip {
        let data = try await inspect(url: url, thumbnailCount: thumbnailCount)
        let thumbnails = data.thumbnailCGImages.map { cgImage in
            NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }

        return VideoClip(
            url: url,
            fileName: url.lastPathComponent,
            fileSizeBytes: data.fileSizeBytes,
            duration: data.duration,
            naturalSize: data.naturalSize,
            preferredTransform: data.preferredTransform,
            displaySize: data.displaySize,
            nominalFrameRate: data.nominalFrameRate,
            hasAudio: data.hasAudio,
            estimatedDataRate: data.estimatedDataRate,
            thumbnails: thumbnails
        )
    }

    private static func inspect(url: URL, thumbnailCount: Int) async throws -> InspectedVideoData {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        let isPlayable: Bool
        let duration: CMTime
        let videoTracks: [AVAssetTrack]
        let audioTracks: [AVAssetTrack]

        do {
            isPlayable = try await asset.load(.isPlayable)
            duration = try await asset.load(.duration)
            videoTracks = try await asset.loadTracks(withMediaType: .video)
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw VideoInspectorError.unreadableAsset(error.localizedDescription)
        }

        guard isPlayable || !videoTracks.isEmpty else {
            throw VideoInspectorError.unreadableAsset(tr("Soubor není podporovaný nebo je poškozený."))
        }

        guard let videoTrack = videoTracks.first else {
            throw VideoInspectorError.missingVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)

        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(
            width: max(2, abs(transformedRect.width)),
            height: max(2, abs(transformedRect.height))
        )

        let fileSizeBytes = resolveFileSize(url: url)
        let effectiveDuration = duration.isNumeric && duration.seconds > 0
            ? duration
            : CMTime(seconds: 0.1, preferredTimescale: 600)

        let thumbnailImages = await generateThumbnails(
            for: asset,
            duration: effectiveDuration,
            count: max(1, thumbnailCount)
        )

        return InspectedVideoData(
            fileSizeBytes: fileSizeBytes,
            duration: effectiveDuration,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            displaySize: displaySize,
            nominalFrameRate: nominalFrameRate > 0 ? nominalFrameRate : 30.0,
            hasAudio: !audioTracks.isEmpty,
            estimatedDataRate: estimatedDataRate,
            thumbnailCGImages: thumbnailImages
        )
    }

    private static func resolveFileSize(url: URL) -> Int64 {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize {
            return Int64(size)
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            return size.int64Value
        }
        return 0
    }

    private static func generateThumbnails(
        for asset: AVAsset,
        duration: CMTime,
        count: Int
    ) async -> [CGImage] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)

        let totalSeconds = max(0.1, duration.seconds)
        var times: [CMTime] = []
        times.reserveCapacity(count)

        for index in 0..<count {
            let fraction = count == 1 ? 0.0 : Double(index) / Double(count)
            let seconds = min(max(0, totalSeconds * fraction), max(0, totalSeconds - 0.02))
            times.append(CMTime(seconds: seconds, preferredTimescale: 600))
        }

        var images: [CGImage] = []
        images.reserveCapacity(count)

        for await result in generator.images(for: times) {
            if let cgImage = try? result.image {
                images.append(cgImage)
            }
        }
        return images
    }
}
