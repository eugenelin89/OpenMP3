import Foundation

extension ProbeApplication {
    public var canPlayCollection: Bool {
        ["complete", "incomplete"].contains(scanObservation.state) && !tracks.isEmpty
    }
    public var isPlaybackRequested: Bool { playback.wantsPlayback }
    public func playAll() {
        guard canPlayCollection, audio != nil else { return }
        beginQueue(playback.shuffle ? shuffled(tracks) : tracks, starting: 0)
    }
    public func playTrack(id: String) {
        guard canPlayCollection, let index = tracks.firstIndex(where: { $0.id == id }), audio != nil else { return }
        let ordered = playback.shuffle ? [tracks[index]] + shuffled(tracks.filter { $0.id != id }) : tracks
        beginQueue(ordered, starting: playback.shuffle ? 0 : index)
    }
    private func beginQueue(_ ordered: [DiscoveredTrack], starting index: Int, snapshot: CollectionSnapshot? = nil, playing: Bool = true) {
        let shuffle = playback.shuffle, repeatMode = playback.repeatMode
        playback = PlaybackObservation()
        playback.shuffle = shuffle; playback.repeatMode = repeatMode
        playback.canonicalQueue = snapshot?.tracks ?? tracks
        playback.queueSource = snapshot?.root ?? selectedRoot
        playback.sourceName = snapshot?.name ?? selectedRootName
        playback.queue = ordered
        playback.index = index
        playback.highWaterIndex = index
        playback.history = [ordered[index].id]
        playback.wantsPlayback = playing
        startCurrent()
    }
    public func play() {
        if let ready = playback.ready {
            guard audio != nil else { return }
            beginQueue(ready.order, starting: ready.index, snapshot: ready.collection)
            return
        }
        guard !playback.queue.isEmpty else { return }
        playback.wantsPlayback = true
        guard !interrupted else { return }
        if playback.needsRetry { retryPlayback(); return }
        if playback.current == nil || playback.state == "unavailable" {
            newCycle(avoiding: playback.lastEndedID)
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
        if playback.ready != nil {
            let mode = playback.repeatMode
            playback.ready?.next(repeatMode: mode)
            return
        }
        if consumePending() { return }
        advanceWithinQueue()
    }
    private func consumePending() -> Bool {
        guard let pending = playback.pending else { return false }
        beginQueue(playback.shuffle ? shuffled(pending.tracks) : pending.tracks, starting: 0,
                   snapshot: pending, playing: playback.wantsPlayback)
        return true
    }
    private func advanceWithinQueue() {
        guard let previous = playback.current else { return }
        while playback.historyPosition + 1 < playback.history.count {
            playback.historyPosition += 1
            if activateHistoryTrack(playback.history[playback.historyPosition]) { return }
        }
        playback.index = playback.highWaterIndex + 1
        while let track = playback.current, playback.unavailableIDs.contains(track.id) { playback.index += 1 }
        if let current = playback.current {
            playback.highWaterIndex = playback.index
            playback.history.append(current.id)
            playback.historyPosition = playback.history.count - 1
            startCurrent()
        } else {
            playback.lastEndedID = previous.id
            if playback.repeatMode == .all { newCycle(avoiding: previous.id) }
            else { audio?.pause(); playback.wantsPlayback = false; playback.state = "ended" }
        }
    }
    public func previous() {
        if playback.ready != nil { playback.ready?.previous(); return }
        guard playback.current != nil else { return }
        if playback.seconds >= 3 || playback.historyPosition == 0 { seek(seconds: 0); return }
        let originalPosition = playback.historyPosition
        while playback.historyPosition > 0 {
            playback.historyPosition -= 1
            if activateHistoryTrack(playback.history[playback.historyPosition]) { return }
        }
        playback.historyPosition = originalPosition
        seek(seconds: 0)
    }
    private func activateHistoryTrack(_ id: String) -> Bool {
        guard !playback.unavailableIDs.contains(id), let index = playback.queue.firstIndex(where: { $0.id == id }) else { return false }
        // A replay from an older cycle becomes visited in this cycle, so a later
        // shuffle cannot move the current track or automatically replay it again.
        if index > playback.highWaterIndex {
            let track = playback.queue.remove(at: index)
            playback.highWaterIndex += 1
            playback.queue.insert(track, at: playback.highWaterIndex)
            playback.index = playback.highWaterIndex
        } else { playback.index = index }
        startCurrent()
        return true
    }
    func startCurrent(preservingPosition: Bool = false, retrying: Bool = false) {
        guard let current = playback.current, let audio, let drive else { return }
        let generation = UUID()
        audioGeneration = generation
        audio.onEvent = { [weak self] event in
            guard let self, self.audioGeneration == generation else { return }
            self.receive(event)
        }
        if !retrying { playback.retries = 0 }
        playback.needsRetry = false; playback.message = nil
        playback.resumePosition = preservingPosition && playback.seconds > 0 ? playback.seconds : nil
        if !preservingPosition { playback.seconds = 0; playback.duration = 0 }
        playback.state = playback.wantsPlayback ? "loading" : "paused"
        playback.record("Load queue item \(playback.index + 1)")
        do { try audio.start(url: drive.mediaURL(current), id: current.id, playing: playback.wantsPlayback && !interrupted && playback.resumePosition == nil) }
        catch { recoverTemporaryFailure() }
    }
    func receive(_ event: AudioEvent) {
        guard event.id == playback.current?.id else { return }
        switch event {
        case let .ready(_, duration):
            playback.duration = duration.isFinite ? duration : 0
            playback.record("Native item ready; audible playback unconfirmed")
            if let position = playback.resumePosition { audio?.seek(seconds: playback.duration > 0 ? min(position, playback.duration) : position) }
        case let .progress(_, seconds):
            guard seconds.isFinite, playback.resumePosition == nil else { return }
            if seconds > playback.seconds, playback.wantsPlayback { playback.state = "playing" }
            playback.seconds = seconds
        case .ended:
            playback.record("Natural end of queue item \(playback.index + 1)")
            if consumePending() { return }
            if playback.repeatMode == .one { startCurrent() } else { advanceWithinQueue() }
        case .failed:
            recoverTemporaryFailure()
        case .unavailable:
            if let current = playback.current { playback.unavailableIDs.insert(current.id) }
            if playback.canonicalQueue.allSatisfy({ playback.unavailableIDs.contains($0.id) }) {
                audio?.pause(); playback.wantsPlayback = false; playback.state = "unavailable"
                playback.message = "No playable tracks remain. Rescan or choose another collection."
            } else { advanceWithinQueue() }
        case let .seeked(_, requested, actual, finished):
            playback.record(String(format: "Seek %@: requested %.1fs, actual %.1fs", finished ? "completed" : "failed", requested, actual))
            if playback.resumePosition != nil {
                if finished {
                    playback.resumePosition = nil
                    if actual.isFinite { playback.seconds = max(0, actual) }
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
        playback.ready?.setShuffle(enabled, shuffled: shuffled)
        guard playback.current != nil else { return }
        playback.queue = reorderedUpcoming(playback.queue, canonical: playback.canonicalQueue,
                                           visitedThrough: playback.highWaterIndex,
                                           shuffle: enabled ? shuffled : { $0 })
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
        playback.highWaterIndex = 0
        playback.history.append(playback.queue[0].id)
        playback.historyPosition = playback.history.count - 1
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
