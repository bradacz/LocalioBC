import Foundation
import Observation

/// Uploads are explicit and independent of the editor's current clips/results.
/// One worker streams one file at a time; a restored queue never starts itself.
@MainActor @Observable
final class BunnyUploadCoordinator {
    static let shared = BunnyUploadCoordinator()
    private(set) var profile: BunnyStorageProfile?
    private(set) var jobs: [BunnyUploadJob] = []
    private(set) var hasStoredCredential = false
    private(set) var isUploading = false
    var errorMessage: String?
    var isConfigured: Bool { profile != nil && hasStoredCredential }
    var hasUnfinishedJobs: Bool { jobs.contains { $0.state != .completed && $0.state != .cancelled } }
    var pendingCount: Int { jobs.filter { $0.state == .queued || $0.state == .interrupted }.count }

    @ObservationIgnored private let credentials: any BunnyCredentialStore
    @ObservationIgnored private let disk: any BunnyUploadDiskStore
    @ObservationIgnored private let transport: any BunnyStorageTransport
    @ObservationIgnored private let sourceAccess: any BunnySourceAccessing
    @ObservationIgnored private let hasher: any BunnyFileHashing
    @ObservationIgnored private let sleep: @Sendable (TimeInterval) async throws -> Void
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var activeJobID: UUID?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var diskAvailable = true

