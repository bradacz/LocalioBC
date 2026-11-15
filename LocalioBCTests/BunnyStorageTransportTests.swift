import CryptoKit
import Foundation
import XCTest
@testable import LocalioBC

final class BunnyStorageTransportTests: XCTestCase {
    func testPUTUsesZonePasswordChecksumMIMEAndAllowedRegionalHost() async throws {
        let data = Data("synthetic video bytes".utf8)
        let file = try fixture(data, extension: "mov"); defer { try? FileManager.default.removeItem(at: file) }
        let recorder = BunnyRequestRecorder()
        BunnyMockURLProtocol.install { request in recorder.add(request); return BunnyMockReply(status: 201) }
        let checksum = sha256(data)
        try await transport().upload(file: file, to: URL(string: "https://ny.storage.bunnycdn.com/zone/folder/file.mov")!,
                                     password: "synthetic-zone-password", checksum: checksum, progress: { _, _ in })
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.host, "ny.storage.bunnycdn.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "AccessKey"), "synthetic-zone-password")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Checksum"), checksum)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "video/quicktime")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Length"), String(data.count))
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        XCTAssertNil(request.url?.query)
    }

    func testListingWithoutChecksumFallsBackToBoundedStreamingSHA256() async throws {
        let data = Data(repeating: 79, count: 3_000_017) // Larger than metadata response cap.
        let recorder = BunnyRequestRecorder()
        let listing = try JSONSerialization.data(withJSONObject: [["ObjectName": "movie.mp4", "Length": data.count, "IsDirectory": false]])
        let chunks = stride(from: 0, to: data.count, by: 65536).map { data.subdata(in: $0..<min(data.count, $0 + 65536)) }
        BunnyMockURLProtocol.install { request in
            recorder.add(request)
            return BunnyMockReply(status: 200, chunks: request.url!.absoluteString.hasSuffix("/") ? [listing] : chunks)
        }
        let result = try await transport().verify(fileAt: URL(string: "https://storage.bunnycdn.com/zone/unique/movie.mp4")!,
                                                  password: "synthetic-password", size: Int64(data.count), checksum: sha256(data))
        switch result { case .matches: break; default: XCTFail("Remote streaming checksum should match") }
        XCTAssertEqual(recorder.requests.count, 2)
        XCTAssertEqual(recorder.requests.map(\.httpMethod), ["GET", "GET"])
        XCTAssertTrue(recorder.requests.allSatisfy { $0.url?.host == "storage.bunnycdn.com" })
    }

    func testRateLimitAndRedirectNeverForwardCredentialToAnotherHost() async throws {
        let file = try fixture(Data([1, 2, 3])); defer { try? FileManager.default.removeItem(at: file) }
        let recorder = BunnyRequestRecorder()
        BunnyMockURLProtocol.install { request in recorder.add(request); return BunnyMockReply(status: 429, headers: ["Retry-After": "120"]) }
        let url = URL(string: "https://storage.bunnycdn.com/zone/file.mp4")!
        do {
            try await transport().upload(file: file, to: url, password: "synthetic-password", checksum: sha256(Data([1,2,3])), progress: { _, _ in })
            XCTFail("429 must be surfaced")
        } catch let error as BunnyTransferError {
            XCTAssertEqual(error.retryAfter, 120); XCTAssertTrue(error.isRetryable)
        }
        BunnyMockURLProtocol.install { request in recorder.add(request); return BunnyMockReply(status: 302, headers: ["Location": "https://untrusted.example.com/steal"]) }
        do {
            try await transport().upload(file: file, to: url, password: "synthetic-password", checksum: sha256(Data([1,2,3])), progress: { _, _ in })
            XCTFail("A redirect is not upload success")
        } catch let error as BunnyTransferError { XCTAssertFalse(error.isRetryable) }
        let count = recorder.requests.count
        do {
            try await transport().upload(file: file, to: URL(string: "https://untrusted.example.com/steal")!,
                                         password: "synthetic-password", checksum: sha256(Data([1,2,3])), progress: { _, _ in })
            XCTFail("Credential host must be allowlisted")
        } catch { }
        XCTAssertEqual(recorder.requests.count, count)
        XCTAssertTrue(recorder.requests.allSatisfy { $0.url?.host == "storage.bunnycdn.com" })
    }

    func testStreamingVerificationPreservesRateLimitWhenErrorBodyExceedsFileSize() async throws {
        let listing = try JSONSerialization.data(withJSONObject: [["ObjectName": "tiny.mp4", "Length": 3, "IsDirectory": false]])
        BunnyMockURLProtocol.install { request in
            if request.url!.absoluteString.hasSuffix("/") { return BunnyMockReply(status: 200, chunks: [listing]) }
            return BunnyMockReply(status: 429, headers: ["Retry-After": "180"], chunks: [Data(repeating: 88, count: 200)])
        }
        do {
            _ = try await transport().verify(fileAt: URL(string: "https://storage.bunnycdn.com/zone/tiny.mp4")!,
                                              password: "synthetic-password", size: 3, checksum: String(repeating: "A", count: 64))
            XCTFail("429 should retain its cooldown, rather than becoming a size error")
        } catch let error as BunnyTransferError {
            XCTAssertTrue(error.isRetryable); XCTAssertEqual(error.retryAfter, 180)
        }
    }

    func testCancellingARealURLSessionUploadCompletesWithoutWaitingForResponse() async throws {
        let file = try fixture(Data(repeating: 1, count: 2048)); defer { try? FileManager.default.removeItem(at: file) }
        let recorder = BunnyRequestRecorder()
        BunnyMockURLProtocol.install(onStop: { recorder.stopped() }) { request in
            recorder.add(request); return BunnyMockReply(status: 200, hold: true)
        }
        let client = transport()
        let task = Task {
            try await client.upload(file: file, to: URL(string: "https://storage.bunnycdn.com/zone/pending.mp4")!,
                                    password: "synthetic-password", checksum: String(repeating: "A", count: 64), progress: { _, _ in })
        }
        try await wait { recorder.requests.count == 1 }
        task.cancel()
        do { try await task.value; XCTFail("Cancelled upload must throw") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await wait { recorder.stopCount > 0 }
    }

    private func transport() -> BunnyURLSessionTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BunnyMockURLProtocol.self]
        return BunnyURLSessionTransport(configuration: configuration)
    }
    private func fixture(_ data: Data, extension ext: String = "mp4") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BunnyHTTP-\(UUID().uuidString).\(ext)")
        try data.write(to: url); return url
    }
    private func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02X", $0) }.joined() }
    private func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition() {
            guard ContinuousClock.now < deadline else { throw NSError(domain: "BunnyHTTPTimeout", code: 1) }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
}

private struct BunnyMockReply: Sendable {
    let status: Int
    var headers: [String: String] = [:]
    var chunks: [Data] = []
    var hold = false
}
private final class BunnyRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []
    private var stops = 0
    var requests: [URLRequest] { lock.withLock { stored } }
    var stopCount: Int { lock.withLock { stops } }
    func add(_ request: URLRequest) { lock.withLock { stored.append(request) } }
    func stopped() { lock.withLock { stops += 1 } }
}
private final class BunnyMockURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: (@Sendable (URLRequest) throws -> BunnyMockReply)?
    nonisolated(unsafe) private static var onStop: (@Sendable () -> Void)?
    static func install(onStop: (@Sendable () -> Void)? = nil, handler: @escaping @Sendable (URLRequest) throws -> BunnyMockReply) {
        lock.withLock { self.handler = handler; self.onStop = onStop }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.lock.withLock({ Self.handler }) else { throw BunnyTransferError.invalidResponse }
            let reply = try handler(request)
            if reply.hold { return }
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in reply.chunks { client?.urlProtocol(self, didLoad: chunk) }
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { Self.lock.withLock { Self.onStop }?() }
}
