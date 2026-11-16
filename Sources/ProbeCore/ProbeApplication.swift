import Foundation
import Combine

public struct RootFolder: Equatable {
    public let id: String
    public let resourceKey: String?
}

@MainActor public final class ProbeApplication: ObservableObject {
    @Published public private(set) var selectedRoot: RootFolder?
    @Published public private(set) var error: String?
    @Published public private(set) var tracks: [DiscoveredTrack] = []
    @Published public private(set) var failedFolderPaths: [[String]] = []
    @Published public private(set) var scanObservation = ScanObservation()
    @Published public private(set) var playback = PlaybackObservation()
    private let audio: AudioOutput?
    private let drive: DriveAccess?
    private let now: () -> Double
    private var scanTask: Task<Void, Never>?
    private var stopReason = "Scan stopped"
    public init(drive: DriveAccess? = nil, audio: AudioOutput? = nil, now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.drive = drive; self.audio = audio; self.now = now
        audio?.onEvent = { [weak self] event in self?.receive(event) }
    }
    public func playAll() {
        guard scanObservation.state == "complete" || scanObservation.state == "incomplete", !tracks.isEmpty, audio != nil else { return }
        playback = PlaybackObservation()
        playback.queueSource = selectedRoot
        playback.queue = tracks
        startCurrent()
    }
    public func seek(seconds: Double) {
        guard playback.current != nil, seconds.isFinite, seconds >= 0, playback.duration > 0 else { return }
        audio?.seek(seconds: min(seconds, playback.duration))
    }
    public func pause() { audio?.pause(); playback.state = "paused" }
    public func next() {
        guard playback.current != nil else { return }
        playback.index += 1
        if playback.current == nil { audio?.pause(); playback.state = "ended" }
        else { startCurrent() }
    }
    private func startCurrent() {
        guard let current = playback.current, let audio, let drive else { return }
        playback.seconds = 0; playback.duration = 0; playback.state = "loading"
        playback.events.append("Load queue item \(playback.index + 1)")
        do { try audio.start(url: drive.mediaURL(current), id: current.id) }
        catch { playback.state = "failed"; playback.events.append("Media access failed") }
    }
    public func receive(_ event: AudioEvent) {
        guard event.id == playback.current?.id else { return }
        switch event {
        case let .ready(_, duration):
            playback.duration = duration.isFinite ? duration : 0
            playback.events.append("Native item ready; audible playback unconfirmed")
        case let .progress(_, seconds):
            guard seconds.isFinite else { return }
            if seconds > playback.seconds, playback.state != "paused" { playback.state = "playing" }
            playback.seconds = seconds
        case .ended:
            playback.events.append("Natural end of queue item \(playback.index + 1)")
            next()
        case .failed:
            audio?.pause(); playback.state = "failed"
            playback.events.append("Native playback failed; inspect device evidence")
        case let .seeked(_, requested, actual, finished):
            playback.events.append(String(format: "Seek %@: requested %.1fs, actual %.1fs", finished ? "completed" : "failed", requested, actual))
        }
    }
    public func stopScan(backgrounded: Bool = false) {
        stopReason = backgrounded ? "App left foreground" : "Scan stopped"
        scanTask?.cancel()
    }
    public func scan(controls: ExperimentControls = ExperimentControls()) async {
        guard let root = selectedRoot, let drive, scanObservation.state != "scanning", scanTask == nil else { return }
        guard controls.isValid else { error = "Invalid experimental controls"; return }
        scanTask = Task { await self.performScan(root: root, drive: drive, controls: controls) }
        await withTaskCancellationHandler(operation: { await scanTask?.value }, onCancel: {
            Task { @MainActor in self.stopScan() }
        })
        scanTask = nil
    }

