import Foundation

public enum AudioEvent {
    case ready(id: String, duration: Double)
    case progress(id: String, seconds: Double)
    case ended(id: String)
    case failed(id: String)
    case seeked(id: String, requested: Double, actual: Double, finished: Bool)
    var id: String {
        switch self {
        case let .ready(id, _), let .progress(id, _), let .ended(id), let .failed(id), let .seeked(id, _, _, _): return id
        }
    }
}

@MainActor public protocol AudioOutput: AnyObject {
    var onEvent: ((AudioEvent) -> Void)? { get set }
    func start(url: URL, id: String) throws
    func pause()
    func seek(seconds: Double)
}

public struct PlaybackObservation {
    public var state = "idle"
    public var queueSource: RootFolder?
    public var queue: [DiscoveredTrack] = []
    public var index = 0
    public var seconds: Double = 0
    public var duration: Double = 0
    public var events: [String] = []
    public var current: DiscoveredTrack? { queue.indices.contains(index) ? queue[index] : nil }
}
