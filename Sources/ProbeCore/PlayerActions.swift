import Foundation

extension ProbeApplication {
    public var canPlayCollection: Bool {
        ["complete", "incomplete"].contains(scanObservation.state) && !tracks.isEmpty
    }
    public func playAll() { if let first = tracks.first { playTrack(id: first.id) } }
    public func playTrack(id: String) {
        guard canPlayCollection, let index = tracks.firstIndex(where: { $0.id == id }), audio != nil else { return }
        let shuffle = playback.shuffle, repeatMode = playback.repeatMode
        playback = PlaybackObservation()
        playback.shuffle = shuffle; playback.repeatMode = repeatMode
        playback.canonicalQueue = tracks
        playback.queueSource = selectedRoot
        playback.sourceName = selectedRootName
        playback.queue = shuffle ? [tracks[index]] + shuffled(tracks.filter { $0.id != id }) : tracks
        playback.index = shuffle ? 0 : index
        playback.history = [playback.index]
        playback.wantsPlayback = true
        startCurrent()
    }
    public func play() {
        guard !playback.queue.isEmpty else { return }
        playback.wantsPlayback = true
        guard !interrupted else { return }
        if playback.needsRetry { retryPlayback(); return }
        if playback.current == nil || playback.state == "unavailable" {
            newCycle()
        } else {
            do { try audio?.resume(); playback.state = "playing" }
            catch { recoverTemporaryFailure() }
        }
    }
    public func pause() {
        playback.wantsPlayback = false
        audio?.pause()
        if playback.current != nil { playback.state = "paused" }
    }
    public func seek(seconds: Double) {
        guard playback.current != nil, seconds.isFinite, seconds >= 0, playback.duration > 0 else { return }
        let target = min(seconds, playback.duration)
        playback.seconds = target
        audio?.seek(seconds: target)
    }
    public func next() {
        guard let previous = playback.current else { return }
        if playback.historyPosition + 1 < playback.history.count {
            playback.historyPosition += 1
            playback.index = playback.history[playback.historyPosition]
        } else {
            playback.index += 1
            while let track = playback.current, playback.unavailableIDs.contains(track.id) { playback.index += 1 }
            if playback.current != nil {
                playback.history.append(playback.index)
                playback.historyPosition = playback.history.count - 1
            }
        }
        if playback.current == nil {
            if playback.repeatMode == .all { newCycle(avoiding: previous.id) }
            else { audio?.pause(); playback.wantsPlayback = false; playback.state = "ended" }
        }
        else { startCurrent() }
    }
    public func previous() {
        guard playback.current != nil else { return }
        if playback.seconds >= 3 || playback.historyPosition == 0 { seek(seconds: 0) }
        else {
            playback.historyPosition -= 1
            playback.index = playback.history[playback.historyPosition]
            startCurrent()
        }
    }
    func startCurrent(preservingPosition: Bool = false, retrying: Bool = false) {
        guard let current = playback.current, let audio, let drive else { return }
        if !retrying { playback.retries = 0 }
        playback.needsRetry = false; playback.message = nil
        playback.resumePosition = preservingPosition && playback.seconds > 0 ? playback.seconds : nil
        if !preservingPosition { playback.seconds = 0; playback.duration = 0 }
        playback.state = playback.wantsPlayback ? "loading" : "paused"
        playback.record("Load queue item \(playback.index + 1)")
        do { try audio.start(url: drive.mediaURL(current), id: current.id, playing: playback.wantsPlayback && !interrupted && playback.resumePosition == nil) }
        catch { recoverTemporaryFailure() }
    }
    public func receive(_ event: AudioEvent) {
        guard event.id == playback.current?.id else { return }
        switch event {
        case let .ready(_, duration):
            playback.duration = duration.isFinite ? duration : 0
            playback.record("Native item ready; audible playback unconfirmed")
            if let position = playback.resumePosition { audio?.seek(seconds: min(position, playback.duration)) }
        case let .progress(_, seconds):
            guard seconds.isFinite else { return }
            if seconds > playback.seconds, playback.wantsPlayback { playback.state = "playing" }
            playback.seconds = seconds
        case .ended:
            playback.record("Natural end of queue item \(playback.index + 1)")
            if playback.repeatMode == .one { startCurrent() } else { next() }
        case .failed:
            recoverTemporaryFailure()
        case .unavailable:
            if let current = playback.current { playback.unavailableIDs.insert(current.id) }
            if playback.canonicalQueue.allSatisfy({ playback.unavailableIDs.contains($0.id) }) {
                audio?.pause(); playback.wantsPlayback = false; playback.state = "unavailable"
                playback.message = "No playable tracks remain. Rescan or choose another collection."
            } else { next() }
        case let .seeked(_, requested, actual, finished):
            playback.record(String(format: "Seek %@: requested %.1fs, actual %.1fs", finished ? "completed" : "failed", requested, actual))
            if playback.resumePosition != nil {
                playback.resumePosition = nil
                if finished {
                    if playback.wantsPlayback && !interrupted {
                        do { try audio?.resume() } catch { recoverTemporaryFailure() }
                    }
                } else { recoverTemporaryFailure() }
            }
        }
    }
}

