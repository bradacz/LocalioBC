import Foundation

/// The primary region of the user's Storage Zone (not its replication regions).
enum BunnyStorageRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case frankfurt = "de", london = "uk", newYork = "ny", losAngeles = "la"
    case singapore = "sg", stockholm = "se", saoPaulo = "br", johannesburg = "jh", sydney = "syd"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .frankfurt: "Frankfurt (DE)"
        case .london: "London (UK)"
        case .newYork: "New York (US)"
        case .losAngeles: "Los Angeles (US)"
        case .singapore: "Singapore (SG)"
        case .stockholm: "Stockholm (SE)"
        case .saoPaulo: "São Paulo (BR)"
        case .johannesburg: "Johannesburg (ZA)"
        case .sydney: "Sydney (AU)"
        }
    }
    var endpoint: URL {
        URL(string: rawValue == "de" ? "https://storage.bunnycdn.com" : "https://\(rawValue).storage.bunnycdn.com")!
    }
}

struct BunnyStorageProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var zoneName: String
    var region: BunnyStorageRegion
    var remoteFolder: String
    var cdnBaseURL: URL

    init(id: UUID = UUID(), zoneName: String, region: BunnyStorageRegion = .frankfurt,
         remoteFolder: String = "", cdnBaseURL: URL) {
        self.id = id; self.zoneName = zoneName; self.region = region
        self.remoteFolder = remoteFolder; self.cdnBaseURL = cdnBaseURL
    }

    func validated() throws -> Self {
        var value = self
        value.zoneName = zoneName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.zoneName.isEmpty,
              value.zoneName.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }),
              value.zoneName.utf8.count <= 63 else { throw BunnyStorageError.invalidZone }
        let components = remoteFolder.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard components.allSatisfy({ $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) }) else {
            throw BunnyStorageError.invalidFolder
        }
        value.remoteFolder = components.joined(separator: "/")
        guard let url = URLComponents(url: cdnBaseURL, resolvingAgainstBaseURL: false),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || url.port == 443,
              !url.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw BunnyStorageError.invalidCDNURL
        }
        return value
    }

    func remotePath(for source: BunnyUploadSource) -> String {
        ([remoteFolder, source.id.uuidString.lowercased(), source.fileName]).filter { !$0.isEmpty }.joined(separator: "/")
    }
    func storageURL(for source: BunnyUploadSource) -> URL { storageURL(for: remotePath(for: source)) }
    func storageURL(for remotePath: String) -> URL {
        remotePath.split(separator: "/").reduce(region.endpoint.appendingPathComponent(zoneName)) {
            $0.appendingPathComponent(String($1))
        }
    }
    func publicURL(for source: BunnyUploadSource) -> URL { publicURL(for: remotePath(for: source)) }
    func publicURL(for remotePath: String) -> URL {
        remotePath.split(separator: "/").reduce(cdnBaseURL) { $0.appendingPathComponent(String($1)) }
    }
}

struct BunnyFileFingerprint: Codable, Equatable, Sendable {
    let size: Int64
    let modifiedAt: Date
    let inode: UInt64?
    let device: UInt64?

    static func read(_ url: URL) throws -> Self {
        guard url.isFileURL else { throw BunnyStorageError.missingSource }
        let values = try FileManager.default.attributesOfItem(atPath: url.path)
        guard values[.type] as? FileAttributeType == .typeRegular,
              let size = values[.size] as? NSNumber, size.int64Value > 0,
              let date = values[.modificationDate] as? Date else { throw BunnyStorageError.missingSource }
        return Self(size: size.int64Value, modifiedAt: date,
                    inode: (values[.systemFileNumber] as? NSNumber)?.uint64Value,
                    device: (values[.systemNumber] as? NSNumber)?.uint64Value)
    }
}

/// A durable read grant captured while the export's original save-panel grant is active.
struct BunnyUploadSource: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let fileName: String
    let originalURL: URL
    var bookmarkData: Data
    let relativePath: String?
    var fingerprint: BunnyFileFingerprint
    var fileSizeBytes: Int64 { fingerprint.size }

    static func capture(fileURL: URL, grantURL: URL? = nil) throws -> Self {
        let grant = grantURL ?? fileURL
        let started = grant.startAccessingSecurityScopedResource()
        defer { if started { grant.stopAccessingSecurityScopedResource() } }
        let file = fileURL.standardizedFileURL
        let grantValues = try grant.resourceValues(forKeys: [.isDirectoryKey])
        let relativePath: String?
        if grantValues.isDirectory == true {
            let parent = grant.resolvingSymlinksInPath().standardizedFileURL.pathComponents
            let child = file.resolvingSymlinksInPath().pathComponents
            guard child.count > parent.count, Array(child.prefix(parent.count)) == parent else {
                throw BunnyStorageError.missingSource
            }
            relativePath = child.dropFirst(parent.count).joined(separator: "/")
        } else {
            guard grant.standardizedFileURL == file else { throw BunnyStorageError.missingSource }
            relativePath = nil
        }
        let data = try grant.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                          includingResourceValuesForKeys: nil, relativeTo: nil)
        return Self(id: UUID(), fileName: file.lastPathComponent, originalURL: file,
                    bookmarkData: data, relativePath: relativePath,
                    fingerprint: try BunnyFileFingerprint.read(file))
    }
}

