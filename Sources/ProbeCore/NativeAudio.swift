import Foundation
import AVFoundation
#if os(iOS)
import MediaPlayer
#endif

/// Streams the public download URL directly; no bulk download or private HTTP-header options.
@MainActor public final class NativeAudio: AudioOutput {
    public var onCommand: ((PlayerCommand) -> Void)?
    #if os(iOS)
    private var system: SystemAudioControls?
    #endif
    public var onEvent: ((AudioEvent) -> Void)?
    private let player = AVPlayer()
    private var status: NSKeyValueObservation?
    private var endToken: NSObjectProtocol?
    private var failureToken: NSObjectProtocol?
    private var timeToken: Any?
    private var currentID: String?
    public init() {
        #if os(iOS)
        system = SystemAudioControls { [weak self] command in self?.onCommand?(command) }
        #endif
    }
    public func updateNowPlaying(_ playback: PlaybackObservation) {
        #if os(iOS)
        system?.update(playback)
        #endif
    }
    public func start(url: URL, id: String, playing: Bool) throws {
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
                case .failed: self.reportFailure(item: item, id: id)
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
                self.reportFailure(item: item, id: id)
            }
        }
        timeToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak item] time in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                self.onEvent?(.progress(id: id, seconds: time.seconds))
            }
        }
        if playing { player.play() }
    }
    public func resume() throws {
        #if os(iOS)
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
        player.play()
    }
    private func reportFailure(item: AVPlayerItem, id: String) {
        let error = item.error as NSError?
        let statuses = item.errorLog()?.events.map(\.errorStatusCode) ?? []
        // HTTP access/quota failures can be temporary, including Google's 403 responses.
        let temporaryHTTP = statuses.contains { $0 == 403 || $0 == 429 || $0 >= 500 }
        let missingHTTP = statuses.contains { $0 == 404 || $0 == 410 }
        let provenDecodeFailure = error?.domain == AVFoundationErrorDomain &&
            [AVError.Code.decodeFailed.rawValue, AVError.Code.decoderNotFound.rawValue].contains(error?.code ?? 0)
        onEvent?(!temporaryHTTP && (missingHTTP || provenDecodeFailure) ? .unavailable(id: id) : .failed(id: id))
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
