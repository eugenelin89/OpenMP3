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
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = playback.canPlay
        center.pauseCommand.isEnabled = playback.canPause
        center.togglePlayPauseCommand.isEnabled = playback.canPause || playback.canPlay
        center.nextTrackCommand.isEnabled = playback.canNext
        center.previousTrackCommand.isEnabled = playback.canPrevious
        center.changePlaybackPositionCommand.isEnabled = playback.canSeek
        guard let current = playback.displayTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: current.entry.name,
            MPMediaItemPropertyAlbumTitle: playback.displaySourceName,
            MPMediaItemPropertyPlaybackDuration: playback.displayDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: playback.displaySeconds,
            MPNowPlayingInfoPropertyPlaybackRate: playback.displayRate,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: playback.displayIndex,
            MPNowPlayingInfoPropertyPlaybackQueueCount: playback.displayCount
        ]
    }
    deinit {
        for (command, token) in commands { command.removeTarget(token) }
        for token in notifications { NotificationCenter.default.removeObserver(token) }
    }
}
#endif
