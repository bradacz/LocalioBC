import CryptoKit
import Foundation

protocol BunnyStorageTransport: Sendable {
    func upload(file: URL, to remoteURL: URL, password: String, checksum: String,
                progress: @escaping @Sendable (Int64, Int64) -> Void) async throws
    func verify(fileAt remoteURL: URL, password: String, size: Int64, checksum: String) async throws -> BunnyRemoteFileState
}
enum BunnyRemoteFileState: Sendable { case matches, missing, conflict, unknown }
enum BunnyTransferError: Error, LocalizedError, Sendable {
    case unauthorized, rateLimited(retryAfter: TimeInterval?), temporary(statusCode: Int?)
    case permanent(statusCode: Int), ambiguous, invalidResponse
    var isRetryable: Bool {
        switch self { case .rateLimited, .temporary, .ambiguous: true; default: false }
    }
    var retryAfter: TimeInterval? {
        if case .rateLimited(let seconds) = self { return seconds }
        return nil
    }
    var errorDescription: String? {
        switch self {
        case .unauthorized: tr("Bunny odmítl přístup. Zkontrolujte heslo Storage zóny a její primární region.")
        case .rateLimited: tr("Bunny dočasně omezil požadavky. Nahrávání se zopakuje později.")
        case .temporary, .ambiguous: tr("Připojení k Bunny bylo přerušeno. Před opakováním se ověří vzdálený soubor.")
        case .permanent: tr("Bunny požadavek odmítl. Zkontrolujte nastavení připojení.")
        case .invalidResponse: tr("Bunny vrátil neočekávanou odpověď. Nahrání nelze potvrdit.")
        }
    }
}

/// Every request uses a fresh, nonpersistent session. Credentials never enter a URL,
/// cache, cookie store, logging statement, or redirect to another server.
final class BunnyURLSessionTransport: BunnyStorageTransport, @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration.copy() as! URLSessionConfiguration
        self.configuration.httpCookieStorage = nil
        self.configuration.httpShouldSetCookies = false
        self.configuration.urlCache = nil
        self.configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.configuration.timeoutIntervalForRequest = 90
        self.configuration.timeoutIntervalForResource = 86_400
    }

    func upload(file: URL, to remoteURL: URL, password: String, checksum: String,
                progress: @escaping @Sendable (Int64, Int64) -> Void) async throws {
        var request = try makeRequest(url: remoteURL, password: password, method: "PUT")
        guard checksum.count == 64, checksum.allSatisfy({ $0.isHexDigit }) else { throw BunnyTransferError.invalidResponse }
        request.setValue(checksum.uppercased(), forHTTPHeaderField: "Checksum")
        request.setValue(file.pathExtension.lowercased() == "mov" ? "video/quicktime" : "video/mp4", forHTTPHeaderField: "Content-Type")
        let size = try BunnyFileFingerprint.read(file).size
        request.setValue(String(size), forHTTPHeaderField: "Content-Length")
        let transfer = BunnyHTTPTransfer(progress: progress)
        let (_, response) = try await transfer.perform(configuration: configuration, request: request, file: file)
        guard response.statusCode == 201 else { throw Self.responseError(response) }
    }

    func verify(fileAt remoteURL: URL, password: String, size: Int64, checksum: String) async throws -> BunnyRemoteFileState {
        var directory = remoteURL.deletingLastPathComponent()
        if !directory.absoluteString.hasSuffix("/") { directory = URL(string: directory.absoluteString + "/")! }
        let request = try makeRequest(url: directory, password: password, method: "GET")
        let (data, response) = try await BunnyHTTPTransfer().perform(configuration: configuration, request: request)
        if response.statusCode == 404 { return .missing }
        guard response.statusCode == 200 else { throw Self.responseError(response) }
        let entries: [BunnyDirectoryEntry]
        do { entries = try JSONDecoder().decode([BunnyDirectoryEntry].self, from: data) }
        catch { return .unknown }
        guard let entry = entries.first(where: { $0.ObjectName == remoteURL.lastPathComponent && !$0.IsDirectory }) else { return .missing }
        guard entry.Length == size else { return .conflict }
        if let remoteChecksum = entry.Checksum, remoteChecksum.count == 64 {
            return remoteChecksum.caseInsensitiveCompare(checksum) == .orderedSame ? .matches : .conflict
        }
        // The public listing schema does not guarantee Checksum. Compare a
        // bounded-memory authenticated stream from the same Storage host.
        let fileRequest = try makeRequest(url: remoteURL, password: password, method: "GET")
        let (hashData, fileResponse) = try await BunnyHTTPTransfer(hashingBytes: size)
            .perform(configuration: configuration, request: fileRequest)
        if fileResponse.statusCode == 404 { return .missing }
        guard fileResponse.statusCode == 200 else { throw Self.responseError(fileResponse) }
        guard let downloadedChecksum = String(data: hashData, encoding: .utf8) else { return .unknown }
        return downloadedChecksum.caseInsensitiveCompare(checksum) == .orderedSame ? .matches : .conflict
    }

    private func makeRequest(url: URL, password: String, method: String) throws -> URLRequest {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || url.port == 443,
              BunnyStorageRegion.allCases.contains(where: { $0.endpoint.host == url.host }),
              !password.isEmpty, !password.contains("\r"), !password.contains("\n") else { throw BunnyTransferError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(password, forHTTPHeaderField: "AccessKey")
        return request
    }
    private static func responseError(_ response: HTTPURLResponse) -> BunnyTransferError {
        switch response.statusCode {
        case 401, 403: return .unauthorized
        case 429:
            let header = response.value(forHTTPHeaderField: "Retry-After")
            let seconds: TimeInterval?
            if let header, let value = Double(header), value.isFinite { seconds = max(0, value) }
            else if let header {
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                seconds = formatter.date(from: header).map { max(0, $0.timeIntervalSinceNow) }
            } else { seconds = nil }
            return .rateLimited(retryAfter: seconds)
        case 408, 500...599: return .temporary(statusCode: response.statusCode)
        default: return .permanent(statusCode: response.statusCode)
        }
    }
}

