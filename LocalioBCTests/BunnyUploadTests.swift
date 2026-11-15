import CryptoKit
import Foundation
import XCTest
@testable import LocalioBC

final class BunnyUploadTests: XCTestCase {
    @MainActor
    func testExplicitBatchUsesFinalFilesAndPersistsNoPassword() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let sources = try [fixture.source("one.mp4"), fixture.source("two.mov")]
        let disk = BunnyMemoryDisk(); let credentials = BunnyMemoryCredentials(); let transport = BunnyMockTransport()
        let model = BunnyUploadCoordinator(credentials: credentials, disk: disk, transport: transport, sourceAccess: BunnyTestFileAccess())
        let profile = BunnyStorageProfile(zoneName: "my-zone", remoteFolder: "/videos/site/", cdnBaseURL: URL(string: "https://media.example.com")!)
        try model.saveConfiguration(profile, password: "test-storage-password")
        try model.enqueue(sources); try model.enqueue(sources)
        XCTAssertEqual(model.jobs.count, 2)
        let observed1 = await transport.uploadCount
        XCTAssertEqual(observed1, 0)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(disk.snapshot), as: UTF8.self).contains("test-storage-password"))
        model.start()
        try await wait { !model.isUploading && model.jobs.allSatisfy { $0.state == .completed } }
        let observed2 = await transport.uploadCount
        XCTAssertEqual(observed2, 2)
        let observed3 = await transport.maximumConcurrent
        XCTAssertEqual(observed3, 1)
        XCTAssertEqual(model.jobs.map(\.totalBytes), sources.map(\.fileSizeBytes))
        XCTAssertTrue(model.jobs.allSatisfy { $0.progress == 1 && $0.checksum?.count == 64 })
        XCTAssertEqual(Set(model.jobs.map(\.remotePath)).count, 2)
        XCTAssertEqual(model.jobs[0].publicURL, try profile.validated().publicURL(for: sources[0]))
        let observed4 = await transport.filePayloads
        XCTAssertEqual(observed4, try sources.map { try Data(contentsOf: $0.originalURL) })
    }

    @MainActor
    func testLostAcknowledgementVerifiesAcceptedObjectWithoutDuplicatePUT() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let transport = BunnyMockTransport(mode: .acceptThenDisconnect)
        let model = try configured(transport: transport)
        try model.enqueue([fixture.source("accepted.mp4")]); model.start()
        try await wait { !model.isUploading && model.jobs.first?.state == .completed }
        let observed5 = await transport.uploadCount
        XCTAssertEqual(observed5, 1)
        let observed6 = await transport.verificationCount
        XCTAssertEqual(observed6, 2)
        XCTAssertEqual(model.jobs.first?.attempts, 1)
    }

    @MainActor
    func testTemporaryFailureRetriesOnlyAfterVerificationAtSameUniquePath() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let transport = BunnyMockTransport(mode: .failFirst)
        let model = try configured(transport: transport)
        try model.enqueue([fixture.source("retry.mp4")]); model.start()
        try await wait { !model.isUploading && model.jobs.first?.state == .completed }
        let observed7 = await transport.uploadCount
        XCTAssertEqual(observed7, 2)
        let observed8 = await transport.verificationCount
        XCTAssertEqual(observed8, 2)
        let observed9 = await transport.uploadURLs
        XCTAssertEqual(Set(observed9).count, 1)
    }

    @MainActor
    func testCancelStopsCurrentJobAndPreservesCompletedFilesAndQueuedJobs() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let sources = try [fixture.source("a.mp4"), fixture.source("b.mp4"), fixture.source("c.mp4")]
        let transport = BunnyMockTransport(mode: .suspendSecond)
        let model = try configured(transport: transport)
        try model.enqueue(sources); model.start()
        try await wait { model.jobs[0].state == .completed && model.jobs[1].state == .uploading }
        model.cancel(model.jobs[1].id)
        try await wait { !model.isUploading }
        XCTAssertEqual(model.jobs.map(\.state), [.completed, .cancelled, .queued])
        XCTAssertTrue(sources.allSatisfy { FileManager.default.fileExists(atPath: $0.originalURL.path) })
        model.start()
        try await wait { !model.isUploading && model.jobs[2].state == .completed }
        XCTAssertEqual(model.jobs[1].state, .cancelled)
        let observed10 = await transport.uploadCount
        XCTAssertEqual(observed10, 3)
    }

    @MainActor
    func testRestoredUploadWaitsForExplicitRetryAndReconcilesRemoteState() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let source = try fixture.source("restored.mp4")
        let profile = testProfile()
        var job = BunnyUploadJob(source: source, profile: profile)
        job.state = .uploading; job.attempts = 1; job.requiresRemoteVerification = true
        let disk = BunnyMemoryDisk(state: BunnyPersistedState(profile: profile, jobs: [job]))
        let credentials = BunnyMemoryCredentials(); try credentials.save(password: "password", for: profile.id)
        let transport = BunnyMockTransport()
        await transport.acceptRemote(url: job.remoteURL, size: source.fileSizeBytes,
                                     checksum: try await BunnyFileHasher().checksum(of: source.originalURL))
        let model = BunnyUploadCoordinator(credentials: credentials, disk: disk, transport: transport,
                                          sourceAccess: BunnyTestFileAccess(), sleep: { _ in })
        XCTAssertEqual(model.jobs.first?.state, .interrupted)
        model.start()
        XCTAssertFalse(model.isUploading)
        let observed11 = await transport.uploadCount
        XCTAssertEqual(observed11, 0)
        model.retry(job.id)
        try await wait { !model.isUploading && model.jobs.first?.state == .completed }
        let observed12 = await transport.uploadCount
        XCTAssertEqual(observed12, 0)
        let observed13 = await transport.verificationCount
        XCTAssertEqual(observed13, 1)
    }

    @MainActor
    func testChangedSourceAfterHashingNeverReachesNetwork() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let source = try fixture.source("changed.mp4")
        let transport = BunnyMockTransport()
        let model = BunnyUploadCoordinator(credentials: BunnyMemoryCredentials(), disk: BunnyMemoryDisk(),
                                          transport: transport, sourceAccess: BunnyTestFileAccess(), hasher: BunnyMutatingHasher())
        try model.saveConfiguration(testProfile(), password: "password")
        try model.enqueue([source]); model.start()
        try await wait { !model.isUploading }
        XCTAssertEqual(model.jobs.first?.state, .needsFile)
        let observed14 = await transport.uploadCount
        XCTAssertEqual(observed14, 0)
        let observed15 = await transport.verificationCount
        XCTAssertEqual(observed15, 0)
    }

    @MainActor
    func testTerminalRateLimitRetainsCooldownAndKeychainFailureCanBeRepaired() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let credentials = BunnyMemoryCredentials(); credentials.failReads = true
        let disk = BunnyMemoryDisk(state: BunnyPersistedState(profile: testProfile(), jobs: []))
        let transport = BunnyMockTransport(mode: .rateLimited)
        let model = BunnyUploadCoordinator(credentials: credentials, disk: disk, transport: transport,
                                          sourceAccess: BunnyTestFileAccess(), sleep: { _ in })
        XCTAssertFalse(model.isConfigured)
        try model.saveConfiguration(try XCTUnwrap(model.profile), password: "replacement")
        credentials.failReads = false
        XCTAssertTrue(model.isConfigured)
        try model.enqueue([fixture.source("rate-limited.mp4")]); model.start()
        try await wait { !model.isUploading }
        XCTAssertEqual(model.jobs.first?.state, .failed)
        XCTAssertGreaterThan(try XCTUnwrap(model.jobs.first?.retryNotBefore).timeIntervalSinceNow, 100)
        let attempts = await transport.uploadCount
        model.retry(try XCTUnwrap(model.jobs.first?.id))
        XCTAssertFalse(model.isUploading)
        let observed16 = await transport.uploadCount
        XCTAssertEqual(observed16, attempts)
    }

    @MainActor
    func testDiskFailurePreventsNetworkAndBookmarkRoundTripKeepsRelativeFile() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let source = try fixture.source("nested/movie.mp4")
        let captured = try BunnyUploadSource.capture(fileURL: source.originalURL, grantURL: fixture.root)
        XCTAssertEqual(captured.relativePath, "nested/movie.mp4")
        let restored = try BunnyBookmarkSourceAccess().access(captured)
        XCTAssertEqual(try Data(contentsOf: restored.fileURL), try Data(contentsOf: source.originalURL))
        let disk = BunnyMemoryDisk(); let transport = BunnyMockTransport()
        let model = BunnyUploadCoordinator(credentials: BunnyMemoryCredentials(), disk: disk,
                                          transport: transport, sourceAccess: BunnyTestFileAccess())
        try model.saveConfiguration(testProfile(), password: "password")
        try model.enqueue([source]); disk.failWrites = true; model.start()
        try await wait { !model.isUploading }
        XCTAssertNotNil(model.errorMessage)
        let observed17 = await transport.uploadCount
        XCTAssertEqual(observed17, 0)
        let observed18 = await transport.verificationCount
        XCTAssertEqual(observed18, 0)
    }

    func testProfileValidationAndStreamingSHA256() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let source = try fixture.source("hash.mp4", data: Data("abc".utf8))
        let actualChecksum = try await BunnyFileHasher().checksum(of: source.originalURL)
        XCTAssertEqual(actualChecksum, "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD")
        for zone in ["", "žluťoučký", "bad_zone", String(repeating: "a", count: 64)] {
            XCTAssertThrowsError(try BunnyStorageProfile(zoneName: zone, cdnBaseURL: URL(string: "https://cdn.example.com")!).validated())
        }
        for url in ["http://cdn.example.com", "https://user:secret@cdn.example.com", "https://cdn.example.com?secret=x"] {
            XCTAssertThrowsError(try BunnyStorageProfile(zoneName: "valid", cdnBaseURL: URL(string: url)!).validated())
        }
    }

    @MainActor
    func testReselectingChangedSourceAfterAmbiguousPUTUsesFreshPathAndExplicitRetry() async throws {
        let fixture = try BunnyTestFiles(); defer { fixture.remove() }
        let source = try fixture.source("reselected.mp4")
        let profile = testProfile()
        var original = BunnyUploadJob(source: source, profile: profile)
        original.state = .failed; original.attempts = 1; original.requiresRemoteVerification = true
        let oldURL = original.remoteURL
        let oldChecksum = try await BunnyFileHasher().checksum(of: source.originalURL)
        let credentials = BunnyMemoryCredentials(); try credentials.save(password: "password", for: profile.id)
        let transport = BunnyMockTransport()
        await transport.acceptRemote(url: oldURL, size: source.fileSizeBytes, checksum: oldChecksum)
        let model = BunnyUploadCoordinator(credentials: credentials,
            disk: BunnyMemoryDisk(state: BunnyPersistedState(profile: profile, jobs: [original])),
            transport: transport, sourceAccess: BunnyTestFileAccess(), sleep: { _ in })
        try Data("new explicitly selected bytes".utf8).write(to: source.originalURL)
        try model.reselect(original.id, fileURL: source.originalURL)
        XCTAssertEqual(model.jobs.count, 1)
        XCTAssertEqual(model.jobs[0].id, original.id)
        XCTAssertNotEqual(model.jobs[0].remoteURL, oldURL)
        XCTAssertEqual(model.jobs[0].state, .interrupted)
        XCTAssertEqual(model.jobs[0].attempts, 0)
        XCTAssertNil(model.jobs[0].checksum)
        XCTAssertFalse(model.isUploading)
        model.retry(original.id)
        try await wait { !model.isUploading && model.jobs[0].state == .completed }
        let urls = await transport.uploadURLs
        XCTAssertEqual(urls, [model.jobs[0].remoteURL])
        XCTAssertFalse(urls.contains(oldURL))
    }

    @MainActor private func configured(transport: BunnyMockTransport) throws -> BunnyUploadCoordinator {
        let model = BunnyUploadCoordinator(credentials: BunnyMemoryCredentials(), disk: BunnyMemoryDisk(),
                                          transport: transport, sourceAccess: BunnyTestFileAccess(), sleep: { _ in })
        try model.saveConfiguration(testProfile(), password: "password")
        return model
    }
    private func testProfile() -> BunnyStorageProfile {
        BunnyStorageProfile(zoneName: "test-zone", remoteFolder: "site", cdnBaseURL: URL(string: "https://media.example.com")!)
    }
    @MainActor private func wait(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !predicate() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Upload state transition timed out", file: file, line: line)
                throw NSError(domain: "BunnyTestTimeout", code: 1)
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
}