    private func performScan(root: RootFolder, drive: DriveAccess, controls: ExperimentControls) async {
        let started = now()
        let deadline = started + controls.seconds
        tracks = []
        failedFolderPaths = []
        scanObservation = ScanObservation()
        scanObservation.state = "scanning"
        error = nil
        do {
            let metadata = try await request(listing: false, controls: controls, deadline: deadline) {
                try await drive.inspectRoot(root)
            }
            guard metadata.mimeType == DriveEntry.folderType else { throw DriveFailure.access }
            var pending: [(RootFolder, [String])] = [(root, [])]
            var folders: Set<String> = [root.id]
            var files: Set<String> = []
            while !pending.isEmpty {
                let (folder, path) = pending.removeFirst()
                scanObservation.folders += 1
                var token: String?
                var tokens: Set<String> = []
                do {
                    repeat {
                        let page = try await request(listing: true, controls: controls, deadline: deadline) {
                            try await drive.list(folder, pageToken: token)
                        }
                        if let warning = page.coverageWarning, !scanObservation.reasons.contains(warning) { scanObservation.reasons.append(warning) }
                        if page.incompleteSearch == true { scanObservation.reasons.append("Drive reported incomplete search") }
                        for entry in page.files {
                            try checkTime(deadline)
                            if entry.mimeType == DriveEntry.shortcutType { scanObservation.shortcuts += 1; continue }
                            if entry.mimeType == DriveEntry.folderType {
                                if !folders.contains(entry.id) {
                                    guard folders.count < controls.folders else { throw ScanLimit(reason: "Experimental folder limit") }
                                    folders.insert(entry.id)
                                    pending.append((RootFolder(id: entry.id, resourceKey: entry.resourceKey), path + [entry.name]))
                                }
                            } else if entry.name.lowercased().hasSuffix(".mp3") || entry.mimeType == "audio/mpeg" {
                                if !files.contains(entry.id) {
                                    guard tracks.count < controls.tracks else { throw ScanLimit(reason: "Experimental track limit") }
                                    files.insert(entry.id)
                                    tracks.append(DiscoveredTrack(entry: entry, path: path))
                                }
                            } else { scanObservation.ignoredFiles += 1 }
                        }
                        token = page.nextPageToken
                        if let token, !tokens.insert(token).inserted { throw DriveFailure.malformedResponse }
                    } while token != nil
                } catch let failure as DriveFailure where folder.id != root.id && [.access, .malformedResponse, .restriction].contains(failure) {
                    failedFolderPaths.append(path)
                    scanObservation.reasons.append("Unreadable descendant at depth \(path.count); accessible siblings retained")
                }
            }
        } catch {
            if error is CancellationError || Task.isCancelled { self.error = stopReason }
            else if let limit = error as? ScanLimit { self.error = limit.reason }
            else if error as? DriveFailure == .experimentalLimit { self.error = "Experimental response-size limit" }
            else if error as? DriveFailure == .transient { self.error = "Temporary network or quota failure; retry controls exhausted" }
            else { self.error = "Drive access or response failure" }
            scanObservation.reasons.append(self.error!)
        }
        tracks.sort {
            let left = $0.path.joined(separator: "/"), right = $1.path.joined(separator: "/")
            if left != right { return left.localizedStandardCompare(right) == .orderedAscending }
            if $0.entry.name != $1.entry.name { return $0.entry.name.localizedStandardCompare($1.entry.name) == .orderedAscending }
            return $0.id < $1.id
        }
        scanObservation.elapsedSeconds = max(0, now() - started)
        scanObservation.state = scanObservation.reasons.isEmpty ? "complete" : "incomplete"
    }

    private struct ScanLimit: Error { let reason: String }
    private func checkTime(_ deadline: Double) throws {
        try Task.checkCancellation()
        if now() >= deadline { throw ScanLimit(reason: "Experimental wall-clock limit") }
    }

    private func request<T>(listing: Bool, controls: ExperimentControls, deadline: Double,
                            operation: @escaping @MainActor () async throws -> T) async throws -> T {
        var retries = 0
        while true {
            try checkTime(deadline)
            if listing {
                guard scanObservation.listingRequests < controls.listingRequests else {
                    throw ScanLimit(reason: "Experimental listing-request limit")
                }
                scanObservation.listingRequests += 1
            } else { scanObservation.metadataRequests += 1 }
            do {
                let remaining = deadline - now()
                let value = try await withThrowingTaskGroup(of: T.self) { group in
                    group.addTask { try await operation() }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(max(0, min(remaining, 86_400)) * 1_000_000_000))
                        throw ScanLimit(reason: "Experimental wall-clock limit")
                    }
                    defer { group.cancelAll() }
                    return try await group.next()!
                }
                try checkTime(deadline)
                return value
            } catch DriveFailure.transient {
                guard retries < controls.retriesPerRequest, scanObservation.retries < controls.totalRetries else {
                    throw DriveFailure.transient
                }
                retries += 1
                scanObservation.retries += 1
                try checkTime(deadline)
                try await Task.sleep(nanoseconds: UInt64(min(controls.retryDelay, max(0, deadline - now()), 86_400) * 1_000_000_000))
            }
        }
    }
    public func selectRoot(_ input: String) {
        guard scanObservation.state != "scanning", scanTask == nil else { return }
        tracks = []
        failedFolderPaths = []
        scanObservation = ScanObservation()
        selectedRoot = nil
        error = "Invalid Google Drive folder link"
        guard let url = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host == "drive.google.com",
              url.user == nil, url.password == nil, url.port == nil else { return }
        let parts = url.path.split(separator: "/").map(String.init)
        let keys = (url.queryItems ?? []).filter { $0.name == "resourcekey" }
        guard keys.count <= 1 else { return }
        let id: String?
        if parts.count >= 3, parts.first == "drive", parts[parts.count - 2] == "folders",
           parts.count == 3 || (parts.count == 5 && parts[1] == "u" && Int(parts[2]) != nil) {
            id = parts.last
        } else if url.path == "/open" {
            let ids = (url.queryItems ?? []).filter { $0.name == "id" }
            id = ids.count == 1 ? ids.first?.value : nil
        } else { return }
        let key = keys.first?.value
        guard let id, Self.validIdentifier(id), keys.isEmpty || (key.map(Self.validIdentifier) ?? false) else { return }
        selectedRoot = RootFolder(id: id, resourceKey: key)
        error = nil
    }

    static func validIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }
}