    init(credentials: any BunnyCredentialStore = BunnyKeychainCredentialStore(),
         disk: any BunnyUploadDiskStore = BunnyJSONUploadDiskStore(),
         transport: any BunnyStorageTransport = BunnyURLSessionTransport(),
         sourceAccess: any BunnySourceAccessing = BunnyBookmarkSourceAccess(),
         hasher: any BunnyFileHashing = BunnyFileHasher(),
         sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
             try await Task.sleep(for: .seconds(seconds))
         }) {
        self.credentials = credentials; self.disk = disk; self.transport = transport
        self.sourceAccess = sourceAccess; self.hasher = hasher; self.sleep = sleep
        do {
            let state = try disk.load()
            profile = try state.profile?.validated()
            jobs = try state.jobs.map { job in
                _ = try job.profile.validated()
                guard job.remotePath == job.profile.remotePath(for: job.source),
                      !job.source.fileName.isEmpty, ![".", ".."].contains(job.source.fileName),
                      !job.source.fileName.contains("/"), !job.source.fileName.contains("\\") else {
                    throw BunnyStorageError.persistenceFailure
                }
                var restored = job
                if job.state.isActive || job.state == .queued {
                    restored.state = .interrupted
                    restored.requiresRemoteVerification = job.requiresRemoteVerification || job.attempts > 0
                    restored.bytesSent = 0
                }
                return restored
            }
            if let profile {
                do { hasStoredCredential = (try credentials.password(for: profile.id))?.isEmpty == false }
                catch { errorMessage = BunnyStorageError.credentialUnavailable.localizedDescription }
            }
            try disk.save(BunnyPersistedState(profile: profile, jobs: jobs))
        } catch {
            diskAvailable = false
            errorMessage = BunnyStorageError.persistenceFailure.localizedDescription
        }
    }

    func saveConfiguration(_ candidate: BunnyStorageProfile, password: String) throws {
        guard !isUploading else { throw BunnyStorageError.profileBusy }
        try ensureDisk()
        var candidate = try candidate.validated()
        let oldProfile = profile
        let sameTarget = oldProfile?.zoneName == candidate.zoneName && oldProfile?.region == candidate.region
        if oldProfile != nil && !sameTarget && hasUnfinishedJobs { throw BunnyStorageError.profileBusy }
        if sameTarget, let oldProfile { candidate.id = oldProfile.id }
        else if oldProfile != nil { candidate.id = UUID() }
        else if let previous = jobs.first(where: { $0.profile.zoneName == candidate.zoneName && $0.profile.region == candidate.region }) {
            candidate.id = previous.profile.id
        }
        let supplied = password.trimmingCharacters(in: .whitespacesAndNewlines)
        // A locked/missing Keychain item must not prevent entering a replacement.
        let oldPassword: String?
        if supplied.isEmpty { oldPassword = try credentials.password(for: candidate.id) }
        else { oldPassword = try? credentials.password(for: candidate.id) }
        let value = supplied.isEmpty && sameTarget ? oldPassword : supplied
        guard let value, !value.isEmpty, !value.contains("\r"), !value.contains("\n") else { throw BunnyStorageError.missingPassword }
        try credentials.save(password: value, for: candidate.id)
        do { try disk.save(BunnyPersistedState(profile: candidate, jobs: jobs)) }
        catch {
            if let oldPassword { try? credentials.save(password: oldPassword, for: candidate.id) }
            else { try? credentials.deletePassword(for: candidate.id) }
            throw BunnyStorageError.persistenceFailure
        }
        if let oldProfile, oldProfile.id != candidate.id {
            do { try credentials.deletePassword(for: oldProfile.id) }
            catch {
                try? disk.save(BunnyPersistedState(profile: oldProfile, jobs: jobs))
                if let oldPassword { try? credentials.save(password: oldPassword, for: candidate.id) }
                else { try? credentials.deletePassword(for: candidate.id) }
                throw BunnyStorageError.credentialUnavailable
            }
        }
        profile = candidate; hasStoredCredential = true; errorMessage = nil
    }

    func deleteConfiguration() throws {
        guard !isUploading else { throw BunnyStorageError.profileBusy }
        try ensureDisk()
        guard let profile else { return }
        let previousPassword = try credentials.password(for: profile.id)
        try credentials.deletePassword(for: profile.id)
        do { try disk.save(BunnyPersistedState(profile: nil, jobs: jobs)) }
        catch {
            if let previousPassword { try? credentials.save(password: previousPassword, for: profile.id) }
            throw BunnyStorageError.persistenceFailure
        }
        self.profile = nil; hasStoredCredential = false; errorMessage = nil
    }

    func enqueue(_ sources: [BunnyUploadSource]) throws {
        try ensureDisk()
        guard let profile, isConfigured else { throw BunnyStorageError.configurationMissing }
        let validated = try profile.validated()
        var updated = jobs
        for source in sources {
            guard !source.fileName.isEmpty, ![".", ".."].contains(source.fileName),
                  !source.fileName.contains("/"), !source.fileName.contains("\\"), source.fileSizeBytes > 0 else {
                throw BunnyStorageError.missingSource
            }
            let path = validated.remotePath(for: source)
            if updated.contains(where: { $0.remoteURL == validated.storageURL(for: path) }) { continue }
            updated.append(BunnyUploadJob(source: source, profile: validated))
        }
        do { try disk.save(BunnyPersistedState(profile: profile, jobs: updated)) }
        catch { throw BunnyStorageError.persistenceFailure }
        jobs = updated; errorMessage = nil
    }

    func start() {
        guard worker == nil, jobs.contains(where: { $0.state == .queued }) else { return }
        guard diskAvailable else { errorMessage = BunnyStorageError.persistenceFailure.localizedDescription; return }
        guard isConfigured else { errorMessage = BunnyStorageError.configurationMissing.localizedDescription; return }
        let token = UUID(); generation = token; isUploading = true
        worker = Task { [weak self] in
            guard let self else { return }
            await self.runQueue(generation: token)
        }
    }

    func cancel(_ jobID: UUID) {
        guard let index = index(jobID), jobs[index].state != .completed else { return }
        if activeJobID == jobID { worker?.cancel() }
        jobs[index].requiresRemoteVerification = jobs[index].requiresRemoteVerification || jobs[index].attempts > 0
        jobs[index].state = .cancelled; jobs[index].errorMessage = nil; jobs[index].updatedAt = Date()
        persistOrReport()
    }
    func cancelAll() { for id in jobs.filter({ $0.state != .completed }).map(\.id) { cancel(id) } }

    func retry(_ jobID: UUID) {
        guard let index = index(jobID), jobs[index].state.canRetry, activeJobID != jobID else { return }
        guard diskAvailable else { errorMessage = BunnyStorageError.persistenceFailure.localizedDescription; return }
        guard let profile, profile.id == jobs[index].profile.id, isConfigured else {
            errorMessage = BunnyStorageError.configurationMissing.localizedDescription; return
        }
        if let date = jobs[index].retryNotBefore, date > Date() {
            errorMessage = BunnyTransferError.rateLimited(retryAfter: date.timeIntervalSinceNow).localizedDescription; return
        }
        jobs[index].state = .queued; jobs[index].errorMessage = nil; jobs[index].bytesSent = 0
        jobs[index].updatedAt = Date(); jobs[index].retryNotBefore = nil
        if persistOrReport() { start() }
    }

    func reselect(_ jobID: UUID, fileURL: URL, grantURL: URL? = nil) throws {
        guard let index = index(jobID), !jobs[index].state.isActive, jobs[index].state != .completed else { return }
        try ensureDisk()
        let captured = try BunnyUploadSource.capture(fileURL: fileURL, grantURL: grantURL)
        var updated = jobs
        if captured.fingerprint != jobs[index].source.fingerprint {
            // Explicitly selecting different bytes creates a fresh destination.
            // Keep the row identity, leave any ambiguous old remote file untouched,
            // and require the user's separate Retry action before any network call.
            var replacement = BunnyUploadJob(id: jobID, source: captured, profile: jobs[index].profile)
            replacement.state = .interrupted
            updated[index] = replacement
        } else {
            // The same file was moved; retain its accepted remote destination.
            updated[index].source = BunnyUploadSource(
                id: jobs[index].source.id, fileName: jobs[index].source.fileName,
                originalURL: captured.originalURL, bookmarkData: captured.bookmarkData,
                relativePath: captured.relativePath, fingerprint: captured.fingerprint)
            updated[index].state = .interrupted; updated[index].errorMessage = nil
        }
        do { try disk.save(BunnyPersistedState(profile: profile, jobs: updated)) }
        catch { throw BunnyStorageError.persistenceFailure }
        jobs = updated
    }

    func remove(_ jobID: UUID) {
        guard let index = index(jobID), !jobs[index].state.isActive, activeJobID != jobID else { return }
        let old = jobs; jobs.remove(at: index)
        if !persistOrReport() { jobs = old }
    }

    private func runQueue(generation token: UUID) async {
        defer {
            if generation == token { activeJobID = nil; isUploading = false; worker = nil }
        }
        while !Task.isCancelled, generation == token,
              let job = jobs.first(where: { $0.state == .queued }) {
            activeJobID = job.id
            await process(job.id, generation: token)
            if !diskAvailable { break }
        }
    }

    private func process(_ jobID: UUID, generation token: UUID) async {
        do {
            try Task.checkCancellation()
            guard let i = index(jobID), let currentProfile = profile,
                  currentProfile.id == jobs[i].profile.id else { throw BunnyStorageError.configurationMissing }
            let password = try credentials.password(for: jobs[i].profile.id)
            guard let password, !password.isEmpty else { throw BunnyStorageError.credentialUnavailable }
            let access: BunnyResolvedSource
            do { access = try sourceAccess.access(jobs[i].source) }
            catch { throw (error as? BunnyStorageError) ?? BunnyStorageError.missingSource }
            defer { withExtendedLifetime(access) {} }
            if let bookmark = access.refreshedBookmark { jobs[i].source.bookmarkData = bookmark }
            try transition(jobID, to: .hashing)
            let checksum = try await hasher.checksum(of: access.fileURL)
            try checkCurrent(jobID, token)
            try verifyFingerprint(jobID, file: access.fileURL)
            guard let current = index(jobID) else { return }
            jobs[current].checksum = checksum
            try persist()
            var failures = 0
            while true {
                try checkCurrent(jobID, token)
                do {
                    guard let j = index(jobID) else { return }
                    let snapshot = jobs[j]
                    try transition(jobID, to: .verifying)
                    let remote = try await transport.verify(fileAt: snapshot.remoteURL, password: password,
                                                            size: snapshot.totalBytes, checksum: checksum)
                    try checkCurrent(jobID, token)
                    try verifyFingerprint(jobID, file: access.fileURL)
                    switch remote {
                    case .matches:
                        try complete(jobID); return
                    case .conflict: throw BunnyStorageError.remoteConflict
                    case .unknown: throw BunnyStorageError.unverifiedUpload
                    case .missing: break
                    }
                    // URLSession opens this file path itself; check identity again
                    // immediately before PUT and use the server-validated SHA256.
                    try verifyFingerprint(jobID, file: access.fileURL)
                    guard let uploadIndex = index(jobID) else { return }
                    jobs[uploadIndex].attempts += 1
                    jobs[uploadIndex].bytesSent = 0
                    jobs[uploadIndex].requiresRemoteVerification = true
                    let attempt = jobs[uploadIndex].attempts
                    try transition(jobID, to: .uploading) // Persist before any network write.
                    try await transport.upload(file: access.fileURL, to: snapshot.remoteURL,
                                               password: password, checksum: checksum) { [weak self] sent, _ in
                        Task { @MainActor in
                            guard let self, self.generation == token, self.activeJobID == jobID,
                                  let index = self.index(jobID), self.jobs[index].state == .uploading,
                                  self.jobs[index].attempts == attempt else { return }
                            self.jobs[index].bytesSent = max(self.jobs[index].bytesSent, min(self.jobs[index].totalBytes, max(0, sent)))
                        }
                    }
                    try checkCurrent(jobID, token)
                    try verifyFingerprint(jobID, file: access.fileURL)
                    try complete(jobID); return
                } catch let error as BunnyTransferError where error.isRetryable && failures < 2 {
                    failures += 1
                    let delay = max(pow(2, Double(failures)), error.retryAfter ?? 0)
                    guard delay.isFinite, delay <= 300 else {
                        if let index = index(jobID) { jobs[index].retryNotBefore = delay.isFinite && delay <= 31_536_000 ? Date().addingTimeInterval(max(0, delay)) : Date.distantFuture }
                        throw error
                    }
                    guard let index = index(jobID) else { return }
                    jobs[index].errorMessage = error.localizedDescription
                    try transition(jobID, to: .waitingToRetry)
                    try await sleep(delay)
                    // Every retry starts with remote verification, never a blind PUT.
                }
            }
        } catch {
            guard let i = index(jobID), generation == token else { return }
            if Task.isCancelled || error is CancellationError {
                if jobs[i].state != .cancelled { jobs[i].state = .interrupted }
                jobs[i].errorMessage = nil
            } else {
                jobs[i].state = (error as? BunnyStorageError == .missingSource || error as? BunnyStorageError == .sourceChanged) ? .needsFile : .failed
                jobs[i].errorMessage = (error as? BunnyStorageError)?.localizedDescription
                    ?? (error as? BunnyTransferError)?.localizedDescription
                    ?? BunnyTransferError.invalidResponse.localizedDescription
            }
            if let cooldown = (error as? BunnyTransferError)?.retryAfter {
                jobs[i].retryNotBefore = cooldown.isFinite && cooldown <= 31_536_000
                    ? Date().addingTimeInterval(max(0, cooldown)) : Date.distantFuture
            }
            jobs[i].updatedAt = Date(); persistOrReport()
        }
    }

    private func checkCurrent(_ id: UUID, _ token: UUID) throws {
        try Task.checkCancellation()
        guard generation == token, activeJobID == id, let index = index(id), jobs[index].state != .cancelled else {
            throw CancellationError()
        }
    }
    private func verifyFingerprint(_ id: UUID, file: URL) throws {
        guard let index = index(id) else { throw CancellationError() }
        do {
            guard try BunnyFileFingerprint.read(file) == jobs[index].source.fingerprint else { throw BunnyStorageError.sourceChanged }
        } catch let error as BunnyStorageError { throw error }
        catch { throw BunnyStorageError.missingSource }
    }
    private func complete(_ id: UUID) throws {
        guard let index = index(id) else { return }
        jobs[index].bytesSent = jobs[index].totalBytes
        jobs[index].requiresRemoteVerification = false; jobs[index].errorMessage = nil; jobs[index].retryNotBefore = nil
        try transition(id, to: .completed)
    }
    private func transition(_ id: UUID, to state: BunnyUploadState) throws {
        guard let index = index(id) else { throw CancellationError() }
        jobs[index].state = state; jobs[index].updatedAt = Date()
        try persist()
    }
    private func index(_ id: UUID) -> Int? { jobs.firstIndex { $0.id == id } }
    private func ensureDisk() throws { guard diskAvailable else { throw BunnyStorageError.persistenceFailure } }
    private func persist() throws {
        try ensureDisk()
        do { try disk.save(BunnyPersistedState(profile: profile, jobs: jobs)) }
        catch { diskAvailable = false; throw BunnyStorageError.persistenceFailure }
    }
    @discardableResult private func persistOrReport() -> Bool {
        do { try persist(); return true }
        catch { errorMessage = BunnyStorageError.persistenceFailure.localizedDescription; return false }
    }
}
