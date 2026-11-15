import AVFoundation
import Foundation
import XCTest
@testable import LocalioBC

final class EditorBunnyHandoffTests: XCTestCase {
    @MainActor
    func testMergedExportQueuesFinalFileAndSurvivesEditorReset() async throws {
        let files = try HandoffFiles()
        defer { files.remove() }
        let clips = try [files.clip("first.mov"), files.clip("second.mov")]
        let payload = Data(repeating: 0x37, count: 173)
        let destination = files.exports.appendingPathComponent("hotové video.mp4")
        var exportedClipIDs: [UUID] = []
        let editor = EditorViewModel(exportOperation: { clips, settings, url, progress in
            exportedClipIDs = clips.map(\.id)
            XCTAssertTrue(settings.removeAudio)
            try payload.write(to: url)
            progress(1)
            return ExportResult(outputURL: url, fileSizeBytes: Int64(payload.count), usedPassthrough: false)
        })
        editor.clips = clips
        editor.settings.removeAudio = true
        editor.startExport(to: destination)
        try await waitUntil { !editor.isExporting }

        XCTAssertEqual(exportedClipIDs, clips.map(\.id))
        XCTAssertNil(editor.errorMessage)
        XCTAssertNil(editor.lastExportUploadError)
        XCTAssertEqual(editor.lastExportResults.count, 1)
        XCTAssertEqual(editor.lastExportUploadSources.count, 1)
        let source = try XCTUnwrap(editor.lastExportUploadSources.first)
        XCTAssertEqual(source.fileName, destination.lastPathComponent)
        XCTAssertEqual(source.fileSizeBytes, Int64(payload.count))
        XCTAssertNil(source.relativePath)
        try assertRestorable(source, grant: destination, payload: payload)

        // Use an isolated disk and inert transport: queuing a finished export is
        // independent of resetting editor results and never starts a transfer.
        let transport = HandoffNoNetworkTransport()
        let disk = BunnyJSONUploadDiskStore(fileURL: files.root.appendingPathComponent("queue/uploads.json"))
        let uploads = BunnyUploadCoordinator(credentials: HandoffCredentials(), disk: disk, transport: transport)
        try uploads.saveConfiguration(BunnyStorageProfile(zoneName: "handoff-test",
            cdnBaseURL: URL(string: "https://cdn.example.com")!), password: "test-only")
        try uploads.enqueue(editor.lastExportUploadSources)
        editor.clearAll()

        XCTAssertTrue(editor.lastExportUploadSources.isEmpty)
        XCTAssertTrue(editor.lastExportResults.isEmpty)
        XCTAssertEqual(uploads.jobs.map(\.source), [source])
        XCTAssertEqual(uploads.jobs.map(\.state), [.queued])
        XCTAssertFalse(uploads.isUploading)
        let persistedSource = try XCTUnwrap(disk.load().jobs.first?.source)
        try assertRestorable(persistedSource, grant: destination, payload: payload)
        let networkCalls = await transport.callCount
        XCTAssertEqual(networkCalls, 0)
    }

