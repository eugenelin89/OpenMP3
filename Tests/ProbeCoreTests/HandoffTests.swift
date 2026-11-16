import XCTest
@testable import ProbeCore

final class HandoffTests: XCTestCase {
    @MainActor func testNaturalEndConsumesPendingOnceAndResetsSourceHistory() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        for root in ["a", "b"] {
            drive.pages[root + ":"] = DrivePage(files: (1...2).map { DriveEntry(id: root + "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        }
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
        audio.emit(.progress(id: "a1", seconds: 12))
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        XCTAssertEqual(app.playback.current?.id, "a1")
        XCTAssertEqual(app.playback.seconds, 12)
        XCTAssertEqual(audio.starts.count, 1)
        audio.emit(.ended(id: "a1"))
        XCTAssertEqual(app.playback.queueSource?.id, "b")
        XCTAssertEqual(app.playback.current?.id, "b1")
        audio.emit(.ended(id: "a1"))
        XCTAssertEqual(audio.starts.count, 2)
        app.previous(); XCTAssertEqual(app.playback.current?.id, "b1")
        audio.emit(.ended(id: "b1"))
        XCTAssertEqual(app.playback.current?.id, "b2")
    }
}

extension HandoffTests {
    @MainActor func testSameIdentityOldCompletionCannotAdvanceNewCollection() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "same", name: "1.mp3", mimeType: "audio/mpeg")])
        drive.pages["b:"] = DrivePage(files: [DriveEntry(id: "same", name: "1.mp3", mimeType: "audio/mpeg"), DriveEntry(id: "second", name: "2.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
        let oldCompletion = audio.callbacks[0]
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        oldCompletion(.ended(id: "same"))
        XCTAssertEqual(app.playback.queueSource?.id, "b")
        oldCompletion(.ended(id: "same"))
        oldCompletion(.failed(id: "same"))
        oldCompletion(.progress(id: "same", seconds: 99))
        XCTAssertEqual(app.playback.current?.id, "same")
        XCTAssertEqual(app.playback.seconds, 0)
        XCTAssertEqual(audio.starts.count, 2)
        audio.callbacks.last?(.ended(id: "same"))
        XCTAssertEqual(app.playback.current?.id, "second")
    }
}

extension HandoffTests {
    @MainActor func testPausedNextAndRepeatShuffleUseHandoffModesAndKeepAControls() async {
        for mode in RepeatMode.allCases {
            let drive = FixtureDrive(), audio = RecordingAudio()
            for root in ["a", "b"] { drive.pages[root + ":"] = DrivePage(files: (1...3).map { DriveEntry(id: root + "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") }) }
            let app = ProbeApplication(drive: drive, audio: audio, shuffled: { Array($0.reversed()) })
            app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play(); app.next()
            app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
            XCTAssertEqual(app.playback.pending?.root.id, "b")
            app.handle(.pause); app.handle(.play); app.handle(.pause); app.handle(.previous)
            XCTAssertEqual(app.playback.current?.id, "a1")
            XCTAssertEqual(app.playback.pending?.root.id, "b")
            app.setShuffle(true); app.setRepeat(mode)
            audio.onCommand?(.next)
            XCTAssertEqual(app.playback.queueSource?.id, "b")
            XCTAssertEqual(app.playback.current?.id, "b3")
            XCTAssertEqual(app.playback.state, "paused")
            XCTAssertEqual(audio.starts.last?.playing, false)
            XCTAssertNil(app.playback.pending)
            XCTAssertEqual(app.playback.repeatMode, mode)
            app.previous(); XCTAssertEqual(app.playback.current?.id, "b3")
            app.play(); audio.emit(.ended(id: "b3"))
            XCTAssertEqual(app.playback.current?.id, mode == .one ? "b3" : "b2")
        }
    }

    @MainActor func testNaturalHandoffOverridesRepeatAndRecoverySkipStaysInA() async {
        for mode in RepeatMode.allCases {
            let drive = FixtureDrive(), audio = RecordingAudio()
            for root in ["a", "b"] { drive.pages[root + ":"] = DrivePage(files: (1...2).map { DriveEntry(id: root + "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") }) }
            let app = ProbeApplication(drive: drive, audio: audio)
            app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
            app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan(); app.setRepeat(mode)
            audio.emit(.unavailable(id: "a1"))
            XCTAssertEqual(app.playback.current?.id, "a2")
            XCTAssertEqual(app.playback.pending?.root.id, "b")
            audio.emit(.ended(id: "a2"))
            XCTAssertEqual(app.playback.current?.id, "b1")
            XCTAssertNil(app.playback.pending)
            XCTAssertTrue(app.isPlaybackRequested)
            XCTAssertEqual(app.playback.repeatMode, mode)
        }
    }

    @MainActor func testPendingSurvivesSuspendedEmptyAndFailedScansThenReplaces() async {
        let drive = SuspendedDrive(), audio = RecordingAudio()
        for root in ["a", "b", "c"] { drive.fixture.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")]) }
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        app.selectRoot("https://drive.google.com/drive/folders/empty"); await app.scan()
        XCTAssertEqual(app.playback.pending?.root.id, "b")
        drive.fixture.denied = ["denied"]
        app.selectRoot("https://drive.google.com/drive/folders/denied"); await app.scan()
        XCTAssertEqual(app.playback.pending?.root.id, "b")
        app.selectRoot("https://drive.google.com/drive/folders/c"); drive.suspendRoot = "c"
        let scan = Task { await app.scan() }; await drive.waitForSuspension()
        XCTAssertEqual(app.playback.pending?.root.id, "b")
        XCTAssertEqual(audio.starts.count, 1)
        drive.release(); await scan.value
        XCTAssertEqual(app.playback.pending?.root.id, "c")
        app.next(); XCTAssertEqual(app.playback.current?.id, "c")
    }

    @MainActor func testSameRootRescanRetainsActiveSnapshotUntilHandoff() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "old", name: "Old.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "new", name: "New.mp3", mimeType: "audio/mpeg")])
        await app.scan()
        XCTAssertEqual(app.playback.queue.map(\.id), ["old"])
        XCTAssertEqual(app.playback.pending?.tracks.map(\.id), ["new"])
        app.next(); XCTAssertEqual(app.playback.queue.map(\.id), ["new"])
    }
}
