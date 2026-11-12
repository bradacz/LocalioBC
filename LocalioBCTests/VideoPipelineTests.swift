import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import XCTest
@testable import LocalioBC

final class VideoPipelineTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalioBCTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testAspectRatioCenteredCropAndSettings() {
        let crop9x16 = AspectRatioPreset.ratio9x16.centeredNormalizedCrop(
            for: CGSize(width: 1920, height: 1080)
        )
        XCTAssertEqual(crop9x16.origin.y, 0, accuracy: 0.0001)
        XCTAssertEqual(crop9x16.height, 1.0, accuracy: 0.0001)
        let pixelWidth = crop9x16.width * 1920.0
        let pixelHeight = crop9x16.height * 1080.0
        XCTAssertEqual(pixelWidth / pixelHeight, 9.0 / 16.0, accuracy: 0.001)

        var settings = ExportSettings()
        settings.compressionMode = .passthrough
        let fakeClip = VideoClip(
            url: URL(fileURLWithPath: "/tmp/a.mp4"),
            fileName: "a.mp4",
            fileSizeBytes: 1_000_000,
            duration: CMTime(seconds: 5, preferredTimescale: 600),
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: .identity,
            displaySize: CGSize(width: 1920, height: 1080),
            nominalFrameRate: 30,
            hasAudio: true,
            estimatedDataRate: 4_000_000
        )
        XCTAssertTrue(settings.canUsePassthrough(for: [fakeClip]))
        XCTAssertFalse(settings.canUsePassthrough(for: [fakeClip, fakeClip]))

