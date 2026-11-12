import AVFoundation
import CoreVideo
import Foundation

enum VideoExporterError: LocalizedError {
    case cancelled
    case cannotCreateExportSession
    case readerFailed(String)
    case writerFailed(String)
    case failedToMoveOutput(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return tr("Export videa byl zrušen.")
        case .cannotCreateExportSession:
            return tr("Nepodařilo se inicializovat exportní relaci.")
        case .readerFailed(let reason):
            return tr("Chyba při čtení zdrojového videa: %@", reason)
        case .writerFailed(let reason):
            return tr("Chyba při ukládání výsledného videa: %@", reason)
        case .failedToMoveOutput(let reason):
            return tr("Nepodařilo se uložit výstupní soubor: %@", reason)
        }
    }
}

struct ExportResult: Sendable {
    let outputURL: URL
    let fileSizeBytes: Int64
    let usedPassthrough: Bool
}

enum VideoExporter {
    /// Exportuje upravené klipy na zvolené URL a průběžně hlásí postup (0.0 ... 1.0).
    static func export(
        clips: [VideoClip],
        settings: ExportSettings,
        to destinationURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> ExportResult {
        try Task.checkCancellation()
        try settings.validateTargetSize(for: clips)
        onProgress(0.0)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalioBC-\(UUID().uuidString)")
            .appendingPathExtension(settings.container.fileExtension)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        var usedPassthrough = false

        if settings.canUsePassthrough(for: clips), let clip = clips.first {
            let source = AVURLAsset(url: clip.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let asset: AVAsset
            if settings.removeAudio {
                let composition = AVMutableComposition()
                let sourceTracks = try await source.loadTracks(withMediaType: .video)
                guard let sourceTrack = sourceTracks.first,
                      let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw CompositionBuilderError.missingVideoTrack(clip.fileName)
                }
                let range = try await sourceTrack.load(.timeRange)
                track.preferredTransform = try await sourceTrack.load(.preferredTransform)
                try track.insertTimeRange(range, of: sourceTrack, at: range.start)
                asset = composition
            } else {
                asset = source
            }
            let compatible = await isPassthroughCompatible(
                asset: asset,
                outputFileType: settings.container.avFileType
            )
            if compatible {
                try await exportPassthrough(
                    asset: asset,
                    clip: clip,
                    outputFileType: settings.container.avFileType,
                    tempURL: tempURL,
                    onProgress: onProgress
                )
                usedPassthrough = true
            } else {
                try await exportTranscoded(
                    clips: clips,
                    settings: settings,
                    tempURL: tempURL,
                    onProgress: onProgress
                )
            }
        } else {
            try await exportTranscoded(
                clips: clips,
                settings: settings,
                tempURL: tempURL,
                onProgress: onProgress
            )
        }

        try Task.checkCancellation()
        try moveReplacingDestination(from: tempURL, to: destinationURL)
        onProgress(1.0)

        let size = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        return ExportResult(outputURL: destinationURL, fileSizeBytes: size, usedPassthrough: usedPassthrough)
    }

    private static func exportPassthrough(
        asset: AVAsset,
        clip: VideoClip,
        outputFileType: AVFileType,
        tempURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw VideoExporterError.cannotCreateExportSession
        }

        let start = CMTime(seconds: max(0, clip.trimStart), preferredTimescale: 600)
        let end = CMTime(seconds: min(clip.durationSeconds, clip.trimEnd), preferredTimescale: 600)
        if clip.isTrimmed && CMTimeCompare(end, start) > 0 {
            session.timeRange = CMTimeRange(start: start, end: end)
        }
        session.shouldOptimizeForNetworkUse = true

        let box = UncheckedExportSessionBox(session)

        if #available(macOS 15.0, *) {
            let progressTask = Task {
                for await state in box.session.states(updateInterval: 0.08) {
                    if Task.isCancelled { break }
                    if case .exporting(let progress) = state {
                        onProgress(min(0.99, progress.fractionCompleted))
                    }
                }
            }
            defer { progressTask.cancel() }

            do {
                try await withTaskCancellationHandler {
                    try await box.session.export(to: tempURL, as: outputFileType)
                } onCancel: {
                    box.session.cancelExport()
                }
            } catch is CancellationError {
                throw VideoExporterError.cancelled
            } catch {
                if Task.isCancelled {
                    throw VideoExporterError.cancelled
                }
                throw VideoExporterError.writerFailed(error.localizedDescription)
            }
        } else {
            try await exportSessionLegacy(
                box: box,
                tempURL: tempURL,
                outputFileType: outputFileType,
                onProgress: onProgress
            )
        }
    }

    private static func isPassthroughCompatible(asset: AVAsset, outputFileType: AVFileType) async -> Bool {
        await withCheckedContinuation { continuation in
            AVAssetExportSession.determineCompatibility(
                ofExportPreset: AVAssetExportPresetPassthrough,
                with: asset,
                outputFileType: outputFileType
            ) { isCompatible in
                continuation.resume(returning: isCompatible)
            }
        }
    }

    @available(macOS, deprecated: 15.0)
    private static func exportSessionLegacy(
        box: UncheckedExportSessionBox,
        tempURL: URL,
        outputFileType: AVFileType,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        box.session.outputURL = tempURL
        box.session.outputFileType = outputFileType

        let poller = Task {
            while !Task.isCancelled {
                onProgress(Double(min(0.99, box.session.progress)))
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { poller.cancel() }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                box.session.exportAsynchronously {
                    switch box.session.status {
                    case .completed:
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: VideoExporterError.cancelled)
                    default:
                        let msg = box.session.error?.localizedDescription ?? tr("Neznámá chyba exportu")
                        continuation.resume(throwing: VideoExporterError.writerFailed(msg))
                    }
                }
            }
        } onCancel: {
            box.session.cancelExport()
        }
    }

    private static func exportTranscoded(
        clips: [VideoClip],
        settings: ExportSettings,
        tempURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let built = try await CompositionBuilder.build(clips: clips, settings: settings)
        try Task.checkCancellation()

        let videoBitrate = settings.resolvedVideoBitrate(
            outputSize: built.renderSize,
            fps: built.targetFPS,
            totalDuration: built.totalDuration,
            hasAudio: built.hasAudio
        )
        let audioBitrate = settings.resolvedAudioBitrate(totalDuration: built.totalDuration)

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: built.composition)
        } catch {
            throw VideoExporterError.readerFailed(error.localizedDescription)
        }

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: tempURL, fileType: settings.container.avFileType)
        } catch {
            throw VideoExporterError.writerFailed(error.localizedDescription)
        }
        writer.shouldOptimizeForNetworkUse = true

        let compVideoTracks = built.composition.tracks(withMediaType: .video)
        let videoOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: compVideoTracks,
            videoSettings: videoOutputSettings
        )
        videoOutput.videoComposition = built.videoComposition
        videoOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(videoOutput) else {
            throw VideoExporterError.readerFailed(tr("Nelze připojit obrazový výstup čtečky."))
        }
        reader.add(videoOutput)

        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: videoBitrate,
            AVVideoExpectedSourceFrameRateKey: built.targetFPS,
            AVVideoMaxKeyFrameIntervalKey: Int(max(15, built.targetFPS * 2))
        ]
        if settings.codec == .h264 {
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }

        let videoInputSettings: [String: Any] = [
            AVVideoCodecKey: settings.codec.avCodec,
            AVVideoWidthKey: Int(built.renderSize.width),
            AVVideoHeightKey: Int(built.renderSize.height),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        videoInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(videoInput) else {
            throw VideoExporterError.writerFailed(tr("Nepodporované nastavení video enkodéru."))
        }
        writer.add(videoInput)

        var audioOutput: AVAssetReaderAudioMixOutput?
        var audioInput: AVAssetWriterInput?

        let compAudioTracks = built.composition.tracks(withMediaType: .audio)
        if !compAudioTracks.isEmpty {
            let pcmSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let aOut = AVAssetReaderAudioMixOutput(audioTracks: compAudioTracks, audioSettings: pcmSettings)
            aOut.alwaysCopiesSampleData = false

            let aacSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: audioBitrate
            ]
            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: aacSettings)
            aIn.expectsMediaDataInRealTime = false

            if reader.canAdd(aOut) && writer.canAdd(aIn) {
                reader.add(aOut)
                writer.add(aIn)
                audioOutput = aOut
                audioInput = aIn
            }
        }

        let pump = ReaderWriterPump(
            reader: reader,
            writer: writer,
            videoOutput: videoOutput,
            videoInput: videoInput,
            audioOutput: audioOutput,
            audioInput: audioInput,
            totalDuration: built.totalDuration,
            onProgress: onProgress
        )

        try await withTaskCancellationHandler {
            try await pump.run()
        } onCancel: {
            pump.cancel()
        }
    }

    private static func moveReplacingDestination(from tempURL: URL, to destinationURL: URL) throws {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destinationURL.path) {
                _ = try fm.replaceItemAt(destinationURL, withItemAt: tempURL)
            } else {
                try fm.moveItem(at: tempURL, to: destinationURL)
            }
        } catch {
            throw VideoExporterError.failedToMoveOutput(error.localizedDescription)
        }
    }
}

