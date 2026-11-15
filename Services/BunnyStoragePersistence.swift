import Foundation
import Security

protocol BunnyCredentialStore: Sendable {
    func password(for profileID: UUID) throws -> String?
    func save(password: String, for profileID: UUID) throws
    func deletePassword(for profileID: UUID) throws
}

struct BunnyKeychainCredentialStore: BunnyCredentialStore {
    let service: String
    init(service: String = (Bundle.main.bundleIdentifier ?? "com.localiobvideo.app") + ".bunny-storage") {
        self.service = service
    }
    private func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString.lowercased()]
    }
    func password(for profileID: UUID) throws -> String? {
        var request = query(profileID)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data,
              let password = String(data: data, encoding: .utf8) else { throw BunnyStorageError.credentialUnavailable }
        return password
    }
    func save(password: String, for profileID: UUID) throws {
        let data = Data(password.utf8)
        let status = SecItemUpdate(query(profileID) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query(profileID)
            request[kSecValueData as String] = data
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw BunnyStorageError.credentialUnavailable }
        } else if status != errSecSuccess { throw BunnyStorageError.credentialUnavailable }
    }
    func deletePassword(for profileID: UUID) throws {
        let status = SecItemDelete(query(profileID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw BunnyStorageError.credentialUnavailable }
    }
}

protocol BunnyUploadDiskStore: Sendable {
    func load() throws -> BunnyPersistedState
    func save(_ state: BunnyPersistedState) throws
}
struct BunnyJSONUploadDiskStore: BunnyUploadDiskStore {
    let fileURL: URL
    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? base.appendingPathComponent("LocalioBC/BunnyStorage/uploads.json")
    }
    func load() throws -> BunnyPersistedState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return BunnyPersistedState(profile: nil, jobs: []) }
        return try JSONDecoder().decode(BunnyPersistedState.self, from: Data(contentsOf: fileURL))
    }
    func save(_ state: BunnyPersistedState) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