        let fallbackBitrate = settings.resolvedVideoBitrate(
            outputSize: CGSize(width: 1920, height: 1080),
            fps: 30,
            totalDuration: 5,
            hasAudio: true
        )
        XCTAssertGreaterThan(fallbackBitrate, 500_000)
    }

    @MainActor
    func testRotatedVideoInspectionDisplaySizeAndThumbnails() async throws {
        let url = tempDir.appendingPathComponent("rotated_portrait.mov")
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: url,
            naturalSize: CGSize(width: 320, height: 180),
            durationSeconds: 1.0,
            fps: 24,
            preferredTransform: CGAffineTransform(rotationAngle: .pi / 2),
            includeAudio: false
        )

        let clip = try await VideoInspector.loadClip(from: url, thumbnailCount: 6)
        XCTAssertEqual(clip.naturalSize.width, 320, accuracy: 0.5)
        XCTAssertEqual(clip.naturalSize.height, 180, accuracy: 0.5)
        XCTAssertEqual(clip.displaySize.width, 180, accuracy: 0.5)
        XCTAssertEqual(clip.displaySize.height, 320, accuracy: 0.5)
        XCTAssertFalse(clip.hasAudio)
        XCTAssertEqual(clip.thumbnails.count, 6)
        if let firstThumb = clip.thumbnails.first {
            XCTAssertGreaterThan(firstThumb.size.height, firstThumb.size.width)
        }
    }

    @MainActor
    func testCropUnrotatedAndRotatedVideoPreservesExpectedQuadrantColor() async throws {
        // 1. Neotočené video 320x240: vlevo nahoře červená, vpravo nahoře zelená, vlevo dole modrá, vpravo dole žlutá.
        let unrotatedURL = tempDir.appendingPathComponent("quad_unrotated.mov")
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: unrotatedURL,
            naturalSize: CGSize(width: 320, height: 240),
            durationSeconds: 0.8,
            fps: 24,
            preferredTransform: .identity,
            includeAudio: false
        )

        var clip = try await VideoInspector.loadClip(from: unrotatedURL, thumbnailCount: 4)
        clip.cropRect = CGRect(x: 0.05, y: 0.05, width: 0.4, height: 0.4) // Horní levý kvadrant = červená

        var settings = ExportSettings()
        settings.compressionMode = .preset
        settings.qualityPreset = .high
        settings.container = .mp4

        let outUnrotated = tempDir.appendingPathComponent("out_unrotated.mp4")
        _ = try await VideoExporter.export(clips: [clip], settings: settings, to: outUnrotated) { _ in }

        let rgbUnrotated = try await TestMediaFactory.sampleCenterRGB(of: outUnrotated)
        XCTAssertGreaterThan(rgbUnrotated.r, 170, "Expected red dominant in unrotated top-left crop, got \(rgbUnrotated)")
        XCTAssertLessThan(rgbUnrotated.g, 80, "Expected low green in unrotated top-left crop, got \(rgbUnrotated)")
        XCTAssertLessThan(rgbUnrotated.b, 80, "Expected low blue in unrotated top-left crop, got \(rgbUnrotated)")

        // 2. Video otočené o 90° (preferredTransform = +90° po směru hodinových ručiček v Y-down souřadnicích):
        // Původní levý dolní kvadrant (modrá) se po otočení o +90° dostane do horního levého rohu zobrazení.
        let rotatedURL = tempDir.appendingPathComponent("quad_rotated.mov")
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: rotatedURL,
            naturalSize: CGSize(width: 320, height: 240),
            durationSeconds: 0.8,
            fps: 24,
            preferredTransform: CGAffineTransform(rotationAngle: .pi / 2),
            includeAudio: false
        )

        var rotatedClip = try await VideoInspector.loadClip(from: rotatedURL, thumbnailCount: 4)
        XCTAssertEqual(rotatedClip.displaySize.width, 240, accuracy: 0.5)
        XCTAssertEqual(rotatedClip.displaySize.height, 320, accuracy: 0.5)

        // Ověřme, jakou barvu má horní levý roh zobrazeného (orientovaného) videa přímo z náhledu AVAssetImageGenerator
        let sourceOrientedTopLeft = try await TestMediaFactory.sampleNormalizedRGB(
            of: rotatedURL,
            normalizedPoint: CGPoint(x: 0.25, y: 0.25)
        )

        // Ořízneme přesně tentýž horní levý kvadrant
        rotatedClip.cropRect = CGRect(x: 0.05, y: 0.05, width: 0.4, height: 0.4)
        let outRotated = tempDir.appendingPathComponent("out_rotated.mp4")
        _ = try await VideoExporter.export(clips: [rotatedClip], settings: settings, to: outRotated) { _ in }

        let exportedCenterRGB = try await TestMediaFactory.sampleCenterRGB(of: outRotated)
        XCTAssertEqual(Double(exportedCenterRGB.r), Double(sourceOrientedTopLeft.r), accuracy: 45)
        XCTAssertEqual(Double(exportedCenterRGB.g), Double(sourceOrientedTopLeft.g), accuracy: 45)
        XCTAssertEqual(Double(exportedCenterRGB.b), Double(sourceOrientedTopLeft.b), accuracy: 45)
    }

    @MainActor
    func testMultiClipMergeWithMixedOrientationsAndAudio() async throws {
        let clipAURL = tempDir.appendingPathComponent("clipA.mov")
        let clipBURL = tempDir.appendingPathComponent("clipB.mov")

        try await TestMediaFactory.writeFourQuadrantVideo(
            to: clipAURL,
            naturalSize: CGSize(width: 320, height: 180),
            durationSeconds: 1.2,
            fps: 30,
            preferredTransform: .identity,
            includeAudio: true
        )
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: clipBURL,
            naturalSize: CGSize(width: 320, height: 180),
            durationSeconds: 1.0,
            fps: 24,
            preferredTransform: CGAffineTransform(rotationAngle: .pi / 2),
            includeAudio: false
        )

        var clipA = try await VideoInspector.loadClip(from: clipAURL, thumbnailCount: 4)
        var clipB = try await VideoInspector.loadClip(from: clipBURL, thumbnailCount: 4)

        clipA.trimStart = 0.1
        clipA.trimEnd = 1.0 // 0.9s
        clipA.cropRect = AspectRatioPreset.ratio1x1.centeredNormalizedCrop(for: clipA.displaySize)

        clipB.trimStart = 0.1
        clipB.trimEnd = 0.9 // 0.8s
        clipB.cropRect = AspectRatioPreset.ratio1x1.centeredNormalizedCrop(for: clipB.displaySize)

        var settings = ExportSettings()
        settings.compressionMode = .preset
        settings.qualityPreset = .balanced
        settings.container = .mp4

        let mergedURL = tempDir.appendingPathComponent("merged.mp4")
        let result = try await VideoExporter.export(clips: [clipA, clipB], settings: settings, to: mergedURL) { _ in }

        XCTAssertFalse(result.usedPassthrough)
        XCTAssertGreaterThan(result.fileSizeBytes, 1000)

        let mergedAsset = AVURLAsset(url: mergedURL)
        let duration = try await mergedAsset.load(.duration)
        let videoTracks = try await mergedAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await mergedAsset.loadTracks(withMediaType: .audio)

        XCTAssertEqual(duration.seconds, 1.7, accuracy: 0.18)
        XCTAssertEqual(videoTracks.count, 1)
        XCTAssertEqual(audioTracks.count, 1)

        if let vTrack = videoTracks.first {
            let size = try await vTrack.load(.naturalSize)
            XCTAssertEqual(size.width, size.height, accuracy: 2.0)
        }
    }

    @MainActor
    func testDelayedAudioPreservesLeadingAndTrailingSilenceAcrossClips() async throws {
        let source = tempDir.appendingPathComponent("audio.mov")
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: source, naturalSize: CGSize(width: 320, height: 180), durationSeconds: 2,
            fps: 24, preferredTransform: .identity, includeAudio: true
        )
        let sourceAsset = AVURLAsset(url: source)
        defer { withExtendedLifetime(sourceAsset) {} }
        let sourceTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        let sourceTrack = try XCTUnwrap(sourceTracks.first)
        let composition = AVMutableComposition()
        let audioTrack = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
        func time(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 600) }
        // Only 0.5...1.3 of the source is available. Trim 0.2...1.8 and place
        // it after a 0.4-second silent clip, then append a second trimmed clip.
        let available = CMTimeRange(start: time(0.5), end: time(1.3))
        XCTAssertTrue(try CompositionBuilder.insertAudio(
            from: sourceTrack, availableRange: available,
            trimRange: CMTimeRange(start: time(0.2), end: time(1.8)),
            into: audioTrack, at: time(0.4)
        ))
        XCTAssertTrue(try CompositionBuilder.insertAudio(
            from: sourceTrack, availableRange: available,
            trimRange: CMTimeRange(start: time(0.8), end: time(1.8)),
            into: audioTrack, at: time(2)
        ))
        let media = audioTrack.segments.filter { !$0.isEmpty }
        XCTAssertEqual(media.count, 2)
        guard media.count == 2 else { return }
        XCTAssertEqual(media[0].timeMapping.target.start.seconds, 0.7, accuracy: 0.005)
        XCTAssertEqual(media[0].timeMapping.target.duration.seconds, 0.8, accuracy: 0.005)
        XCTAssertEqual(media[0].timeMapping.source.start.seconds, 0.5, accuracy: 0.005)
        XCTAssertEqual(media[1].timeMapping.target.start.seconds, 2, accuracy: 0.005)
        XCTAssertEqual(media[1].timeMapping.target.duration.seconds, 0.5, accuracy: 0.005)
        XCTAssertEqual(media[1].timeMapping.source.start.seconds, 0.8, accuracy: 0.005)
        XCTAssertTrue(audioTrack.segments.contains { $0.isEmpty && abs($0.timeMapping.target.duration.seconds - 0.5) < 0.005 })
        // No overlap contributes silence and must not add media samples.
        XCTAssertFalse(try CompositionBuilder.insertAudio(
            from: sourceTrack, availableRange: available,
            trimRange: CMTimeRange(start: time(1.5), end: time(2)),
            into: audioTrack, at: time(3)
        ))
        XCTAssertEqual(audioTrack.segments.filter { !$0.isEmpty }.count, 2)
    }

    func testTargetSizeValidationAndEstimateUseActualBitrate() throws {
        for hasAudio in [false, true] {
            let clip = makeClip(duration: 600, hasAudio: hasAudio)
            var settings = ExportSettings()
            settings.compressionMode = .targetSize
            settings.targetSizeMB = 5
            XCTAssertThrowsError(try settings.validateTargetSize(for: [clip]))
            let bitrate = settings.resolvedVideoBitrate(outputSize: clip.displaySize, fps: 30,
                                                        totalDuration: 600, hasAudio: hasAudio)
            let audioBps = hasAudio ? settings.resolvedAudioBitrate(totalDuration: 600) : 0
            let expectedBytes = Double(bitrate + audioBps) * 600 / 8 / 0.94
            XCTAssertEqual(Double(settings.estimatedOutputBytes(for: [clip])), expectedBytes, accuracy: 1)
            XCTAssertGreaterThan(settings.estimatedOutputBytes(for: [clip]), 5_000_000)
            settings.targetSizeMB = 30
            XCTAssertNoThrow(try settings.validateTargetSize(for: [clip]))
            XCTAssertEqual(Double(settings.estimatedOutputBytes(for: [clip])), 30_000_000, accuracy: 100)
        }
    }

    func testImpossibleTargetIsRejectedBeforeCreatingOutput() async throws {
        var settings = ExportSettings()
        settings.compressionMode = .targetSize
        settings.targetSizeMB = 5
        let destination = tempDir.appendingPathComponent("impossible.mp4")
        do {
            _ = try await VideoExporter.export(clips: [makeClip(duration: 600, hasAudio: true)],
                                               settings: settings, to: destination) { _ in }
            XCTFail("An impossible target must be rejected before opening the source.")
        } catch is ExportSettingsError {
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @MainActor
    func testLatePreviewCannotRestoreClearedProjectOrSelectedClip() async throws {
        var pending: [CheckedContinuation<AVPlayerItem, Error>] = []
        let model = EditorViewModel(previewBuilder: { _, _ in
            try await withCheckedThrowingContinuation { pending.append($0) }
        })
        let clip = makeClip()
        model.clips = [clip]
        model.selectedClipID = clip.id
        model.setComposedPreviewEnabled(true)
        try await waitUntil { pending.count == 1 }
        model.selectClip(clip.id)
        let selectedItem = model.player.currentItem
        let staleItem = AVPlayerItem(asset: AVMutableComposition())
        pending[0].resume(returning: staleItem)
        await drainMainActor()
        XCTAssertTrue(model.player.currentItem === selectedItem)
        XCTAssertFalse(model.isPreviewingComposedResult)
        XCTAssertFalse(model.isBuildingPreview)

        model.setComposedPreviewEnabled(true)
        try await waitUntil { pending.count == 2 }
        model.clearAll()
        pending[1].resume(throwing: NSError(domain: "LatePreview", code: 1))
        await drainMainActor()
        XCTAssertNil(model.player.currentItem)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.clips.isEmpty)
        XCTAssertFalse(model.isBuildingPreview)
    }

    @MainActor
    func testOnlyLatestPreviewCanComplete() async throws {
        var pending: [CheckedContinuation<AVPlayerItem, Error>] = []
        let model = EditorViewModel(previewBuilder: { _, _ in
            try await withCheckedThrowingContinuation { pending.append($0) }
        })
        model.clips = [makeClip()]
        model.selectedClipID = model.clips[0].id
        model.setComposedPreviewEnabled(true)
        try await waitUntil { pending.count == 1 }
        model.setResolutionLimit(.p720)
        try await waitUntil { pending.count == 2 }
        pending[0].resume(returning: AVPlayerItem(asset: AVMutableComposition()))
        await drainMainActor()
        XCTAssertTrue(model.isBuildingPreview)
        let latest = AVPlayerItem(asset: AVMutableComposition())
        pending[1].resume(returning: latest)
        try await waitUntil { !model.isBuildingPreview }
        XCTAssertTrue(model.player.currentItem === latest)
        XCTAssertTrue(model.isPreviewingComposedResult)
    }

    @MainActor
    func testCancelledExportCannotChangeNextExportOrItsCancellation() async throws {
        var pending: [CheckedContinuation<ExportResult, Error>] = []
        var progressCallbacks: [@Sendable (Double) -> Void] = []
        let model = EditorViewModel(exportOperation: { _, _, _, progress in
            progressCallbacks.append(progress)
            return try await withCheckedThrowingContinuation { pending.append($0) }
        })
        model.clips = [makeClip()]
        let destination = tempDir.appendingPathComponent("new.mp4")
        model.startExport(to: destination)
        try await waitUntil { pending.count == 1 }
        model.cancelExport()
        model.startExport(to: destination)
        try await waitUntil { pending.count == 2 }
        progressCallbacks[1](0.4)
        try await waitUntil { model.exportProgress == 0.4 }
        pending[0].resume(throwing: NSError(domain: "OldExport", code: 1))
        progressCallbacks[0](0.9)
        await drainMainActor()
        XCTAssertTrue(model.isExporting)
        XCTAssertEqual(model.exportProgress, 0.4)
        XCTAssertNil(model.errorMessage)
        model.cancelExport()
        pending[1].resume(returning: ExportResult(outputURL: destination, fileSizeBytes: 123, usedPassthrough: false))
        await drainMainActor()
        XCTAssertFalse(model.isExporting)
        XCTAssertNil(model.lastExportResult)
        XCTAssertEqual(model.exportProgress, 0)
    }

    private func makeClip(duration: Double = 5, hasAudio: Bool = false, size: CGSize = CGSize(width: 320, height: 180)) -> VideoClip {
        VideoClip(url: URL(fileURLWithPath: "/tmp/test-clip.mov"), fileName: "test-clip.mov",
                  fileSizeBytes: 1_000_000, duration: CMTime(seconds: duration, preferredTimescale: 600),
                  naturalSize: size, preferredTransform: .identity,
                  displaySize: size, nominalFrameRate: 30,
                  hasAudio: hasAudio, estimatedDataRate: 1_000_000)
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for the asynchronous operation.", file: file, line: line)
                throw NSError(domain: "AsyncTestTimeout", code: 1)
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    @MainActor
    private func drainMainActor() async {
        // Let resumed operations and their queued progress callbacks finish.
        for _ in 0..<10 { await Task.yield() }
    }

    @MainActor
    func testRemovingAudioOmitsTracksInPassthroughAndTranscodedExports() async throws {
        let source = tempDir.appendingPathComponent("with-audio.mov")
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: source, naturalSize: CGSize(width: 320, height: 180), durationSeconds: 1.5,
            fps: 30, preferredTransform: CGAffineTransform(rotationAngle: .pi / 2), includeAudio: true
        )
        var clip = try await VideoInspector.loadClip(from: source, thumbnailCount: 1)
        clip.trimStart = 0.2
        clip.trimEnd = 1.2
        for mode in [CompressionMode.passthrough, .preset] {
            var settings = ExportSettings()
            settings.compressionMode = mode
            settings.removeAudio = true
            let built = try await CompositionBuilder.build(clips: [clip, clip], settings: settings)
            XCTAssertFalse(built.hasAudio)
            XCTAssertTrue(built.composition.tracks(withMediaType: .audio).isEmpty)
            let output = tempDir.appendingPathComponent("silent-\(mode == .passthrough ? "copy" : "encoded").mp4")
            let result = try await VideoExporter.export(clips: [clip], settings: settings, to: output) { _ in }
            XCTAssertEqual(result.usedPassthrough, mode == .passthrough)
            let asset = AVURLAsset(url: output)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            let video = try await asset.loadTracks(withMediaType: .video)
            XCTAssertTrue(audio.isEmpty, "Mute must remove the track, not just silence samples.")
            XCTAssertEqual(video.count, 1)
            let inspected = try await VideoInspector.loadClip(from: output, thumbnailCount: 1)
            XCTAssertGreaterThan(inspected.displaySize.height, inspected.displaySize.width)
            XCTAssertEqual(inspected.durationSeconds, 1, accuracy: 0.15)
        }
    }

    func testMutedOutputUsesAudioFreeSizeBudget() throws {
        let clip = makeClip(duration: 600, hasAudio: true)
        var settings = ExportSettings()
        settings.compressionMode = .targetSize
        settings.targetSizeMB = 15
        XCTAssertThrowsError(try settings.validateTargetSize(for: [clip]))
        settings.removeAudio = true
        XCTAssertFalse(settings.includesAudio(for: [clip]))
        XCTAssertNoThrow(try settings.validateTargetSize(for: [clip]))
        let bitrate = settings.resolvedVideoBitrate(outputSize: clip.displaySize, fps: 30,
                                                    totalDuration: 600, hasAudio: true)
        XCTAssertEqual(bitrate, 188_000)
        XCTAssertEqual(Double(settings.estimatedOutputBytes(for: [clip])), 15_000_000, accuracy: 100)
    }

    @MainActor
    func testCropIsDraftUntilAppliedAndOnlyChangesSelectedClip() async throws {
        let model = EditorViewModel(previewBuilder: { _, _ in AVPlayerItem(asset: AVMutableComposition()) })
        let first = makeClip()
        let second = makeClip()
        model.clips = [first, second]
        model.selectedClipID = first.id
        model.beginCropEditing()
        model.setAspectRatio(.ratio9x16)
        let draft = try XCTUnwrap(model.cropDraft)
        XCTAssertTrue(model.isEditingCrop)
        XCTAssertEqual(model.clips[0].cropRect, first.cropRect)
        model.startExport(to: tempDir.appendingPathComponent("unfinished.mp4"))
        XCTAssertFalse(model.isExporting)
        model.applyCrop()
        try await waitUntil { !model.isBuildingPreview }
        XCTAssertFalse(model.isEditingCrop)
        XCTAssertEqual(model.clips[0].cropRect, draft)
        XCTAssertEqual(model.clips[0].cropAspectRatio, .ratio9x16)
        XCTAssertEqual(model.clips[1].cropRect, second.cropRect)
        XCTAssertTrue(model.isPreviewingComposedResult)

        model.selectClip(second.id)
        model.beginCropEditing()
        model.updateSelectedCropRect(CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
        model.cancelCropEditing()
        XCTAssertEqual(model.clips[1].cropRect, second.cropRect)
        model.selectClip(first.id)
        model.beginCropEditing()
        XCTAssertEqual(model.cropDraft, draft)
        XCTAssertEqual(model.cropDraftAspectRatio, .ratio9x16)
        model.selectClip(second.id)
        XCTAssertFalse(model.isEditingCrop)
        model.selectClip(first.id)
        model.removeSelectedCrop()
        XCTAssertFalse(model.clips[0].isCropped)
        XCTAssertEqual(model.clips[0].cropAspectRatio, .original)
    }

    @MainActor
    func testCustomCropCanBeAppliedToAllClipsAndReusedWithoutDraft() async throws {
        let model = EditorViewModel(previewBuilder: { _, _ in AVPlayerItem(asset: AVMutableComposition()) })
        model.clips = [makeClip(), makeClip(size: CGSize(width: 180, height: 320))]
        model.selectedClipID = model.clips[0].id
        model.setAspectRatio(.custom) // The always-visible picker starts editing directly.
        let rect = CGRect(x: 0.1, y: 0.2, width: 0.6, height: 0.5)
        model.updateSelectedCropRect(rect)
        model.applyCrop(toAllClips: true)
        try await waitUntil { !model.isBuildingPreview }
        XCTAssertFalse(model.isEditingCrop)
        XCTAssertTrue(model.clips.allSatisfy { $0.cropRect == rect && $0.cropAspectRatio == .custom })
        model.clips[1].cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        model.applyCrop(toAllClips: true)
        try await waitUntil { !model.isBuildingPreview }
        XCTAssertEqual(model.clips[1].cropRect, rect)
        model.setAspectRatio(.original)
        model.applyCrop(toAllClips: true)
        try await waitUntil { !model.isBuildingPreview }
        XCTAssertTrue(model.clips.allSatisfy { !$0.isCropped && $0.cropAspectRatio == .original })
    }

    @MainActor
    func testBatchPresetPreservesAspectZoomAndPositionAcrossOrientations() async throws {
        let model = EditorViewModel(previewBuilder: { _, _ in AVPlayerItem(asset: AVMutableComposition()) })
        model.clips = [makeClip(), makeClip(size: CGSize(width: 180, height: 320))]
        model.selectedClipID = model.clips[0].id
        model.setAspectRatio(.ratio1x1)
        let rect = CGRect(x: 0.4, y: 0.2, width: 0.28125, height: 0.5)
        model.updateSelectedCropRect(rect)
        model.applyCrop(toAllClips: true)
        try await waitUntil { !model.isBuildingPreview }
        XCTAssertEqual(model.clips[0].cropRect, rect)
        for clip in model.clips {
            let crop = clip.cropRect
            XCTAssertEqual(clip.croppedDisplaySize.width / clip.croppedDisplaySize.height, 1, accuracy: 0.001)
            XCTAssertEqual(crop.midX, rect.midX, accuracy: 0.001)
            XCTAssertEqual(crop.midY, rect.midY, accuracy: 0.001)
            let fit = AspectRatioPreset.ratio1x1.centeredNormalizedCrop(for: clip.displaySize)
            XCTAssertEqual(crop.width / fit.width, 0.5, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(crop.minX, 0)
            XCTAssertLessThanOrEqual(crop.maxX, 1)
        }
    }

    @MainActor
    func testRemoveAudioMutesSourceAndRebuildsResultPreview() async throws {
        var receivedSettings: [ExportSettings] = []
        let model = EditorViewModel(previewBuilder: { _, settings in
            receivedSettings.append(settings)
            return AVPlayerItem(asset: AVMutableComposition())
        })
        model.clips = [makeClip(hasAudio: true)]
        model.selectedClipID = model.clips[0].id
        model.setComposedPreviewEnabled(true)
        try await waitUntil { !model.isBuildingPreview }
        model.setRemoveAudio(true)
        XCTAssertTrue(model.player.isMuted)
        try await waitUntil { !model.isBuildingPreview }
        XCTAssertEqual(receivedSettings.map(\.removeAudio), [false, true])
        model.clearAll()
        XCTAssertFalse(model.player.isMuted)
        XCTAssertFalse(model.settings.removeAudio)
    }

    @MainActor
    func testSeparateExportCreatesIndividualFilesWithPerClipEdits() async throws {
        let source = tempDir.appendingPathComponent("source.mov")
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: source, naturalSize: CGSize(width: 320, height: 180), durationSeconds: 1.2,
            fps: 30, preferredTransform: .identity, includeAudio: true
        )
        let first = try await VideoInspector.loadClip(from: source, thumbnailCount: 1)
        var second = try await VideoInspector.loadClip(from: source, thumbnailCount: 1)
        second.trimStart = 0.2
        second.trimEnd = 0.8
        second.cropRect = AspectRatioPreset.ratio1x1.centeredNormalizedCrop(for: second.displaySize)
        let model = EditorViewModel()
        model.clips = [first, second]
        model.exportMode = .separate
        model.settings.removeAudio = true
        model.startSeparateExport(in: tempDir)
        try await waitUntil { !model.isExporting }
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.lastExportResults.count, 2)
        XCTAssertEqual(model.exportProgress, 1)
        let folder = try XCTUnwrap(model.lastExportDirectory)
        XCTAssertEqual(folder.deletingLastPathComponent(), tempDir)
        XCTAssertEqual(model.lastExportResults.map { $0.outputURL.lastPathComponent }, ["001_source.mp4", "002_source.mp4"])
        let outputs = model.lastExportResults
        guard outputs.count == 2 else { return }
        for result in outputs {
            let asset = AVURLAsset(url: result.outputURL)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            XCTAssertTrue(audio.isEmpty)
        }
        let firstOutput = try await VideoInspector.loadClip(from: outputs[0].outputURL, thumbnailCount: 1)
        let secondOutput = try await VideoInspector.loadClip(from: outputs[1].outputURL, thumbnailCount: 1)
        XCTAssertEqual(firstOutput.durationSeconds, 1.2, accuracy: 0.1)
        XCTAssertEqual(secondOutput.durationSeconds, 0.6, accuracy: 0.1)
        XCTAssertEqual(firstOutput.displaySize.width, 320, accuracy: 1)
        XCTAssertEqual(secondOutput.displaySize.width, secondOutput.displaySize.height, accuracy: 1)
        model.startSeparateExport(in: tempDir)
        try await waitUntil { !model.isExporting }
        XCTAssertNotEqual(model.lastExportDirectory, folder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputs[0].outputURL.path))
    }

    @MainActor
    func testLosslessEligibilitySupportsIndividualBatchFiles() {
        let model = EditorViewModel()
        model.clips = [makeClip(), makeClip()]
        XCTAssertFalse(model.isPassthroughEligible)
        model.exportMode = .separate
        XCTAssertTrue(model.isPassthroughEligible)
        model.clips[1].cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        XCTAssertFalse(model.isPassthroughEligible)
    }

    @MainActor
    func testSeparateTargetBudgetAndEstimateApplyPerClip() throws {
        let model = EditorViewModel()
        model.clips = [makeClip(duration: 400), makeClip(duration: 400)]
        model.settings.compressionMode = .targetSize
        model.settings.targetSizeMB = 10
        XCTAssertThrowsError(try model.validateCurrentExportSettings())
        model.exportMode = .separate
        XCTAssertNoThrow(try model.validateCurrentExportSettings())
        XCTAssertEqual(Double(model.estimatedOutputBytes), 20_000_000, accuracy: 100)
    }

    @MainActor
    func testCancellingBatchPreservesCompletedFilesAndStopsRemainingJobs() async throws {
        var pending: CheckedContinuation<ExportResult, Error>?
        var started = 0
        let model = EditorViewModel(exportOperation: { _, _, url, progress in
            started += 1
            if started == 1 {
                progress(1)
                return ExportResult(outputURL: url, fileSizeBytes: 42, usedPassthrough: true)
            }
            return try await withCheckedThrowingContinuation { pending = $0 }
        })
        model.clips = [makeClip(), makeClip(), makeClip()]
        model.startSeparateExport(in: tempDir)
        try await waitUntil { pending != nil }
        XCTAssertEqual(model.lastExportResults.count, 1)
        model.cancelExport()
        pending?.resume(throwing: CancellationError())
        await drainMainActor()
        XCTAssertEqual(started, 2)
        XCTAssertEqual(model.lastExportResults.count, 1)
        XCTAssertFalse(model.isExporting)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testPreferencesPersistAndEnglishResourcesAreAvailable() throws {
        let suite = "LocalioBCTestPreferences-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertEqual(preferences.language, .system)
        preferences.appearance = .dark
        preferences.language = .english
        let restored = AppPreferences(defaults: defaults)
        XCTAssertEqual(restored.appearance, .dark)
        XCTAssertEqual(restored.language, .english)
        XCTAssertEqual(localized("Ořez", language: .english), "Crop")
        XCTAssertEqual(localized("Exportovat klipy…", language: .english), "Export clips…")
        XCTAssertEqual(localized("Ořez", language: .czech), "Ořez")
    }

    func testAutomaticLanguageUsesCzechOnlyForCzechSystemLanguage() {
        for language in ["cs", "cs-CZ", "cs_CZ", "CS-cz"] {
            XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: [language]), "cs", language)
        }
        for language in ["en-US", "de-DE", "sk-SK", "fr-FR", "ja-JP"] {
            XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: [language, "cs-CZ"]), "en", language)
        }
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: []), "en")
        XCTAssertEqual(AppLanguage.czech.resolvedCode(preferredLanguages: ["en-US"]), "cs")
        XCTAssertEqual(AppLanguage.english.resolvedCode(preferredLanguages: ["cs-CZ"]), "en")
    }

    @MainActor
    func testPassthroughTrimAndTargetSizeCompression() async throws {
        let sourceURL = tempDir.appendingPathComponent("source.mp4")
        try await TestMediaFactory.writeFourQuadrantVideo(
            to: sourceURL,
            naturalSize: CGSize(width: 640, height: 360),
            durationSeconds: 2.4,
            fps: 30,
            preferredTransform: .identity,
            includeAudio: true
        )

        var clip = try await VideoInspector.loadClip(from: sourceURL, thumbnailCount: 4)
        clip.trimStart = 0.4
        clip.trimEnd = 1.8 // 1.4s

        var passthroughSettings = ExportSettings()
        passthroughSettings.compressionMode = .passthrough
        passthroughSettings.container = .mp4

        let passthroughURL = tempDir.appendingPathComponent("trimmed_passthrough.mp4")
        let ptResult = try await VideoExporter.export(
            clips: [clip],
            settings: passthroughSettings,
            to: passthroughURL
        ) { _ in }

        XCTAssertTrue(ptResult.usedPassthrough)
        let ptDuration = try await AVURLAsset(url: passthroughURL).load(.duration).seconds
        XCTAssertEqual(ptDuration, 1.4, accuracy: 0.45)

        var targetSettings = ExportSettings()
        targetSettings.compressionMode = .targetSize
        targetSettings.targetSizeMB = 1.0
        targetSettings.codec = .hevc
        targetSettings.container = .mp4

        let compressedURL = tempDir.appendingPathComponent("compressed_target.mp4")
        let compResult = try await VideoExporter.export(
            clips: [clip],
            settings: targetSettings,
            to: compressedURL
        ) { _ in }

        XCTAssertFalse(compResult.usedPassthrough)
        XCTAssertGreaterThan(compResult.fileSizeBytes, 5_000)
        XCTAssertLessThan(compResult.fileSizeBytes, 1_300_000)
    }
}