/// Kept alive until hashing/upload/verification finishes; never serialized as an open grant.
final class BunnyResolvedSource: @unchecked Sendable {
    let fileURL: URL
    let refreshedBookmark: Data?
    private let grantURL: URL?
    private let didStart: Bool

    init(fileURL: URL, grantURL: URL? = nil, refreshedBookmark: Data? = nil) {
        self.fileURL = fileURL; self.grantURL = grantURL; self.refreshedBookmark = refreshedBookmark
        didStart = grantURL?.startAccessingSecurityScopedResource() ?? false
    }
    deinit { if didStart { grantURL?.stopAccessingSecurityScopedResource() } }
}

protocol BunnySourceAccessing: Sendable {
    func access(_ source: BunnyUploadSource) throws -> BunnyResolvedSource
}
struct BunnyBookmarkSourceAccess: BunnySourceAccessing {
    func access(_ source: BunnyUploadSource) throws -> BunnyResolvedSource {
        var stale = false
        let grant = try URL(resolvingBookmarkData: source.bookmarkData,
                            options: [.withSecurityScope, .withoutUI], relativeTo: nil,
                            bookmarkDataIsStale: &stale)
        let started = grant.startAccessingSecurityScopedResource()
        defer { if started { grant.stopAccessingSecurityScopedResource() } }
        let file: URL
        if let relative = source.relativePath {
            let parts = relative.split(separator: "/")
            guard !parts.isEmpty, !parts.contains(where: { $0 == "." || $0 == ".." }) else { throw BunnyStorageError.missingSource }
            file = parts.reduce(grant) { $0.appendingPathComponent(String($1)) }
        } else { file = grant }
        guard FileManager.default.isReadableFile(atPath: file.path) else { throw BunnyStorageError.missingSource }
        guard try BunnyFileFingerprint.read(file) == source.fingerprint else { throw BunnyStorageError.sourceChanged }
        let refreshed = stale ? try grant.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil) : nil
        return BunnyResolvedSource(fileURL: file, grantURL: grant, refreshedBookmark: refreshed)
    }
}

enum BunnyUploadState: String, Codable, CaseIterable, Sendable {
    case queued, hashing, uploading, verifying, waitingToRetry, completed, failed, cancelled, interrupted, needsFile
    var isActive: Bool { [.hashing, .uploading, .verifying, .waitingToRetry].contains(self) }
    var canRetry: Bool { [.failed, .cancelled, .interrupted, .needsFile].contains(self) }
}
struct BunnyUploadJob: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var source: BunnyUploadSource
    let profile: BunnyStorageProfile
    let remotePath: String
    var state: BunnyUploadState = .queued
    var bytesSent: Int64 = 0
    var checksum: String?
    var errorMessage: String?
    var attempts = 0
    var retryNotBefore: Date?
    let createdAt: Date
    var updatedAt: Date
    /// A PUT may have reached the server even if its acknowledgement was lost.
    var requiresRemoteVerification = false
    var totalBytes: Int64 { source.fileSizeBytes }
    var progress: Double { state == .completed ? 1 : min(1, max(0, Double(bytesSent) / Double(max(1, totalBytes)))) }
    var publicURL: URL { profile.publicURL(for: remotePath) }
    var remoteURL: URL { profile.storageURL(for: remotePath) }

    init(id: UUID = UUID(), source: BunnyUploadSource, profile: BunnyStorageProfile, now: Date = Date()) {
        self.id = id; self.source = source; self.profile = profile
        remotePath = profile.remotePath(for: source); createdAt = now; updatedAt = now
    }
}

struct BunnyPersistedState: Codable, Sendable {
    var profile: BunnyStorageProfile?
    var jobs: [BunnyUploadJob]
}

enum BunnyStorageError: Error, LocalizedError, Equatable, Sendable {
    case invalidZone, invalidFolder, invalidCDNURL, missingPassword, missingSource, sourceChanged
    case configurationMissing, credentialUnavailable, persistenceFailure, remoteConflict, unverifiedUpload, profileBusy
    var errorDescription: String? {
        switch self {
        case .invalidZone: tr("Zadejte platný název Bunny Storage zóny.")
        case .invalidFolder: tr("Cílová složka nesmí obsahovat tečky, zpětná lomítka ani řídicí znaky.")
        case .invalidCDNURL: tr("Zadejte úplnou HTTPS adresu CDN bez hesla, dotazu a fragmentu.")
        case .missingPassword: tr("Zadejte heslo Storage zóny, nikoli hlavní API klíč účtu.")
        case .missingSource: tr("Výstupní soubor není dostupný. Vyberte jej znovu.")
        case .sourceChanged: tr("Výstupní soubor se změnil. Před nahráním jej vyberte znovu.")
        case .configurationMissing: tr("Nejprve nastavte připojení k Bunny Storage.")
        case .credentialUnavailable: tr("Heslo Storage zóny není dostupné v Klíčence. Uložte je znovu v nastavení.")
        case .persistenceFailure: tr("Frontu nahrávání se nepodařilo uložit. Zkontrolujte volné místo a zkuste to znovu.")
        case .remoteConflict: tr("V cíli již existuje jiný soubor. Nebyl přepsán.")
        case .unverifiedUpload: tr("Stav vzdáleného souboru nelze ověřit. Zkuste ověření znovu.")
        case .profileBusy: tr("Před změnou připojení dokončete nebo zrušte čekající nahrávání.")
        }
    }
}