    @MainActor
    func testSeparateExportCapturesFinishedFileDuringBatchAndRestoresParentGrant() async throws {
        let files = try HandoffFiles()
        defer { files.remove() }
        let clips = try [files.clip("one.mov"), files.clip("two.mov")]
        let payloads = [Data(repeating: 0x41, count: 71), Data(repeating: 0x62, count: 149)]
        let gate = HandoffExportGate()
        var startedClipIDs: [UUID] = []
        let editor = EditorViewModel(exportOperation: { clips, _, url, progress in
            let index = startedClipIDs.count
            startedClipIDs.append(try XCTUnwrap(clips.first?.id))
            if index == 1 { try await gate.wait() }
            try payloads[index].write(to: url)
            progress(1)
            return ExportResult(outputURL: url, fileSizeBytes: Int64(payloads[index].count), usedPassthrough: false)
        })
        defer { editor.cancelExport(); gate.resume(throwing: CancellationError()) }
        editor.clips = clips
        editor.exportMode = .separate
        editor.startSeparateExport(in: files.exports)
        try await waitUntil { gate.isWaiting }

        // The second operation still holds the export's destination grant. The
        // first completed file must already have its own durable upload source.
        XCTAssertTrue(editor.isExporting)
        XCTAssertEqual(editor.lastExportResults.count, 1)
        XCTAssertEqual(editor.lastExportUploadSources.count, 1)
        let firstSource = try XCTUnwrap(editor.lastExportUploadSources.first)
        let batchDirectory = try XCTUnwrap(editor.lastExportDirectory)
        XCTAssertEqual(firstSource.relativePath, batchDirectory.lastPathComponent + "/001_one.mp4")
        try assertRestorable(firstSource, grant: files.exports, payload: payloads[0])

        gate.resume()
        try await waitUntil { !editor.isExporting }
        XCTAssertNil(editor.errorMessage)
        XCTAssertNil(editor.lastExportUploadError)
        XCTAssertEqual(startedClipIDs, clips.map(\.id))
        XCTAssertEqual(editor.lastExportUploadSources.map(\.fileName), ["001_one.mp4", "002_two.mp4"])
        XCTAssertEqual(editor.lastExportUploadSources.map(\.fileSizeBytes), payloads.map { Int64($0.count) })
        XCTAssertEqual(editor.lastExportResults.map(\.outputURL), editor.lastExportUploadSources.map(\.originalURL))
        XCTAssertEqual(editor.exportProgress, 1)
        for (source, payload) in zip(editor.lastExportUploadSources, payloads) {
            try assertRestorable(source, grant: files.exports, payload: payload)
        }
    }