private enum TestMediaFactory {
    struct RGB {
        let r: UInt8
        let g: UInt8
        let b: UInt8
    }

    static func writeFourQuadrantVideo(
        to url: URL,
        naturalSize: CGSize,
        durationSeconds: Double,
        fps: Int32,
        preferredTransform: CGAffineTransform,
        includeAudio: Bool
    ) async throws {
        let fileType: AVFileType = url.pathExtension.lowercased() == "mov" ? .mov : .mp4
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(naturalSize.width),
            AVVideoHeightKey: Int(naturalSize.height)
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = preferredTransform
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(naturalSize.width),
                kCVPixelBufferHeightKey as String: Int(naturalSize.height)
            ]
        )
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ]
            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aIn.expectsMediaDataInRealTime = false
            writer.add(aIn)
            audioInput = aIn
        }

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "TestMediaFactory", code: 4)
        }
        defer {
            if writer.status == .writing { writer.cancelWriting() }
        }
        writer.startSession(atSourceTime: .zero)

        let totalFrames = max(2, Int((durationSeconds * Double(fps)).rounded()))
        let frameDuration = CMTime(value: 1, timescale: fps)
        let sampleRate = 48_000
        let chunkSamples = 1024
        let totalSamples = audioInput == nil ? 0 : Int(durationSeconds * Double(sampleRate))

        var frameIndex = 0
        var audioOffset = 0
        var videoFinished = false
        var audioFinished = audioInput == nil
        let deadline = ContinuousClock.now + .seconds(15)

        while !videoFinished || !audioFinished {
            try Task.checkCancellation()
            guard writer.status == .writing else {
                throw writer.error ?? NSError(domain: "TestMediaFactory", code: 5)
            }
            guard ContinuousClock.now < deadline else {
                throw NSError(domain: "TestMediaFactory", code: 6,
                              userInfo: [NSLocalizedDescriptionKey: "Časový limit při generování testovacího videa."])
            }
            var madeProgress = false
            if !videoFinished, videoInput.isReadyForMoreMediaData {
                let pixelBuffer = try makeFourQuadrantPixelBuffer(size: naturalSize, frameIndex: frameIndex)
                let pts = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
                guard adaptor.append(pixelBuffer, withPresentationTime: pts) else {
                    throw writer.error ?? NSError(domain: "TestMediaFactory", code: 7)
                }
                frameIndex += 1
                madeProgress = true
                if frameIndex == totalFrames {
                    videoInput.markAsFinished()
                    videoFinished = true
                }
            }
            if !audioFinished, let audioInput, audioInput.isReadyForMoreMediaData {
                let count = min(chunkSamples, totalSamples - audioOffset)
                guard let sampleBuf = makeSilentAudioSampleBuffer(sampleCount: count, startSample: audioOffset, sampleRate: sampleRate),
                      audioInput.append(sampleBuf) else {
                    throw writer.error ?? NSError(domain: "TestMediaFactory", code: 8)
                }
                audioOffset += count
                madeProgress = true
                if audioOffset == totalSamples {
                    audioInput.markAsFinished()
                    audioFinished = true
                }
            }
            if !madeProgress {
                try await Task.sleep(for: .milliseconds(2))
            }
        }

        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? NSError(domain: "TestMediaFactory", code: 1)
        }
    }

    private static func makeFourQuadrantPixelBuffer(size: CGSize, frameIndex: Int) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pb
        )
        guard let pixelBuffer = pb else {
            throw NSError(domain: "TestMediaFactory", code: 2)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let base = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        if let ctx = CGContext(
            data: base,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) {
            let halfW = size.width / 2.0
            let halfH = size.height / 2.0

            // CGContext má počátek (0,0) vlevo dole:
            // Horní levý kvadrant (y >= halfH) -> Červená
            ctx.setFillColor(CGColor(red: 0.95, green: 0.05, blue: 0.05, alpha: 1))
            ctx.fill(CGRect(x: 0, y: halfH, width: halfW, height: halfH))

            // Horní pravý kvadrant -> Zelená
            ctx.setFillColor(CGColor(red: 0.05, green: 0.95, blue: 0.05, alpha: 1))
            ctx.fill(CGRect(x: halfW, y: halfH, width: halfW, height: halfH))

            // Dolní levý kvadrant -> Modrá
            ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.95, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: halfW, height: halfH))

            // Dolní pravý kvadrant -> Žlutá
            ctx.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.05, alpha: 1))
            ctx.fill(CGRect(x: halfW, y: 0, width: halfW, height: halfH))

            // Malý pohybující se bílý proužek zcela uprostřed (aby enkodér neoptimalizoval staticky a nenarušil rohy)
            let barX = CGFloat((frameIndex * 7) % max(1, Int(size.width / 8)))
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
            ctx.fill(CGRect(x: halfW - 4 + barX * 0.05, y: halfH - 4, width: 8, height: 8))
        }
        return pixelBuffer
    }

    private static func makeSilentAudioSampleBuffer(
        sampleCount: Int,
        startSample: Int,
        sampleRate: Int
    ) -> CMSampleBuffer? {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var formatDesc: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )
        guard let formatDesc else { return nil }

        let byteCount = sampleCount * 4
        var blockBuffer: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: byteCount,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard let blockBuffer else { return nil }
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: byteCount)

        var sampleBuffer: CMSampleBuffer?
        let pts = CMTime(value: CMTimeValue(startSample), timescale: CMTimeScale(sampleRate))
        CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleCount: sampleCount,
            presentationTimeStamp: pts,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        return sampleBuffer
    }

    static func sampleCenterRGB(of url: URL) async throws -> RGB {
        try await sampleNormalizedRGB(of: url, normalizedPoint: CGPoint(x: 0.5, y: 0.5))
    }

    static func sampleNormalizedRGB(of url: URL, normalizedPoint: CGPoint) async throws -> RGB {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let (cgImage, _) = try await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600))
        let width = cgImage.width
        let height = cgImage.height

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "TestMediaFactory", code: 3)
        }

        // CGContext kreslí odspodu; pro test souřadnic (0,0 = vlevo nahoře) obrátíme jen index čtení
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let px = max(0, min(width - 1, Int((normalizedPoint.x * CGFloat(width)).rounded())))
        // V paměti CGContextu (po draw) je řádek 0 horní okraj obrázku
        let py = max(0, min(height - 1, Int((normalizedPoint.y * CGFloat(height)).rounded())))
        let offset = (py * width + px) * 4
        return RGB(r: rgba[offset], g: rgba[offset + 1], b: rgba[offset + 2])
    }
}
