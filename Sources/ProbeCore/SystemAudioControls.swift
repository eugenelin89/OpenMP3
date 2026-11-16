#if os(iOS)
import Foundation
import AVFoundation
import MediaPlayer

/// Native events are routed through the same application actions as the screen.
@MainActor final class SystemAudioControls {
    private var commands: [(MPRemoteCommand, Any)] = []
    private var notifications: [NSObjectProtocol] = []
    private let send: (PlayerCommand) -> Void
    init(send: @escaping (PlayerCommand) -> Void) {
        self.send = send
        let center = MPRemoteCommandCenter.shared()
        bind(center.playCommand, .play)
        bind(center.pauseCommand, .pause)
        bind(center.togglePlayPauseCommand, .toggle)
        bind(center.nextTrackCommand, .next)
        bind(center.previousTrackCommand, .previous)
        let seek = center.changePlaybackPositionCommand
        let token = seek.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in send(.seek(event.positionTime)) }
            return .success
        }
        commands.append((seek, token))
        let session = AVAudioSession.sharedInstance()
        notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor in
                send(type == .began ? .interruptionBegan : .interruptionEnded(shouldResume: options.contains(.shouldResume)))
            }
        })
        notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in send(.disconnected) }
        })
    }
    private func bind(_ command: MPRemoteCommand, _ action: PlayerCommand) {
        let token = command.addTarget { [send] _ in
            Task { @MainActor in send(action) }
            return .success
        }
        commands.append((command, token))
    }
    func update(_ playback: PlaybackObservation) {
        for (command, _) in commands { command.isEnabled = !playback.queue.isEmpty }
        guard let current = playback.current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: current.entry.name,
            MPMediaItemPropertyAlbumTitle: "OpenMP3",
            MPMediaItemPropertyPlaybackDuration: playback.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: playback.seconds,
            MPNowPlayingInfoPropertyPlaybackRate: playback.state == "playing" ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: playback.index,
            MPNowPlayingInfoPropertyPlaybackQueueCount: playback.queue.count
        ]
    }
    deinit {
        for (command, token) in commands { command.removeTarget(token) }
        for token in notifications { NotificationCenter.default.removeObserver(token) }
    }
}
#endif