private final class UncheckedExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

private final class ReaderWriterPump: @unchecked Sendable {
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let videoOutput: AVAssetReaderOutput
    private let videoInput: AVAssetWriterInput
    private let audioOutput: AVAssetReaderOutput?
    private let audioInput: AVAssetWriterInput?
    private let totalDuration: Double
    private let onProgress: @Sendable (Double) -> Void

    private let videoQueue = DispatchQueue(label: "com.localiobvideo.export.video")
    private let audioQueue = DispatchQueue(label: "com.localiobvideo.export.audio")
    private let stateLock = NSLock()

    private var isCancelled = false
    private var videoFinished = false
    private var audioFinished = false
    private var capturedError: Error?
    private var continuation: CheckedContinuation<Void, Error>?
    private var didResume = false
    private var lastReportedProgress: Double = -1

    init(
        reader: AVAssetReader,
        writer: AVAssetWriter,
        videoOutput: AVAssetReaderOutput,
        videoInput: AVAssetWriterInput,
        audioOutput: AVAssetReaderOutput?,
        audioInput: AVAssetWriterInput?,
        totalDuration: Double,
        onProgress: @escaping @Sendable (Double) -> Void
    ) {
        self.reader = reader
        self.writer = writer
        self.videoOutput = videoOutput
        self.videoInput = videoInput
        self.audioOutput = audioOutput
        self.audioInput = audioInput
        self.totalDuration = max(0.05, totalDuration)
        self.onProgress = onProgress
        self.audioFinished = (audioInput == nil)
    }