private final class BunnyTestFiles {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("BunnyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func source(_ name: String, data: Data = Data(repeating: 7, count: 4096)) throws -> BunnyUploadSource {
        let file = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file)
        return BunnyUploadSource(id: UUID(), fileName: file.lastPathComponent, originalURL: file,
                                 bookmarkData: Data([1]), relativePath: nil, fingerprint: try BunnyFileFingerprint.read(file))
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
private struct BunnyTestFileAccess: BunnySourceAccessing {
    func access(_ source: BunnyUploadSource) throws -> BunnyResolvedSource {
        guard try BunnyFileFingerprint.read(source.originalURL) == source.fingerprint else { throw BunnyStorageError.sourceChanged }
        return BunnyResolvedSource(fileURL: source.originalURL)
    }
}
private struct BunnyMutatingHasher: BunnyFileHashing {
    func checksum(of file: URL) async throws -> String {
        let hash = try await BunnyFileHasher().checksum(of: file)
        try Data("changed file contents".utf8).write(to: file)
        return hash
    }
}
private final class BunnyMemoryCredentials: BunnyCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UUID: String] = [:]
    private var shouldFailReads = false
    var failReads: Bool { get { lock.withLock { shouldFailReads } } set { lock.withLock { shouldFailReads = newValue } } }
    func password(for profileID: UUID) throws -> String? {
        try lock.withLock { if shouldFailReads { throw BunnyStorageError.credentialUnavailable }; return values[profileID] }
    }
    func save(password: String, for profileID: UUID) throws { lock.withLock { values[profileID] = password } }
    func deletePassword(for profileID: UUID) throws { lock.withLock { _ = values.removeValue(forKey: profileID) } }
}
private final class BunnyMemoryDisk: BunnyUploadDiskStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state: BunnyPersistedState
    private var shouldFailWrites = false
    var failWrites: Bool { get { lock.withLock { shouldFailWrites } } set { lock.withLock { shouldFailWrites = newValue } } }
    var snapshot: BunnyPersistedState { lock.withLock { state } }
    init(state: BunnyPersistedState = BunnyPersistedState(profile: nil, jobs: [])) { self.state = state }
    func load() throws -> BunnyPersistedState { snapshot }
    func save(_ state: BunnyPersistedState) throws {
        try lock.withLock { if shouldFailWrites { throw BunnyStorageError.persistenceFailure }; self.state = state }
    }
}
private actor BunnyMockTransport: BunnyStorageTransport {
    enum Mode: Sendable, Equatable { case success, acceptThenDisconnect, failFirst, suspendSecond, rateLimited }
    let mode: Mode
    private(set) var uploadCount = 0
    private(set) var verificationCount = 0
    private(set) var maximumConcurrent = 0
    private var concurrent = 0
    private(set) var filePayloads: [Data] = []
    private(set) var uploadURLs: [URL] = []
    private var remote: [URL: (Int64, String)] = [:]
    init(mode: Mode = .success) { self.mode = mode }
    func acceptRemote(url: URL, size: Int64, checksum: String) { remote[url] = (size, checksum) }
    func upload(file: URL, to remoteURL: URL, password: String, checksum: String,
                progress: @escaping @Sendable (Int64, Int64) -> Void) async throws {
        uploadCount += 1; concurrent += 1; maximumConcurrent = max(maximumConcurrent, concurrent)
        defer { concurrent -= 1 }
        uploadURLs.append(remoteURL)
        if mode == .rateLimited { throw BunnyTransferError.rateLimited(retryAfter: 120) }
        if mode == .failFirst && uploadCount == 1 { throw BunnyTransferError.temporary(statusCode: 503) }
        if mode == .suspendSecond && uploadCount == 2 { try await Task.sleep(for: .seconds(60)) }
        let data = try Data(contentsOf: file); filePayloads.append(data)
        progress(Int64(data.count), Int64(data.count))
        remote[remoteURL] = (Int64(data.count), checksum)
        if mode == .acceptThenDisconnect && uploadCount == 1 { throw BunnyTransferError.ambiguous }
    }
    func verify(fileAt remoteURL: URL, password: String, size: Int64, checksum: String) async throws -> BunnyRemoteFileState {
        verificationCount += 1
        guard let stored = remote[remoteURL] else { return .missing }
        return stored.0 == size && stored.1 == checksum ? .matches : .conflict
    }
}
