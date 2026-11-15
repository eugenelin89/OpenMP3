import Foundation
import AVFoundation

/// Streams the public download URL directly; no bulk download or private HTTP-header options.
@MainActor public final class NativeAudio: AudioOutput {
    public var onEvent: ((AudioEvent) -> Void)?
    private let player = AVPlayer()
    private var status: NSKeyValueObservation?
    private var endToken: NSObjectProtocol?
    private var failureToken: NSObjectProtocol?
    private var timeToken: Any?
    private var currentID: String?
    public init() {}
    public func start(url: URL, id: String) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        #endif
        player.pause()
        if let timeToken { player.removeTimeObserver(timeToken); self.timeToken = nil }
        status = nil
        if let endToken { NotificationCenter.default.removeObserver(endToken) }
        if let failureToken { NotificationCenter.default.removeObserver(failureToken) }
        currentID = id
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        status = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                switch item.status {
                case .readyToPlay: self.onEvent?(.ready(id: id, duration: item.duration.seconds))
                case .failed: self.onEvent?(.failed(id: id))
                default: break
                }
            }
        }
        endToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.onEvent?(.ended(id: id))
            }
        }
        failureToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.onEvent?(.failed(id: id))
            }
        }
        timeToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak item] time in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.onEvent?(.progress(id: id, seconds: time.seconds))
            }
        }
        player.play()
    }
    public func pause() { player.pause() }
    public func seek(seconds: Double) {
        guard let id = currentID, let item = player.currentItem else { return }
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak item] finished in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.onEvent?(.seeked(id: id, requested: seconds, actual: self.player.currentTime().seconds, finished: finished))
            }
        }
    }
    deinit {
        if let timeToken { player.removeTimeObserver(timeToken) }
        if let endToken { NotificationCenter.default.removeObserver(endToken) }
        if let failureToken { NotificationCenter.default.removeObserver(failureToken) }
    }
}
