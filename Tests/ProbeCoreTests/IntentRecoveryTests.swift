import XCTest
@testable import ProbeCore

final class IntentRecoveryTests: XCTestCase {
    @MainActor func testTrackTapDuringScanWinsOverEarlierScanIntent() async {
        let drive = SuspendedDrive(), audio = RecordingAudio()
        drive.fixture.pages["a:"] = DrivePage(files: [DriveEntry(id: "a", name: "A.mp3", mimeType: "audio/mpeg")])
        drive.fixture.pages["b:"] = DrivePage(files: [DriveEntry(id: "b", name: "B.mp3", mimeType: "audio/mpeg")])
        drive.fixture.pages["c:"] = DrivePage(files: [DriveEntry(id: "c", name: "C.mp3", mimeType: "audio/mpeg"), DriveEntry(id: "child", name: "Child", mimeType: DriveEntry.folderType)])
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        app.selectRoot("https://drive.google.com/drive/folders/c"); drive.suspendRoot = "child"
        let scan = Task { await app.scan() }; await drive.waitForSuspension()
        app.playTrack(id: "c")
        XCTAssertEqual(app.playback.current?.id, "c")
        XCTAssertNil(app.playback.pending)
        drive.release(); await scan.value
        XCTAssertNil(app.playback.pending)
        XCTAssertNil(app.playback.ready)
        XCTAssertEqual(app.tracks.map(\.id), ["c"])
        XCTAssertEqual(audio.starts.count, 2)
        await app.scan()
        XCTAssertEqual(app.playback.pending?.root.id, "c") // later-started rescan may arm
    }
}

extension IntentRecoveryTests {
    @MainActor func testRecoveryExhaustionPromotesPendingSilentlyAndRejectsOldCallbacks() async {
        for temporary in [false, true] {
            let drive = FixtureDrive(), audio = RecordingAudio()
            for root in ["a", "b"] { drive.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")]) }
            let app = ProbeApplication(drive: drive, audio: audio)
            app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
            app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
            if temporary {
                audio.emit(.failed(id: "a"))
                XCTAssertEqual(app.playback.pending?.root.id, "b")
                XCTAssertEqual(app.playback.current?.id, "a")
            }
            let oldCallback = audio.callbacks.last!
            audio.emit(temporary ? .failed(id: "a") : .unavailable(id: "a"))
            XCTAssertEqual(app.playback.ready?.root.id, "b")
            XCTAssertNil(app.playback.pending)
            XCTAssertFalse(app.isPlaybackRequested)
            let starts = audio.starts.count
            oldCallback(.ended(id: "a")); oldCallback(.failed(id: "a"))
            XCTAssertEqual(audio.starts.count, starts)
            XCTAssertEqual(app.playback.ready?.root.id, "b")
            app.play()
            XCTAssertEqual(app.playback.queueSource?.id, "b")
            XCTAssertEqual(audio.starts.last?.playing, true)
            audio.emit(.failed(id: "b")); audio.emit(.failed(id: "b"))
            XCTAssertEqual(app.playback.queueSource?.id, "b")
            XCTAssertNil(app.playback.pending)
        }
    }
}

extension IntentRecoveryTests {
    @MainActor func testRemovingRootClearsFutureIntentAndPreservesActiveQueue() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        for root in ["a", "b"] { drive.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")]) }
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); app.saveSelectedRoot(name: "A"); await app.scan()
        app.removeSavedRoot(id: "a")
        XCTAssertNil(app.playback.ready)
        XCTAssertFalse(app.playback.canPlay)
        XCTAssertEqual(app.playback.displaySource, "Load a folder to prepare music")
        app.selectRoot("https://drive.google.com/drive/folders/a"); app.saveSelectedRoot(name: "A"); await app.scan(); app.play()
        app.selectRoot("https://drive.google.com/drive/folders/b"); app.saveSelectedRoot(name: "B"); await app.scan()
        app.removeSavedRoot(id: "b")
        XCTAssertNil(app.playback.pending)
        XCTAssertEqual(app.playback.current?.id, "a")
        app.removeSavedRoot(id: "a")
        XCTAssertEqual(app.playback.current?.id, "a")
        XCTAssertEqual(app.playback.sourceName, "A")
        XCTAssertNil(app.selectedRoot)
        app.selectSavedRoot(id: "b")
        XCTAssertNil(app.selectedRoot)
    }
}