    @MainActor
    func testLaterBatchFailurePreservesCompletedUploadSourceAndFile() async throws {
        let files = try HandoffFiles()
        defer { files.remove() }
        let payload = Data(repeating: 0x53, count: 211)
        var calls = 0
        let editor = EditorViewModel(exportOperation: { _, _, url, _ in
            calls += 1
            if calls == 2 { throw HandoffTestError.exportFailed }
            try payload.write(to: url)
            return ExportResult(outputURL: url, fileSizeBytes: Int64(payload.count), usedPassthrough: false)
        })
        editor.clips = try [files.clip("finished.mov"), files.clip("fails.mov"), files.clip("never-started.mov")]
        editor.exportMode = .separate
        editor.startSeparateExport(in: files.exports)
        try await waitUntil { !editor.isExporting }

        XCTAssertEqual(calls, 2)
        XCTAssertNotNil(editor.errorMessage)
        XCTAssertNil(editor.lastExportUploadError)
        XCTAssertEqual(editor.lastExportResults.count, 1)
        XCTAssertEqual(editor.lastExportUploadSources.count, 1)
        let source = try XCTUnwrap(editor.lastExportUploadSources.first)
        XCTAssertEqual(source.fileName, "001_finished.mp4")
        XCTAssertEqual(source.fileSizeBytes, Int64(payload.count))
        XCTAssertEqual(editor.lastExportResult?.outputURL, source.originalURL)
        try assertRestorable(source, grant: files.exports, payload: payload)
        let batchDirectory = try XCTUnwrap(editor.lastExportDirectory)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: batchDirectory.path), [source.fileName])
    }

    @MainActor
    func testCancellingBatchPreservesCompletedUploadSourceAndStopsRemainingFiles() async throws {
        let files = try HandoffFiles()
        defer { files.remove() }
        let payload = Data(repeating: 0x29, count: 103)
        let gate = HandoffExportGate()
        var calls = 0
        let editor = EditorViewModel(exportOperation: { _, _, url, _ in
            calls += 1
            if calls == 2 { try await gate.wait() }
            try payload.write(to: url)
            return ExportResult(outputURL: url, fileSizeBytes: Int64(payload.count), usedPassthrough: false)
        })
        defer { editor.cancelExport(); gate.resume(throwing: CancellationError()) }
        editor.clips = try [files.clip("finished.mov"), files.clip("cancelled.mov"), files.clip("never-started.mov")]
        editor.exportMode = .separate
        editor.startSeparateExport(in: files.exports)
        try await waitUntil { gate.isWaiting }
        XCTAssertEqual(editor.lastExportUploadSources.count, 1)
        let completedSource = try XCTUnwrap(editor.lastExportUploadSources.first)

        editor.cancelExport()
        gate.resume(throwing: CancellationError())
        try await waitUntil { gate.didFinish }

        XCTAssertFalse(editor.isExporting)
        XCTAssertEqual(calls, 2)
        XCTAssertNil(editor.errorMessage)
        XCTAssertNil(editor.lastExportUploadError)
        XCTAssertEqual(editor.lastExportResults.count, 1)
        XCTAssertEqual(editor.lastExportUploadSources, [completedSource])
        XCTAssertEqual(editor.lastExportResult?.outputURL, completedSource.originalURL)
        try assertRestorable(completedSource, grant: files.exports, payload: payload)
        let batchDirectory = try XCTUnwrap(editor.lastExportDirectory)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: batchDirectory.path), [completedSource.fileName])
    }

    private func assertRestorable(_ source: BunnyUploadSource, grant: URL, payload: Data,
                                  file: StaticString = #filePath, line: UInt = #line) throws {
        // Exercise the recorded bookmark after serialization, as a persisted
        // upload queue does, rather than relying on the original file URL.
        let recorded = try JSONDecoder().decode(BunnyUploadSource.self, from: JSONEncoder().encode(source))
        XCTAssertFalse(recorded.bookmarkData.isEmpty, file: file, line: line)
        var stale = false
        let recordedGrant = try URL(resolvingBookmarkData: recorded.bookmarkData,
            options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        XCTAssertEqual(recordedGrant.resolvingSymlinksInPath().standardizedFileURL,
                       grant.resolvingSymlinksInPath().standardizedFileURL, file: file, line: line)
        let access = try BunnyBookmarkSourceAccess().access(recorded)
        XCTAssertEqual(access.fileURL.resolvingSymlinksInPath().standardizedFileURL,
                       source.originalURL.resolvingSymlinksInPath().standardizedFileURL, file: file, line: line)
        XCTAssertEqual(try Data(contentsOf: access.fileURL), payload, file: file, line: line)
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for editor export handoff.", file: file, line: line)
                throw HandoffTestError.timeout
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
}

private final class HandoffFiles {
    let root: URL
    let exports: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("EditorBunnyHandoff-\(UUID())", isDirectory: true)
        exports = root.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Inputs"), withIntermediateDirectories: true)
    }
    func clip(_ name: String) throws -> VideoClip {
        let url = root.appendingPathComponent("Inputs").appendingPathComponent(name)
        let data = Data(repeating: 0xA5, count: 31)
        try data.write(to: url)
        let size = CGSize(width: 320, height: 180)
        return VideoClip(url: url, fileName: name, fileSizeBytes: Int64(data.count),
            duration: CMTime(seconds: 1, preferredTimescale: 600), naturalSize: size,
            preferredTransform: .identity, displaySize: size, nominalFrameRate: 30,
            hasAudio: false, estimatedDataRate: 1_000_000)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}

@MainActor private final class HandoffExportGate {
    private var continuation: CheckedContinuation<Void, Error>?
    private(set) var didFinish = false
    var isWaiting: Bool { continuation != nil }
    func wait() async throws {
        defer { didFinish = true }
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func resume(throwing error: Error? = nil) {
        guard let pending = continuation else { return }
        continuation = nil
        if let error { pending.resume(throwing: error) }
        else { pending.resume() }
    }
}

private enum HandoffTestError: Error { case exportFailed, timeout, unexpectedNetwork }

private struct HandoffCredentials: BunnyCredentialStore {
    func password(for profileID: UUID) throws -> String? { "test-only" }
    func save(password: String, for profileID: UUID) throws {}
    func deletePassword(for profileID: UUID) throws {}
}

private actor HandoffNoNetworkTransport: BunnyStorageTransport {
    private(set) var callCount = 0
    func upload(file: URL, to remoteURL: URL, password: String, checksum: String,
                progress: @escaping @Sendable (Int64, Int64) -> Void) async throws {
        callCount += 1
        throw HandoffTestError.unexpectedNetwork
    }
    func verify(fileAt remoteURL: URL, password: String, size: Int64, checksum: String) async throws -> BunnyRemoteFileState {
        callCount += 1
        throw HandoffTestError.unexpectedNetwork
    }
}
