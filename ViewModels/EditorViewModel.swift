import AppKit
import AVFoundation
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class EditorViewModel {
    var clips: [VideoClip] = []
    var selectedClipID: UUID?
    var settings = ExportSettings()
    var exportMode: ExportMode = .merged
    private(set) var cropDraft: CGRect?
    private(set) var cropDraftAspectRatio: AspectRatioPreset = .custom

    var isEditingCrop: Bool { cropDraft != nil }

    let player = AVPlayer()
    var isPlaying = false
    var currentTime: Double = 0

    var isPreviewingComposedResult = false
    var isBuildingPreview = false
    var isLoadingClips = false

    var isExporting = false
    var exportProgress: Double = 0
    var lastExportResult: ExportResult? {
        didSet {
            if lastExportResult == nil {
                lastExportResults = []
                lastExportDirectory = nil
            }
        }
    }
    var lastExportResults: [ExportResult] = []
    var lastExportDirectory: URL?
    var exportStatus = ""
    var errorMessage: String?

    @ObservationIgnored
    private nonisolated(unsafe) var timeObserver: Any?
    @ObservationIgnored
    private nonisolated(unsafe) var endObserver: NSObjectProtocol?
    @ObservationIgnored
    private var exportTask: Task<Void, Never>?
    @ObservationIgnored
    private var activePreviewURL: URL?

    typealias PreviewBuilder = @MainActor ([VideoClip], ExportSettings) async throws -> AVPlayerItem
    typealias ExportOperation = @MainActor ([VideoClip], ExportSettings, URL, @escaping @Sendable (Double) -> Void) async throws -> ExportResult

    @ObservationIgnored
    private let previewBuilder: PreviewBuilder
    @ObservationIgnored
    private let exportOperation: ExportOperation
    @ObservationIgnored
    private var previewTask: Task<Void, Never>?
    @ObservationIgnored
    private var previewGeneration = UUID()
    @ObservationIgnored
    private var exportID: UUID?

    init(
        previewBuilder: @escaping PreviewBuilder = { clips, settings in
            try await CompositionBuilder.buildPreviewPlayerItem(clips: clips, settings: settings)
        },
        exportOperation: @escaping ExportOperation = { clips, settings, url, progress in
            try await VideoExporter.export(clips: clips, settings: settings, to: url, onProgress: progress)
        }
    ) {
        self.previewBuilder = previewBuilder
        self.exportOperation = exportOperation
        setupTimeObserver()
    }

    deinit {
        if let token = timeObserver {
            player.removeTimeObserver(token)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    // MARK: - Computed Properties

    var selectedClipIndex: Int? {
        guard let selectedClipID else { return clips.isEmpty ? nil : 0 }
        return clips.firstIndex { $0.id == selectedClipID } ?? (clips.isEmpty ? nil : 0)
    }

    var selectedClip: VideoClip? {
        guard let index = selectedClipIndex, clips.indices.contains(index) else { return nil }
        return clips[index]
    }

    var totalSourceSizeBytes: Int64 {
        clips.reduce(0) { $0 + $1.fileSizeBytes }
    }

    var totalTrimmedDuration: Double {
        clips.reduce(0.0) { $0 + $1.trimmedDuration }
    }

    var estimatedOutputBytes: Int64 {
        exportMode == .separate
            ? clips.reduce(0) { $0 + settings.estimatedOutputBytes(for: [$1]) }
            : settings.estimatedOutputBytes(for: clips)
    }

    var outputResolution: CGSize {
        settings.resolveOutputSize(for: clips)
    }

    var isPassthroughEligible: Bool {
        !clips.isEmpty && (exportMode == .separate || clips.count == 1)
            && clips.allSatisfy { !$0.isCropped }
            && settings.resolutionLimit == .original
    }

    var activeTimelineDuration: Double {
        if isPreviewingComposedResult {
            return max(0.1, totalTrimmedDuration)
        }
        return selectedClip?.durationSeconds ?? 0.1
    }

    // MARK: - Importing Videos

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = tr("Vyberte videa k úpravě")
        panel.prompt = tr("Přidat")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie]

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                await addVideos(from: urls)
            }
        }
    }

    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        let validProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !validProviders.isEmpty else { return false }

        Task {
            var collectedURLs: [URL] = []
            for provider in validProviders {
                if let url = await Self.loadURL(from: provider) {
                    collectedURLs.append(url)
                }
            }
            let supported = collectedURLs.filter(Self.isSupportedVideoURL)
            if supported.isEmpty {
                errorMessage = tr("Podporovány jsou soubory MP4, MOV a M4V.")
            } else {
                await addVideos(from: supported)
            }
        }
        return true
    }

    private nonisolated static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private nonisolated static func isSupportedVideoURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "mp4" || ext == "mov" || ext == "m4v"
    }

    func addVideos(from urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isLoadingClips = true
        defer { isLoadingClips = false }

        var newlyAdded: [VideoClip] = []
        for url in urls {
            do {
                let clip = try await VideoInspector.loadClip(from: url)
                newlyAdded.append(clip)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        guard !newlyAdded.isEmpty else { return }
        let hadNoClips = clips.isEmpty
        clips.append(contentsOf: newlyAdded)

        if hadNoClips || selectedClipID == nil {
            selectedClipID = newlyAdded.first?.id
        }

        enforcePassthroughEligibility()
        if isPreviewingComposedResult {
            rebuildComposedPreview()
        } else if hadNoClips {
            loadSelectedClipIntoPlayer(forceReload: true)
        }
    }

    // MARK: - Clip Management

    func selectClip(_ id: UUID) {
        guard selectedClipID != id || isPreviewingComposedResult else { return }
        cancelCropEditing()
        selectedClipID = id
        invalidateComposedPreview()
        isPreviewingComposedResult = false
        loadSelectedClipIntoPlayer(forceReload: true)
    }

    func removeClip(_ id: UUID) {
        pause()
        let wasSelected = (selectedClipID == id)
        if wasSelected { cancelCropEditing() }
        clips.removeAll { $0.id == id }

        if clips.isEmpty {
            invalidateComposedPreview()
            selectedClipID = nil
            isPreviewingComposedResult = false
            activePreviewURL = nil
            player.replaceCurrentItem(with: nil)
            currentTime = 0
            lastExportResult = nil
            return
        }

        if wasSelected {
            selectedClipID = clips.first?.id
        }
        enforcePassthroughEligibility()

        if isPreviewingComposedResult {
            rebuildComposedPreview()
        } else if wasSelected {
            loadSelectedClipIntoPlayer(forceReload: true)
        }
    }

    func moveClip(from sourceIndex: Int, direction: Int) {
        let targetIndex = sourceIndex + direction
        guard clips.indices.contains(sourceIndex), clips.indices.contains(targetIndex) else { return }
        clips.swapAt(sourceIndex, targetIndex)
        if isPreviewingComposedResult {
            rebuildComposedPreview()
        }
    }

    func moveClip(id: UUID, before targetID: UUID) {
        guard id != targetID,
              let fromIndex = clips.firstIndex(where: { $0.id == id }),
              let toIndex = clips.firstIndex(where: { $0.id == targetID }) else {
            return
        }
        let item = clips.remove(at: fromIndex)
        let adjustedTarget = fromIndex < toIndex ? toIndex - 1 : toIndex
        clips.insert(item, at: max(0, min(clips.count, adjustedTarget)))
        if isPreviewingComposedResult {
            rebuildComposedPreview()
        }
    }

    func clearAll() {
        cancelCropEditing()
        invalidateComposedPreview()
        cancelExport()
        pause()
        clips.removeAll()
        selectedClipID = nil
        isPreviewingComposedResult = false
        activePreviewURL = nil
        player.replaceCurrentItem(with: nil)
        currentTime = 0
        lastExportResult = nil
        settings = ExportSettings()
        exportMode = .merged
        player.isMuted = false
    }

    // MARK: - Aspect Ratio & Crop

    func beginCropEditing() {
        guard let clip = selectedClip, !isExporting, !isEditingCrop else { return }
        pause()
        invalidateComposedPreview()
        isPreviewingComposedResult = false
        loadSelectedClipIntoPlayer(forceReload: true)
        cropDraftAspectRatio = clip.isCropped ? clip.cropAspectRatio : .custom
        cropDraft = clip.isCropped ? clip.cropRect : CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
    }

    func setAspectRatio(_ preset: AspectRatioPreset) {
        guard !isExporting else { return }
        if !isEditingCrop { beginCropEditing() }
        guard isEditingCrop, let clip = selectedClip else { return }
        cropDraftAspectRatio = preset
        if preset == .custom {
            if cropDraft == CGRect(x: 0, y: 0, width: 1, height: 1) {
                cropDraft = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
            }
        } else {
            cropDraft = preset.centeredNormalizedCrop(for: clip.displaySize)
        }
    }

    func updateSelectedCropRect(_ newRect: CGRect) {
        guard isEditingCrop else { return }
        cropDraft = newRect
    }

    func resetSelectedCrop() {
        guard !isExporting else { return }
        if !isEditingCrop { beginCropEditing() }
        guard isEditingCrop, let clip = selectedClip else { return }
        cropDraft = cropDraftAspectRatio == .custom
            ? CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
            : cropDraftAspectRatio.centeredNormalizedCrop(for: clip.displaySize)
    }

    func cancelCropEditing() {
        cropDraft = nil
    }

    func applyCrop(toAllClips: Bool = false) {
        guard !isExporting, let selected = selectedClip,
              toAllClips || isEditingCrop else { return }
        let rect = cropDraft ?? selected.cropRect
        let preset = isEditingCrop ? cropDraftAspectRatio : selected.cropAspectRatio
        for index in clips.indices where toAllClips || clips[index].id == selected.id {
            if toAllClips, preset.aspectRatio != nil {
                // Preserve the aspect ratio, relative zoom and position even for
                // clips with different resolutions or orientations.
                let sourceFit = preset.centeredNormalizedCrop(for: selected.displaySize)
                let targetFit = preset.centeredNormalizedCrop(for: clips[index].displaySize)
                let zoom = min(1, min(rect.width / sourceFit.width, rect.height / sourceFit.height))
                let width = targetFit.width * zoom
                let height = targetFit.height * zoom
                clips[index].cropRect = CGRect(
                    x: min(max(0, rect.midX - width / 2), 1 - width),
                    y: min(max(0, rect.midY - height / 2), 1 - height),
                    width: width, height: height
                )
            } else {
                clips[index].cropRect = rect
            }
            clips[index].cropAspectRatio = preset
        }
        cropDraft = nil
        lastExportResult = nil
        enforcePassthroughEligibility()
        setComposedPreviewEnabled(true)
    }

    func removeSelectedCrop() {
        guard let index = selectedClipIndex else { return }
        cancelCropEditing()
        clips[index].cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        clips[index].cropAspectRatio = .original
        lastExportResult = nil
        enforcePassthroughEligibility()
        if isPreviewingComposedResult { rebuildComposedPreview() }
    }

    func setRemoveAudio(_ remove: Bool) {
        settings.removeAudio = remove
        player.isMuted = remove
        lastExportResult = nil
        if isPreviewingComposedResult { rebuildComposedPreview() }
    }

    // MARK: - Trimming & Playback

    func updateTrim(start: Double, end: Double, seekTo targetTime: Double?) {
        guard let index = selectedClipIndex else { return }
        let duration = clips[index].durationSeconds
        let minLen = min(0.2, duration)

        var clampedStart = max(0, min(start, duration - minLen))
        var clampedEnd = max(clampedStart + minLen, min(end, duration))
        if clampedEnd - clampedStart < minLen {
            clampedStart = max(0, clampedEnd - minLen)
            clampedEnd = min(duration, clampedStart + minLen)
        }

        clips[index].trimStart = clampedStart
        clips[index].trimEnd = clampedEnd
        lastExportResult = nil

        if let targetTime {
            seek(to: targetTime)
        }
    }

    func togglePlayPause() {
        guard !clips.isEmpty else { return }

        if isPlaying {
            pause()
            return
        }

        if isPreviewingComposedResult {
            if currentTime >= totalTrimmedDuration - 0.04 {
                seek(to: 0)
            }
        } else if let clip = selectedClip {
            if currentTime < clip.trimStart - 0.03 || currentTime >= clip.trimEnd - 0.03 {
                seek(to: clip.trimStart)
            }
        }

        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let clamped: Double
        if isPreviewingComposedResult {
            clamped = max(0, min(seconds, totalTrimmedDuration))
        } else if let clip = selectedClip {
            clamped = max(0, min(seconds, clip.durationSeconds))
        } else {
            clamped = max(0, seconds)
        }

        currentTime = clamped
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setComposedPreviewEnabled(_ enabled: Bool) {
        guard !clips.isEmpty, !isEditingCrop else { return }
        pause()
        isPreviewingComposedResult = enabled
        if enabled {
            rebuildComposedPreview()
        } else {
            invalidateComposedPreview()
            loadSelectedClipIntoPlayer(forceReload: true)
        }
    }

    private func invalidateComposedPreview() {
        previewGeneration = UUID()
        previewTask?.cancel()
        previewTask = nil
        isBuildingPreview = false
    }

    private func rebuildComposedPreview() {
        invalidateComposedPreview()
        guard isPreviewingComposedResult, !clips.isEmpty else { return }
        let generation = previewGeneration
        let clipsSnapshot = clips
        let settingsSnapshot = settings
        isBuildingPreview = true
        pause()

        previewTask = Task {
            defer {
                if previewGeneration == generation {
                    isBuildingPreview = false
                    previewTask = nil
                }
            }
            do {
                let item = try await previewBuilder(clipsSnapshot, settingsSnapshot)
                guard !Task.isCancelled, previewGeneration == generation,
                      isPreviewingComposedResult else { return }
                activePreviewURL = nil
                replacePlayerItem(item)
                currentTime = 0
            } catch {
                guard !Task.isCancelled, previewGeneration == generation,
                      isPreviewingComposedResult else { return }
                errorMessage = error.localizedDescription
                isPreviewingComposedResult = false
                loadSelectedClipIntoPlayer(forceReload: true)
            }
        }
    }

    private func loadSelectedClipIntoPlayer(forceReload: Bool) {
        guard let clip = selectedClip else { return }
        if forceReload || activePreviewURL != clip.url {
            activePreviewURL = clip.url
            let item = AVPlayerItem(url: clip.url)
            replacePlayerItem(item)
        }
        seek(to: clip.trimStart)
    }

    private func replacePlayerItem(_ item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isPlaying = false
            }
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return }
                let sec = time.seconds
                guard sec.isFinite else { return }
                self.currentTime = sec

                if !self.isPreviewingComposedResult, let clip = self.selectedClip {
                    if sec >= clip.trimEnd - 0.02 {
                        self.pause()
                        self.seek(to: clip.trimEnd)
                    }
                }
            }
        }
    }

    // MARK: - Settings & Export

    func setResolutionLimit(_ limit: OutputResolutionLimit) {
        settings.resolutionLimit = limit
        lastExportResult = nil
        enforcePassthroughEligibility()
        if isPreviewingComposedResult {
            rebuildComposedPreview()
        }
    }

    func enforcePassthroughEligibility() {
        if settings.compressionMode == .passthrough && !isPassthroughEligible {
            settings.compressionMode = .preset
        }
    }

    func startExport() {
        guard !clips.isEmpty, !isExporting, !isEditingCrop else { return }
        pause()
        if exportMode == .separate {
            let panel = NSOpenPanel()
            panel.title = tr("Vyberte složku pro export klipů")
            panel.prompt = tr("Exportovat klipy")
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let directory = panel.url {
                startSeparateExport(in: directory)
            }
            return
        }

        let baseName: String
        if clips.count == 1, let first = clips.first {
            baseName = first.url.deletingPathExtension().lastPathComponent + "_upraveno"
        } else {
            baseName = "LocalioBC_spojene"
        }

        let panel = NSSavePanel()
        panel.title = tr("Exportovat video")
        panel.prompt = tr("Exportovat")
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [settings.container.utType]
        panel.nameFieldStringValue = "\(baseName).\(settings.container.fileExtension)"
        if let sourceDir = clips.first?.url.deletingLastPathComponent() {
            panel.directoryURL = sourceDir
        }

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        startExport(to: destinationURL)
    }

    private struct ExportJob {
        let clips: [VideoClip]
        let destination: URL
    }

    func validateCurrentExportSettings() throws {
        if exportMode == .separate {
            for clip in clips { try settings.validateTargetSize(for: [clip]) }
        } else {
            try settings.validateTargetSize(for: clips)
        }
    }

    func startExport(to destinationURL: URL) {
        beginExport(jobs: [ExportJob(clips: clips, destination: destinationURL)], directory: nil)
    }

    func startSeparateExport(in directory: URL) {
        guard !clips.isEmpty, !isExporting, !isEditingCrop else { return }
        do {
            for clip in clips { try settings.validateTargetSize(for: [clip]) }
            // A unique folder prevents collisions with sources and previous exports.
            let folder = directory.appendingPathComponent("LocalioBC_\(UUID().uuidString.prefix(8))", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            let jobs = clips.enumerated().map { index, clip in
                let name = String(format: "%03d_%@", index + 1, clip.url.deletingPathExtension().lastPathComponent)
                return ExportJob(clips: [clip], destination: folder.appendingPathComponent(name).appendingPathExtension(settings.container.fileExtension))
            }
            beginExport(jobs: jobs, directory: folder)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginExport(jobs: [ExportJob], directory: URL?) {
        guard !clips.isEmpty, !isExporting, !isEditingCrop, !jobs.isEmpty else { return }
        do {
            for job in jobs { try settings.validateTargetSize(for: job.clips) }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        pause()
        let settingsSnapshot = settings
        let id = UUID()
        exportID = id
        isExporting = true
        exportProgress = 0
        lastExportResult = nil
        lastExportDirectory = directory
        exportStatus = tr("Připravuji export…")

        exportTask = Task {
            do {
                for (index, job) in jobs.enumerated() {
                    try Task.checkCancellation()
                    guard exportID == id else { return }
                    exportStatus = directory == nil ? tr("Exportuji video…") : tr("Export klipu %d z %d", index + 1, jobs.count)
                    let result = try await exportOperation(job.clips, settingsSnapshot, job.destination) { progress in
                        Task { @MainActor [weak self] in
                            guard let self, self.exportID == id else { return }
                            self.exportProgress = max(self.exportProgress, (Double(index) + max(0, min(1, progress))) / Double(jobs.count))
                        }
                    }
                    try Task.checkCancellation()
                    guard exportID == id else { return }
                    lastExportResults.append(result)
                    lastExportResult = result
                    exportProgress = Double(index + 1) / Double(jobs.count)
                }
            } catch is CancellationError {
                // Already completed files remain available after cancellation.
            } catch let error as VideoExporterError where error == .cancelled {
                // Already completed files remain available after cancellation.
            } catch {
                if !Task.isCancelled, exportID == id { errorMessage = error.localizedDescription }
            }
            if exportID == id {
                isExporting = false
                exportTask = nil
                exportID = nil
            }
        }
    }

    func cancelExport() {
        exportID = nil
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        exportProgress = 0
    }

    func revealLastExportInFinder() {
        guard let url = lastExportDirectory ?? lastExportResult?.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openLastExport() {
        guard let url = lastExportDirectory ?? lastExportResult?.outputURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Formatting Helpers

    nonisolated static func formatTime(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let totalTenths = Int((clamped * 10.0).rounded())
        let tenths = totalTenths % 10
        let totalSeconds = totalTenths / 10
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, mins, secs, tenths)
        }
        return String(format: "%02d:%02d.%d", mins, secs, tenths)
    }

    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}

extension VideoExporterError: Equatable {
    static func == (lhs: VideoExporterError, rhs: VideoExporterError) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled), (.cannotCreateExportSession, .cannotCreateExportSession):
            return true
        case (.readerFailed(let a), .readerFailed(let b)):
            return a == b
        case (.writerFailed(let a), .writerFailed(let b)):
            return a == b
        case (.failedToMoveOutput(let a), .failedToMoveOutput(let b)):
            return a == b
        default:
            return false
        }
    }
}