extension IntentRecoveryTests {
    @MainActor func testObservedEndBeforeLaterScanSettlesUsesExistingPendingFirst() async {
        for hasPending in [false, true] {
            let drive = SuspendedDrive(), audio = RecordingAudio()
            for root in ["a", "b", "c"] { drive.fixture.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")]) }
            let app = ProbeApplication(drive: drive, audio: audio)
            app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
            if hasPending { app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan() }
            app.selectRoot("https://drive.google.com/drive/folders/c"); drive.suspendRoot = "c"
            let scan = Task { await app.scan() }; await drive.waitForSuspension()
            audio.emit(.ended(id: "a"))
            XCTAssertEqual(app.playback.current?.id, hasPending ? "b" : nil)
            let starts = audio.starts.count
            drive.release(); await scan.value
            XCTAssertEqual(audio.starts.count, starts)
            if hasPending {
                XCTAssertEqual(app.playback.pending?.root.id, "c")
                XCTAssertEqual(app.playback.current?.id, "b")
                audio.emit(.ended(id: "b"))
                XCTAssertEqual(app.playback.current?.id, "c")
            } else {
                XCTAssertEqual(app.playback.ready?.root.id, "c")
                XCTAssertFalse(app.isPlaybackRequested)
            }
        }
    }

    @MainActor func testRetryableFailureRetainsAAndNextPreservesPlayingOrPausedIntent() async {
        for paused in [false, true] {
            let drive = FixtureDrive(), audio = RecordingAudio()
            for root in ["a", "b"] { drive.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")]) }
            let app = ProbeApplication(drive: drive, audio: audio)
            app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
            if paused { app.pause() }
            audio.emit(.failed(id: "a"))
            XCTAssertFalse(app.playback.recoveryExhausted)
            app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
            XCTAssertEqual(app.playback.pending?.root.id, "b")
            XCTAssertNil(app.playback.ready)
            XCTAssertEqual(app.playback.current?.id, "a")
            audio.onCommand?(.next)
            XCTAssertEqual(app.playback.current?.id, "b")
            XCTAssertEqual(audio.starts.last?.playing, !paused)
            XCTAssertNil(app.playback.pending)
        }
    }

    @MainActor func testRemovalWhileScanningIsRejectedAndSettledRemovalCannotRearm() async {
        let drive = SuspendedDrive(), audio = RecordingAudio()
        drive.fixture.pages["a:"] = DrivePage(files: [DriveEntry(id: "song", name: "Song.mp3", mimeType: "audio/mpeg")])
        drive.suspendRoot = "a"
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); app.saveSelectedRoot(name: "A")
        let scan = Task { await app.scan() }; await drive.waitForSuspension()
        app.removeSavedRoot(id: "a")
        XCTAssertEqual(app.savedRoots.count, 1)
        await app.scan() // duplicate request cannot create a second scan
        app.stopScan(); drive.release(); await scan.value
        app.removeSavedRoot(id: "a")
        await Task.yield()
        XCTAssertTrue(app.savedRoots.isEmpty)
        XCTAssertNil(app.selectedRoot)
        XCTAssertNil(app.playback.ready)
        XCTAssertNil(app.playback.pending)
        XCTAssertTrue(audio.starts.isEmpty)
    }

    @MainActor func testUnavailableLastUpcomingTrackPromotesPendingWithoutRepeatingEarlierA() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: (1...2).map { DriveEntry(id: "a\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        drive.pages["b:"] = DrivePage(files: [DriveEntry(id: "b", name: "B.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play(); app.next()
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        audio.emit(.unavailable(id: "a2"))
        XCTAssertEqual(app.playback.ready?.root.id, "b")
        XCTAssertEqual(audio.starts.count, 2)
        XCTAssertFalse(app.isPlaybackRequested)
    }
}
