import Foundation

public struct HTTPObservation: Codable {
    public let purpose: String
    public let status: Int?
    public let seconds: Double
    public let bytes: Int
    public let redirects: Int
    public let finalHost: String?
    public let contentType: String?
    public let contentRange: String?
    public let acceptRanges: String?
    public let prefixOnly: Bool
    public let failure: String?
}

/// No cookies, login, API key, or content confirmation/restriction bypass.
@MainActor public final class AnonymousDrive: DriveAccess {
    public private(set) var observations: [HTTPObservation] = []
    private let protocolClasses: [AnyClass]?
    public init(protocolClasses: [AnyClass]? = nil) { self.protocolClasses = protocolClasses }

    public func inspectRoot(_ root: RootFolder) async throws -> DriveEntry {
        _ = try await folderPage(root, purpose: "root page")
        return DriveEntry(id: root.id, name: "Public root", mimeType: DriveEntry.folderType, resourceKey: root.resourceKey)
    }

    public func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage {
        guard pageToken == nil else { throw DriveFailure.pagination }
        return try await folderPage(folder, purpose: "folder listing")
    }

    private func folderPage(_ folder: RootFolder, purpose: String) async throws -> DrivePage {
        guard ProbeApplication.validIdentifier(folder.id) else { throw DriveFailure.malformedResponse }
        var url = URLComponents(string: "https://drive.google.com/drive/folders/\(folder.id)")!
        if let key = folder.resourceKey { url.queryItems = [URLQueryItem(name: "resourcekey", value: key)] }
        let (data, response) = try await fetch(URLRequest(url: url.url!), purpose: purpose, maximumBytes: 2_097_152)
        try checkStatus(response)
        guard let html = String(data: data, encoding: .utf8) else { throw DriveFailure.malformedResponse }
        let pattern = #"window\['_DRIVE_ivd'\]\s*=\s*'((?:\\.|[^'\\])*)'"#
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { throw DriveFailure.malformedResponse }
        let json = try decodeJavaScriptString(String(html[range]))
        guard let payload = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [Any] else {
            throw DriveFailure.malformedResponse
        }
        let rows: [[Any]]
        if let entries = payload.first as? [[Any]] { rows = entries }
        else if payload.count == 5, payload.prefix(4).allSatisfy({ $0 is NSNull }), payload[4] is [Any] {
            // Observed on a readable empty public folder; the embedded view also
            // contained no entries. Unknown payload shapes still fail closed.
            rows = []
        } else { throw DriveFailure.malformedResponse }
        let entries = try rows.map { row -> DriveEntry in
            guard row.count >= 4, let id = row[0] as? String, let name = row[2] as? String,
                  let mime = row[3] as? String, ProbeApplication.validIdentifier(id) else { throw DriveFailure.malformedResponse }
            // Only these observed fields are understood. Resource-key propagation and
            // pagination in this undocumented format are NOT established by this probe.
            return DriveEntry(id: id, name: name, mimeType: mime)
        }
        return DrivePage(files: entries, coverageWarning: "Undocumented webpage: pagination and descendant resource keys unverified")
    }

    public func mediaURL(_ track: DiscoveredTrack) throws -> URL {
        guard ProbeApplication.validIdentifier(track.id), track.entry.capabilities?.canDownload != false else {
            throw DriveFailure.restriction
        }
        var url = URLComponents(string: "https://drive.google.com/uc")!
        url.queryItems = [URLQueryItem(name: "export", value: "download"), URLQueryItem(name: "id", value: track.id)]
        if let key = track.entry.resourceKey { url.queryItems?.append(URLQueryItem(name: "resourcekey", value: key)) }
        return url.url!
    }

    /// Explicit measurement only: never invoked by scanning. Does not download a track.
    public func sampleMedia(_ track: DiscoveredTrack, offset: Int = 0) async throws {
        guard offset >= 0, offset <= Int.max - 1023 else { throw DriveFailure.malformedResponse }
        var request = URLRequest(url: try mediaURL(track))
        request.setValue("bytes=\(offset)-\(offset + 1023)", forHTTPHeaderField: "Range")
        let (_, response) = try await fetch(request, purpose: "media range at \(offset)", maximumBytes: 65_536, allowPrefix: true)
        try checkStatus(response)
        guard response.statusCode == 206, response.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(offset)-") == true,
              response.mimeType == "audio/mpeg" || response.mimeType == "application/octet-stream" else {
            throw DriveFailure.malformedResponse
        }
    }