private struct BunnyDirectoryEntry: Decodable {
    let ObjectName: String
    let Length: Int64
    let Checksum: String?
    let IsDirectory: Bool
    enum CodingKeys: String, CodingKey { case ObjectName, Length, Checksum, IsDirectory }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ObjectName = try values.decode(String.self, forKey: .ObjectName)
        Length = try values.decode(Int64.self, forKey: .Length)
        Checksum = try values.decodeIfPresent(String.self, forKey: .Checksum)
        IsDirectory = try values.decodeIfPresent(Bool.self, forKey: .IsDirectory) ?? false
    }
}

/// URLSession delegates are serialized on their session queue; cancellation can
/// arrive concurrently, so shared continuation/task/data state is lock-protected.
private final class BunnyHTTPTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    private var task: URLSessionTask?
    private var session: URLSession?
    private var completed = false
    private var response: HTTPURLResponse?
    private var received = Data()
    private var responseHasher: SHA256?
    private var receivedBytes: Int64 = 0
    private let hashingBytes: Int64?
    private let progress: @Sendable (Int64, Int64) -> Void
    private let maximumResponseBytes = 2_097_152
    init(progress: @escaping @Sendable (Int64, Int64) -> Void = { _, _ in }, hashingBytes: Int64? = nil) {
        self.progress = progress; self.hashingBytes = hashingBytes
        responseHasher = hashingBytes == nil ? nil : SHA256()
    }

    func perform(configuration: URLSessionConfiguration, request: URLRequest, file: URL? = nil) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                guard !completed else { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                let task: URLSessionTask
                if let file { task = session.uploadTask(with: request, fromFile: file) }
                else { task = session.dataTask(with: request) }
                self.task = task
                lock.unlock()
                task.resume()
            }
        } onCancel: { self.finish(.failure(CancellationError())) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        lock.lock(); let active = !completed; lock.unlock()
        if active { progress(totalBytesSent, totalBytesExpectedToSend) }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel); finish(.failure(BunnyTransferError.invalidResponse)); return
        }
        lock.lock(); self.response = http; let active = !completed; lock.unlock()
        completionHandler(active ? .allow : .cancel)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard !completed else { lock.unlock(); return }
        if let hashingBytes, response?.statusCode == 200 {
            guard receivedBytes <= hashingBytes - Int64(data.count) else {
                lock.unlock(); finish(.failure(BunnyTransferError.invalidResponse)); return
            }
            receivedBytes += Int64(data.count); responseHasher?.update(data: data); lock.unlock(); return
        }
        guard received.count + data.count <= maximumResponseBytes else {
            lock.unlock(); finish(.failure(BunnyTransferError.invalidResponse)); return
        }
        received.append(data); lock.unlock()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            if (error as? URLError)?.code == .cancelled { finish(.failure(CancellationError())) }
            else { finish(.failure(BunnyTransferError.ambiguous)) }
            return
        }
        lock.lock()
        let response = self.response
        let byteCountMatches = hashingBytes == nil || receivedBytes == hashingBytes
        let data = responseHasher.map { Data($0.finalize().map { String(format: "%02X", $0) }.joined().utf8) } ?? received
        lock.unlock()
        if response?.statusCode == 200 && !byteCountMatches { finish(.failure(BunnyTransferError.invalidResponse)); return }
        guard let response else { finish(.failure(BunnyTransferError.invalidResponse)); return }
        finish(.success((data, response)))
    }
    private func finish(_ result: Result<(Data, HTTPURLResponse), Error>) {
        lock.lock()
        guard !completed else { lock.unlock(); return }
        completed = true
        let continuation = self.continuation; self.continuation = nil
        let session = self.session; self.session = nil
        let task = self.task; self.task = nil
        lock.unlock()
        task?.cancel(); session?.invalidateAndCancel()
        continuation?.resume(with: result)
    }
}
