import CryptoKit
import Foundation

protocol BunnyFileHashing: Sendable {
    func checksum(of file: URL) async throws -> String
}
struct BunnyFileHasher: BunnyFileHashing {
    func checksum(of file: URL) async throws -> String {
        try Task.checkCancellation()
        let task = Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            var hash = SHA256()
            while true {
                try Task.checkCancellation()
                guard let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty else { break }
                hash.update(data: chunk)
            }
            return hash.finalize().map { String(format: "%02X", $0) }.joined()
        }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
}
