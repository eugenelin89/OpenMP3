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

public struct PlaybackObservation {
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
    var history: [Int] = []
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
