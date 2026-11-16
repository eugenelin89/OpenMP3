import Foundation

public enum AudioEvent {
    case ready(id: String, duration: Double)
    case progress(id: String, seconds: Double)
    case ended(id: String)
    case failed(id: String)
    case unavailable(id: String)
    case seeked(id: String, requested: Double, actual: Double, finished: Bool)
    var id: String {
        switch self {
        case let .ready(id, _), let .progress(id, _), let .ended(id), let .failed(id), let .unavailable(id), let .seeked(id, _, _, _): return id
        }
    }
}

@MainActor public protocol AudioOutput: AnyObject {
    var onCommand: ((PlayerCommand) -> Void)? { get set }
    func updateNowPlaying(_ playback: PlaybackObservation)
    var onEvent: ((AudioEvent) -> Void)? { get set }
    func start(url: URL, id: String, playing: Bool) throws
    func resume() throws
    func pause()
    func seek(seconds: Double)
}

public enum RepeatMode: String, CaseIterable { case off, all, one }

public struct ReadyCollection {
    public let root: RootFolder
    public let name: String
    public let tracks: [DiscoveredTrack]
    public internal(set) var order: [DiscoveredTrack]
    public internal(set) var index = 0
    var highWaterIndex = 0
    var history = [0]
    var historyPosition = 0
    mutating func next(repeatMode: RepeatMode) {
        if historyPosition + 1 < history.count {
            historyPosition += 1
            index = history[historyPosition]
        } else if index + 1 < order.count || repeatMode == .all {
            index = (index + 1) % order.count
            highWaterIndex = max(highWaterIndex, index)
            history.append(index)
            historyPosition = history.count - 1
        }
    }
    mutating func previous() {
        guard historyPosition > 0 else { return }
        historyPosition -= 1
        index = history[historyPosition]
    }
    mutating func setShuffle(_ enabled: Bool, shuffled: ([DiscoveredTrack]) -> [DiscoveredTrack]) {
        order = reorderedUpcoming(order, canonical: tracks, visitedThrough: highWaterIndex,
                                  shuffle: enabled ? shuffled : { $0 })
    }
    public var selected: DiscoveredTrack { order[index] }
}

public struct PlaybackObservation {
    public internal(set) var ready: ReadyCollection?
    public var displayTrack: DiscoveredTrack? { ready?.selected ?? current }
    public var displayState: String { ready == nil ? state : "ready" }
    public var displaySource: String { ready.map { "Ready: " + $0.name } ?? (queue.isEmpty ? "Load a folder to prepare music" : "Queue source · " + sourceName) }
    public var canPlay: Bool { ready != nil || !queue.isEmpty }
    public var hasResumableCurrent: Bool {
        current != nil && !["unavailable", "failed", "ended"].contains(state)
    }

    public var shuffle = false
    public var repeatMode = RepeatMode.off
    public var unavailableIDs: Set<String> = []
    public var message: String?
    var retries = 0
    var resumePosition: Double?
    var needsRetry = false
    var canonicalQueue: [DiscoveredTrack] = []
    public var state = "idle"
    public var sourceName = "No queue"
    public var queueSource: RootFolder?
    public var queue: [DiscoveredTrack] = []
    public var index = 0
    public var seconds: Double = 0
    public var duration: Double = 0
    var history: [String] = []
    var highWaterIndex = 0
    var lastEndedID: String?
    var historyPosition = 0
    var wantsPlayback = false
    public var events: [String] = []
    mutating func record(_ message: String) {
        events.append(message)
        if events.count > 200 { events.removeFirst(events.count - 200) }
    }
    public var current: DiscoveredTrack? { queue.indices.contains(index) ? queue[index] : nil }
}

public enum PlayerCommand {
    case play, pause, toggle, next, previous, seek(Double)
    case interruptionBegan, interruptionEnded(shouldResume: Bool), disconnected
}

extension AudioOutput {
    public func updateNowPlaying(_ playback: PlaybackObservation) {}
}

/// Preserve visited entries while ordering only the unvisited suffix.
func reorderedUpcoming(_ order: [DiscoveredTrack], canonical: [DiscoveredTrack],
                       visitedThrough: Int, shuffle: ([DiscoveredTrack]) -> [DiscoveredTrack]) -> [DiscoveredTrack] {
    let boundary = visitedThrough + 1
    let remainingIDs = Set(order.dropFirst(boundary).map(\.id))
    return Array(order.prefix(boundary)) + shuffle(canonical.filter { remainingIDs.contains($0.id) })
}