    func run() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            stateLock.lock()
            if isCancelled {
                stateLock.unlock()
                cont.resume(throwing: VideoExporterError.cancelled)
                return
            }
            self.continuation = cont
            stateLock.unlock()

            guard writer.startWriting() else {
                let message = writer.error?.localizedDescription ?? tr("Nelze spustit zápis.")
                failAndResume(with: VideoExporterError.writerFailed(message))
                return
            }

            guard reader.startReading() else {
                writer.cancelWriting()
                let message = reader.error?.localizedDescription ?? tr("Nelze spustit čtení.")
                failAndResume(with: VideoExporterError.readerFailed(message))
                return
            }

            writer.startSession(atSourceTime: .zero)

            let group = DispatchGroup()

            group.enter()
            videoInput.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
                guard let self else { return }
                self.pumpVideo(group: group)
            }

            if audioOutput != nil, let audioInput {
                group.enter()
                audioInput.requestMediaDataWhenReady(on: audioQueue) { [weak self] in
                    guard let self, let output = self.audioOutput, let input = self.audioInput else { return }
                    self.pumpAudio(output: output, input: input, group: group)
                }
            }

            group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
                self?.completeExport()
            }
        }
    }

    func cancel() {
        stateLock.lock()
        let alreadyCancelled = isCancelled
        isCancelled = true
        stateLock.unlock()

        if !alreadyCancelled {
            reader.cancelReading()
            writer.cancelWriting()
        }
    }

    private func pumpVideo(group: DispatchGroup) {
        while videoInput.isReadyForMoreMediaData {
            if shouldStop() {
                finishVideoInput(group: group)
                return
            }

            if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                if pts.isFinite {
                    let fraction = max(0, min(0.99, pts / totalDuration))
                    reportProgressIfNeeded(fraction)
                }

                if !videoInput.append(sampleBuffer) {
                    let err = writer.error.map { VideoExporterError.writerFailed($0.localizedDescription) }
                        ?? VideoExporterError.writerFailed(tr("Zápis video snímku selhal."))
                    recordErrorAndAbort(err)
                    finishVideoInput(group: group)
                    return
                }
            } else {
                if reader.status == .failed {
                    let err = reader.error.map { VideoExporterError.readerFailed($0.localizedDescription) }
                        ?? VideoExporterError.readerFailed(tr("Čtení video snímku selhalo."))
                    recordErrorAndAbort(err)
                }
                finishVideoInput(group: group)
                return
            }
        }
    }

    private func pumpAudio(output: AVAssetReaderOutput, input: AVAssetWriterInput, group: DispatchGroup) {
        while input.isReadyForMoreMediaData {
            if shouldStop() {
                finishAudioInput(input: input, group: group)
                return
            }

            if let sampleBuffer = output.copyNextSampleBuffer() {
                if !input.append(sampleBuffer) {
                    let err = writer.error.map { VideoExporterError.writerFailed($0.localizedDescription) }
                        ?? VideoExporterError.writerFailed(tr("Zápis audio vzorku selhal."))
                    recordErrorAndAbort(err)
                    finishAudioInput(input: input, group: group)
                    return
                }
            } else {
                if reader.status == .failed {
                    let err = reader.error.map { VideoExporterError.readerFailed($0.localizedDescription) }
                        ?? VideoExporterError.readerFailed(tr("Čtení audio stopy selhalo."))
                    recordErrorAndAbort(err)
                }
                finishAudioInput(input: input, group: group)
                return
            }
        }
    }

    private func finishVideoInput(group: DispatchGroup) {
        stateLock.lock()
        let already = videoFinished
        videoFinished = true
        stateLock.unlock()

        if !already {
            videoInput.markAsFinished()
            group.leave()
        }
    }

    private func finishAudioInput(input: AVAssetWriterInput, group: DispatchGroup) {
        stateLock.lock()
        let already = audioFinished
        audioFinished = true
        stateLock.unlock()

        if !already {
            input.markAsFinished()
            group.leave()
        }
    }

    private func shouldStop() -> Bool {
        stateLock.lock()
        let stop = isCancelled || capturedError != nil
        stateLock.unlock()
        return stop
    }

    private func recordErrorAndAbort(_ error: Error) {
        stateLock.lock()
        if capturedError == nil {
            capturedError = error
        }
        stateLock.unlock()
        reader.cancelReading()
    }

    private func reportProgressIfNeeded(_ fraction: Double) {
        stateLock.lock()
        let shouldReport = (fraction - lastReportedProgress) >= 0.01 || fraction >= 0.99
        if shouldReport {
            lastReportedProgress = fraction
        }
        stateLock.unlock()

        if shouldReport {
            onProgress(fraction)
        }
    }

    private func completeExport() {
        stateLock.lock()
        let cancelled = isCancelled
        let err = capturedError
        stateLock.unlock()

        if cancelled {
            writer.cancelWriting()
            failAndResume(with: VideoExporterError.cancelled)
            return
        }

        if let err {
            writer.cancelWriting()
            failAndResume(with: err)
            return
        }

        writer.finishWriting { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            let nowCancelled = self.isCancelled
            self.stateLock.unlock()

            if nowCancelled {
                self.failAndResume(with: VideoExporterError.cancelled)
            } else if self.writer.status == .completed {
                self.succeedAndResume()
            } else {
                let message = self.writer.error?.localizedDescription ?? tr("Dokončení zápisu selhalo.")
                self.failAndResume(with: VideoExporterError.writerFailed(message))
            }
        }
    }

    private func succeedAndResume() {
        stateLock.lock()
        guard !didResume, let cont = continuation else {
            stateLock.unlock()
            return
        }
        didResume = true
        continuation = nil
        stateLock.unlock()
        cont.resume()
    }

    private func failAndResume(with error: Error) {
        stateLock.lock()
        guard !didResume, let cont = continuation else {
            stateLock.unlock()
            return
        }
        didResume = true
        continuation = nil
        stateLock.unlock()
        cont.resume(throwing: error)
    }
}