extension ProbeApplication {
    public func handle(_ command: PlayerCommand) {
        switch command {
        case .play: play()
        case .pause: pause()
        case .toggle: playback.wantsPlayback ? pause() : play()
        case .next: next()
        case .previous: previous()
        case let .seek(seconds): seek(seconds: seconds)
        case .interruptionBegan:
            interrupted = true
            audio?.pause()
            if playback.current != nil { playback.state = "paused" }
        case let .interruptionEnded(shouldResume):
            guard interrupted else { return }
            interrupted = false
            if shouldResume && playback.wantsPlayback { play() } else { pause() }
        case .disconnected: pause()
        }
    }
}

extension ProbeApplication {
    public func shuffleAll() { setShuffle(true); playAll() }
    public func setRepeat(_ mode: RepeatMode) { playback.repeatMode = mode }
    public func setShuffle(_ enabled: Bool) {
        playback.shuffle = enabled
        guard playback.current != nil else { return }
        let boundary = (playback.history.max() ?? playback.index) + 1
        let prefix = Array(playback.queue.prefix(boundary))
        let rest = Array(playback.queue.dropFirst(boundary))
        let remainingIDs = Set(rest.map(\.id))
        playback.queue = prefix + (enabled ? shuffled(rest) : playback.canonicalQueue.filter { remainingIDs.contains($0.id) })
    }
    func newCycle(avoiding last: String? = nil) {
        let playable = playback.canonicalQueue.filter { !playback.unavailableIDs.contains($0.id) }
        guard !playable.isEmpty else {
            playback.wantsPlayback = false; playback.state = "unavailable"
            playback.message = "No playable tracks remain. Choose a collection to try again."
            return
        }
        playback.queue = playback.shuffle ? shuffled(playable) : playable
        if playback.shuffle, playback.queue.count > 1, playback.queue.first?.id == last {
            playback.queue.swapAt(0, 1)
        }
        playback.index = 0
        playback.history = playback.queue.isEmpty ? [] : [0]
        playback.historyPosition = 0
        startCurrent()
    }
}

extension ProbeApplication {
    public func retryPlayback() {
        guard playback.current != nil else { return }
        playback.wantsPlayback = true
        playback.retries = 0
        startCurrent(preservingPosition: true, retrying: true)
    }
    private func recoverTemporaryFailure() {
        audio?.pause()
        playback.needsRetry = true
        if playback.retries < 1 && playback.wantsPlayback && !interrupted {
            playback.retries += 1
            startCurrent(preservingPosition: true, retrying: true)
        } else {
            playback.wantsPlayback = false
            playback.state = "failed"
            playback.message = "Playback could not continue. Check your connection, then Retry."
        }
    }
}