    private func checkStatus(_ response: HTTPURLResponse) throws {
        if response.statusCode == 429 || (500...599).contains(response.statusCode) { throw DriveFailure.transient }
        guard (200...299).contains(response.statusCode) else { throw DriveFailure.access }
    }

    private func fetch(_ request: URLRequest, purpose: String, maximumBytes: Int, allowPrefix: Bool = false) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = protocolClasses
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        let redirectObserver = RedirectObserver()
        let session = URLSession(configuration: configuration, delegate: redirectObserver, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let started = ProcessInfo.processInfo.systemUptime
        var data = Data()
        var response: HTTPURLResponse?
        var prefixOnly = false
        do {
            let (bytes, rawResponse) = try await session.bytes(for: request)
            guard let http = rawResponse as? HTTPURLResponse else { throw DriveFailure.malformedResponse }
            response = http
            for try await byte in bytes {
                try Task.checkCancellation()
                if data.count == maximumBytes {
                    prefixOnly = true
                    if allowPrefix { break }
                    throw DriveFailure.experimentalLimit
                }
                data.append(byte)
            }
            record(failure: nil)
            return (data, http)
        } catch {
            record(failure: Task.isCancelled ? "cancelled" : "transport or response failure")
            if Task.isCancelled { throw CancellationError() }
            if error is URLError { throw DriveFailure.transient }
            throw error
        }
        func record(failure: String?) {
            observations.append(HTTPObservation(purpose: purpose, status: response?.statusCode,
                seconds: ProcessInfo.processInfo.systemUptime - started, bytes: data.count,
                redirects: redirectObserver.redirectCount, finalHost: response?.url?.host,
                contentType: response?.mimeType, contentRange: response?.value(forHTTPHeaderField: "Content-Range"),
                acceptRanges: response?.value(forHTTPHeaderField: "Accept-Ranges"), prefixOnly: prefixOnly, failure: failure))
        }
    }

    /// Decode a string literal, never execute Google scripts. Schema changes fail closed.
    private func decodeJavaScriptString(_ raw: String) throws -> String {
        let chars = Array(raw.unicodeScalars)
        var result = "", i = 0
        while i < chars.count {
            let char = chars[i]; i += 1
            if char != "\\" { result.unicodeScalars.append(char); continue }
            guard i < chars.count else { throw DriveFailure.malformedResponse }
            let escape = chars[i]; i += 1
            if escape == "x" || escape == "u" {
                let count = escape == "x" ? 2 : 4
                guard i + count <= chars.count,
                      var value = UInt32(String(String.UnicodeScalarView(chars[i..<i+count])), radix: 16) else { throw DriveFailure.malformedResponse }
                i += count
                if escape == "u", (0xD800...0xDBFF).contains(value) {
                    guard i + 6 <= chars.count, chars[i] == "\\", chars[i + 1] == "u",
                          let low = UInt32(String(String.UnicodeScalarView(chars[i+2..<i+6])), radix: 16),
                          (0xDC00...0xDFFF).contains(low) else { throw DriveFailure.malformedResponse }
                    value = 0x10000 + (value - 0xD800) * 0x400 + low - 0xDC00
                    i += 6
                }
                guard let scalar = UnicodeScalar(value) else { throw DriveFailure.malformedResponse }
                result.unicodeScalars.append(scalar)
            } else {
                switch escape {
                case "\\", "'", "\"", "/": result.unicodeScalars.append(escape)
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "b": result.append("\u{8}")
                case "f": result.append("\u{c}")
                default: throw DriveFailure.malformedResponse
                }
            }
        }
        return result
    }
}

private final class RedirectObserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var redirectCount: Int { lock.lock(); defer { lock.unlock() }; return count }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        lock.lock(); count += 1; let allowedCount = count <= 5; lock.unlock()
        let host = request.url?.host ?? ""
        let allowedHost = host == "drive.google.com" || host == "drive.usercontent.google.com" || host.hasSuffix(".googleusercontent.com")
        completionHandler(allowedCount && allowedHost && request.url?.scheme == "https" ? request : nil)
    }
}
