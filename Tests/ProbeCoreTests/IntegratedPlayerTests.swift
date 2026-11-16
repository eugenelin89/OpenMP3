import XCTest
@testable import ProbeCore

final class IntegratedPlayerTests: XCTestCase {
    @MainActor func testReadyRecoveryMetadataAndCommandsDoNotSeekExhaustedA() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        for root in ["a", "b"] { drive.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")]) }
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
        audio.emit(.ready(id: "a", duration: 120)); audio.emit(.progress(id: "a", seconds: 10))
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        audio.emit(.failed(id: "a")); audio.emit(.failed(id: "a"))
        let seeks = audio.seeks.count
        audio.onCommand?(.seek(60))
        XCTAssertEqual(audio.seeks.count, seeks)
        XCTAssertEqual(app.playback.displayTrack?.id, "b")
        XCTAssertEqual(app.playback.displayState, "ready")
    }
}

extension IntegratedPlayerTests {
    @MainActor func testNativeCommandAvailabilityAndMetadataMatchTopState() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: (1...2).map { DriveEntry(id: "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        let app = ProbeApplication(drive: drive, audio: audio)
        XCTAssertEqual(audio.metadata?.canPlay, false)
        XCTAssertEqual(audio.metadata?.canNext, false)
        audio.onCommand?(.play); audio.onCommand?(.next); audio.onCommand?(.previous)
        XCTAssertTrue(audio.starts.isEmpty)
        app.selectRoot("https://drive.google.com/drive/folders/a"); app.saveSelectedRoot(name: "A"); await app.scan()
        XCTAssertEqual(audio.metadata?.displayState, "ready")
        XCTAssertEqual(audio.metadata?.displayRate, 0)
        XCTAssertEqual(audio.metadata?.canPlay, true)
        XCTAssertEqual(audio.metadata?.canPause, false)
        XCTAssertEqual(audio.metadata?.canSeek, false)
        audio.onCommand?(.next)
        XCTAssertEqual(audio.metadata?.displayTrack?.id, "2")
        XCTAssertTrue(audio.starts.isEmpty)
        audio.onCommand?(.play)
        audio.emit(.ready(id: "2", duration: 120)); audio.emit(.progress(id: "2", seconds: 3))
        XCTAssertEqual(audio.metadata?.displayRate, 1)
        XCTAssertEqual(audio.metadata?.displaySourceName, "A")
        XCTAssertEqual(audio.metadata?.canPause, true)
        XCTAssertEqual(audio.metadata?.canSeek, true)
        audio.onCommand?(.pause)
        XCTAssertEqual(audio.metadata?.displayRate, 0)
        XCTAssertEqual(audio.metadata?.displayState, "paused")
        audio.onCommand?(.next)
        XCTAssertEqual(audio.metadata?.canNext, false)
        XCTAssertEqual(audio.metadata?.canPlay, true) // replay exhausted source
    }

    @MainActor func testTypedScanOutcomesDriveReadyPendingEligibilityWithoutChangingMusic() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "a", name: "A.mp3", mimeType: "audio/mpeg")], coverageWarning: "Unverified coverage")
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan()
        XCTAssertEqual(app.scanObservation.state, .finished)
        XCTAssertTrue(app.scanObservation.reasons.isEmpty)
        XCTAssertEqual(app.scanStatusText, "Scan finished · 1 tracks found")
        XCTAssertEqual(app.playback.ready?.root.id, "a")
        XCTAssertTrue(audio.starts.isEmpty)
        app.play()
        drive.pages["b:"] = DrivePage(files: [DriveEntry(id: "b", name: "B.mp3", mimeType: "audio/mpeg")], incompleteSearch: true)
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        XCTAssertEqual(app.scanObservation.state, .incomplete)
        XCTAssertEqual(app.playback.pending?.root.id, "b")
        app.selectRoot("https://drive.google.com/drive/folders/empty"); await app.scan()
        XCTAssertEqual(app.scanObservation.state, .finished)
        XCTAssertEqual(app.playback.pending?.root.id, "b")
        drive.denied = ["denied"]
        app.selectRoot("https://drive.google.com/drive/folders/denied"); await app.scan()
        XCTAssertEqual(app.scanObservation.state, .failed)
        XCTAssertEqual(app.playback.pending?.root.id, "b")
        XCTAssertEqual(app.playback.current?.id, "a")
        XCTAssertEqual(audio.starts.count, 1)
        audio.onCommand?(.next)
        XCTAssertEqual(audio.metadata?.displaySourceName, "Unsaved folder")
        XCTAssertEqual(app.playback.current?.id, "b")
    }
}
