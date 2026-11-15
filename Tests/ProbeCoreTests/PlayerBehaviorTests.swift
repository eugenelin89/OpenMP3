import XCTest
@testable import ProbeCore

final class PlayerBehaviorTests: XCTestCase {
    @MainActor func testTrackTapAndPausedTransportKeepQueueSource() async {
        let drive = FixtureDrive()
        drive.pages["a:"] = DrivePage(files: (1...3).map { DriveEntry(id: "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        let app = ProbeApplication(drive: drive, audio: FixtureAudio())
        app.selectRoot("https://drive.google.com/drive/folders/a")
        await app.scan()
        XCTAssertNil(app.playback.current)
        app.playTrack(id: "2")
        XCTAssertEqual(app.playback.current?.id, "2")
        app.pause(); app.next()
        XCTAssertEqual(app.playback.current?.id, "3")
        XCTAssertEqual(app.playback.state, "paused")
        app.previous()
        XCTAssertEqual(app.playback.current?.id, "2")
        app.selectRoot("https://drive.google.com/drive/folders/b")
        app.play()
        XCTAssertEqual(app.playback.queueSource?.id, "a")
        XCTAssertEqual(app.playback.current?.id, "2")
        app.receive(.progress(id: "2", seconds: 4))
        app.previous()
        XCTAssertEqual(app.playback.current?.id, "2")
        XCTAssertEqual(app.playback.seconds, 0)
    }
}

extension PlayerBehaviorTests {
    @MainActor func testInterruptionsAndDisconnectRespectExplicitPause() async {
        let drive = FixtureDrive()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "song", name: "song.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive, audio: FixtureAudio())
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.playAll()
        app.handle(.interruptionBegan)
        XCTAssertEqual(app.playback.state, "paused")
        app.handle(.interruptionEnded(shouldResume: true))
        XCTAssertEqual(app.playback.state, "playing")
        app.handle(.interruptionBegan); app.pause()
        app.handle(.interruptionEnded(shouldResume: true))
        XCTAssertEqual(app.playback.state, "paused")
        app.play(); app.handle(.disconnected)
        XCTAssertEqual(app.playback.state, "paused")
        app.handle(.interruptionEnded(shouldResume: true))
        XCTAssertEqual(app.playback.state, "paused")
    }
}

extension PlayerBehaviorTests {
    @MainActor func testShuffleHistoryAndRepeatCyclesDoNotChangeCurrentPosition() async {
        let drive = FixtureDrive()
        drive.pages["a:"] = DrivePage(files: (1...4).map { DriveEntry(id: "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        let app = ProbeApplication(drive: drive, audio: FixtureAudio(), shuffled: { Array($0.reversed()) })
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.playAll()
        app.next(); app.receive(.progress(id: "2", seconds: 8))
        app.setShuffle(true)
        XCTAssertEqual(app.playback.current?.id, "2")
        XCTAssertEqual(app.playback.seconds, 8)
        XCTAssertEqual(Set(app.playback.queue.map(\.id)), Set(["1", "2", "3", "4"]))
        app.setShuffle(false)
        XCTAssertEqual(app.playback.queue.map(\.id), ["1", "2", "3", "4"])
        app.setRepeat(.one)
        app.receive(.ended(id: "2"))
        XCTAssertEqual(app.playback.current?.id, "2")
        app.next(); XCTAssertEqual(app.playback.current?.id, "3")
        app.next(); app.next(); XCTAssertNil(app.playback.current)
        app.selectRoot("https://drive.google.com/drive/folders/b")
        app.handle(.toggle); XCTAssertEqual(app.playback.queueSource?.id, "a")
        XCTAssertNotNil(app.playback.current)
        app.setShuffle(true); app.setRepeat(.all)
        var last = ""
        for _ in 0..<4 {
            guard let current = app.playback.current else { XCTFail("Queue exhausted under Repeat All"); return }
            last = current.id; app.next()
        }
        XCTAssertNotEqual(app.playback.current?.id, last)
        XCTAssertEqual(Set(app.playback.queue.map(\.id)), Set(["1", "2", "3", "4"]))
        app.playTrack(id: "3") // Unscanned B cannot replace the active queue.
        XCTAssertEqual(app.playback.queueSource?.id, "a")
    }
}

@MainActor private final class MemoryRoots: RootStorage {
    var snapshot = SavedRootState()
    func load() throws -> SavedRootState { snapshot }
    func save(_ state: SavedRootState) throws { snapshot = state }
}
extension PlayerBehaviorTests {
    @MainActor func testSavedRootsReuseSessionCollectionsButColdLaunchRestoresNoQueue() async {
        let drive = FixtureDrive(), storage = MemoryRoots()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "one", name: "one.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive, audio: FixtureAudio(), storage: storage)
        app.selectRoot("https://drive.google.com/drive/folders/a?resourcekey=key")
        app.saveSelectedRoot(name: "Morning")
        await app.scan(); app.playAll()
        app.selectRoot("https://drive.google.com/drive/folders/b"); app.saveSelectedRoot(name: "Evening")
        app.selectSavedRoot(id: "a")
        XCTAssertEqual(app.tracks.map(\.id), ["one"])
        drive.pages["a:"] = DrivePage(files: [])
        await app.scan()
        XCTAssertTrue(app.tracks.isEmpty)
        XCTAssertEqual(app.playback.current?.id, "one")
        app.removeSavedRoot(id: "a")
        XCTAssertNil(app.selectedRoot)
        XCTAssertEqual(app.playback.queueSource?.id, "a")
        XCTAssertEqual(app.playback.sourceName, "Morning")
        app.selectSavedRoot(id: "b")
        let relaunched = ProbeApplication(drive: drive, audio: FixtureAudio(), storage: storage)
        XCTAssertEqual(relaunched.selectedRoot?.id, "b")
        XCTAssertEqual(relaunched.savedRoots.map(\.name), ["Evening"])
        XCTAssertTrue(relaunched.tracks.isEmpty)
        XCTAssertTrue(relaunched.playback.queue.isEmpty)
    }
}

extension PlayerBehaviorTests {
    @MainActor func testUnavailableTracksStopAcrossRepeatAndTemporaryFailurePreservesPosition() async {
        let drive = FixtureDrive()
        drive.pages["a:"] = DrivePage(files: (1...2).map { DriveEntry(id: "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        let app = ProbeApplication(drive: drive, audio: FixtureAudio())
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.playAll(); app.setRepeat(.all)
        app.receive(.unavailable(id: "1"))
        XCTAssertEqual(app.playback.current?.id, "2")
        app.receive(.unavailable(id: "2"))
        XCTAssertEqual(app.playback.state, "unavailable")
        XCTAssertEqual(app.playback.unavailableIDs, Set(["1", "2"]))
        app.playAll(); app.receive(.progress(id: "1", seconds: 12))
        app.receive(.failed(id: "1")) // One immediate bounded re-prepare.
        XCTAssertEqual(app.playback.current?.id, "1")
        XCTAssertEqual(app.playback.seconds, 12)
        app.receive(.failed(id: "1"))
        XCTAssertEqual(app.playback.state, "failed")
        XCTAssertEqual(app.playback.seconds, 12)
        app.pause(); app.receive(.ready(id: "1", duration: 120))
        XCTAssertEqual(app.playback.state, "paused")
        app.retryPlayback()
        XCTAssertEqual(app.playback.current?.id, "1")
        XCTAssertEqual(app.playback.seconds, 12)
        XCTAssertEqual(app.playback.queueSource?.id, "a")
    }
}

extension PlayerBehaviorTests {
    @MainActor func testSingleTrackRepeatAndShuffleTapWhilePaused() async {
        let drive = FixtureDrive()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "only", name: "only.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive, audio: FixtureAudio())
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.shuffleAll()
        app.setRepeat(.one); app.receive(.ended(id: "only"))
        XCTAssertEqual(app.playback.current?.id, "only")
        app.pause(); app.next()
        XCTAssertNil(app.playback.current)
        app.play(); app.setRepeat(.all); app.pause(); app.next()
        XCTAssertEqual(app.playback.current?.id, "only")
        XCTAssertEqual(app.playback.state, "paused")
        app.receive(.unavailable(id: "only")); app.play()
        XCTAssertEqual(app.playback.state, "unavailable")
        XCTAssertEqual(app.playback.queue.count, 1)
    }
}
