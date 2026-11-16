import XCTest
@testable import ProbeCore

@MainActor final class RecordingAudio: AudioOutput {
    var onCommand: ((PlayerCommand) -> Void)?
    var onEvent: ((AudioEvent) -> Void)?
    var starts: [(id: String, playing: Bool)] = []
    var resumes = 0
    var pauses = 0
    var seeks: [Double] = []
    func start(url: URL, id: String, playing: Bool) throws { starts.append((id, playing)) }
    func resume() throws { resumes += 1 }
    func pause() { pauses += 1 }
    func seek(seconds: Double) { seeks.append(seconds) }
}

final class ReadyPlayerTests: XCTestCase {
    @MainActor func testSettledCollectionStartsOnlyFromTopPlay() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: [DriveEntry(id: "one", name: "One.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive, audio: audio)
        app.handle(.play)
        XCTAssertTrue(audio.starts.isEmpty)
        app.selectRoot("https://drive.google.com/drive/folders/a")
        app.saveSelectedRoot(name: "A")
        await app.scan()
        XCTAssertTrue(audio.starts.isEmpty)
        XCTAssertNil(app.playback.current)
        app.handle(.play)
        XCTAssertEqual(app.playback.current?.id, "one")
        XCTAssertEqual(app.playback.sourceName, "A")
        XCTAssertEqual(audio.starts.count, 1)
        XCTAssertEqual(audio.starts.first?.playing, true)
    }
}

extension ReadyPlayerTests {
    @MainActor func testReadyNavigationShuffleRepeatAndPlaySelectedTrack() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: (1...3).map { DriveEntry(id: "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        let app = ProbeApplication(drive: drive, audio: audio, shuffled: { Array($0.reversed()) })
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan()
        app.previous(); XCTAssertEqual(app.playback.ready?.selected.id, "1")
        app.next(); XCTAssertEqual(app.playback.ready?.selected.id, "2")
        app.setShuffle(true); app.previous(); app.next()
        XCTAssertEqual(app.playback.ready?.selected.id, "2")
        app.setRepeat(.one); app.next(); app.next()
        XCTAssertEqual(app.playback.ready?.selected.id, "3")
        app.setRepeat(.all); app.next()
        XCTAssertEqual(app.playback.ready?.selected.id, "1") // wrap the prepared order
        app.previous(); XCTAssertEqual(app.playback.ready?.selected.id, "3") // actual preceding selection
        app.next(); app.next()
        XCTAssertEqual(app.playback.ready?.selected.id, "2")
        XCTAssertTrue(audio.starts.isEmpty)
        XCTAssertEqual(audio.resumes, 0)
        XCTAssertTrue(audio.seeks.isEmpty)
        app.play()
        XCTAssertEqual(app.playback.current?.id, "2")
        XCTAssertNil(app.playback.ready)
    }
}

extension ReadyPlayerTests {
    @MainActor func testReplacementCachedBrowsingPartialAndExhaustedQueuePrecedence() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        for root in ["a", "b", "c"] {
            drive.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")])
        }
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan(); app.play()
        app.next(); XCTAssertNil(app.playback.current)
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        XCTAssertEqual(app.playback.ready?.root.id, "b")
        app.selectRoot("https://drive.google.com/drive/folders/a")
        XCTAssertEqual(app.playback.ready?.root.id, "b")
        drive.pages["c:"] = DrivePage(files: drive.pages["c:"]!.files, nextPageToken: "more")
        var controls = ExperimentControls(); controls.listingRequests = 1
        app.selectRoot("https://drive.google.com/drive/folders/c"); await app.scan(controls: controls)
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.playback.ready?.root.id, "c")
        app.selectRoot("https://drive.google.com/drive/folders/empty"); await app.scan()
        XCTAssertEqual(app.playback.ready?.root.id, "c")
        drive.denied = ["denied"]
        app.selectRoot("https://drive.google.com/drive/folders/denied"); await app.scan()
        XCTAssertEqual(app.playback.ready?.root.id, "c")
        XCTAssertEqual(audio.starts.count, 1)
        app.play()
        XCTAssertEqual(app.playback.queueSource?.id, "c")
        app.pause()
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        XCTAssertNil(app.playback.ready)
        XCTAssertEqual(app.playback.current?.id, "c")
        XCTAssertEqual(app.playback.state, "paused")
        XCTAssertEqual(audio.starts.count, 2)
        app.play(); XCTAssertEqual(app.playback.current?.id, "c")
    }

    @MainActor func testInitialShuffleAndReadyReplacementDoNotStartAudio() async {
        let drive = FixtureDrive(), audio = RecordingAudio()
        drive.pages["a:"] = DrivePage(files: (1...3).map { DriveEntry(id: "\($0)", name: "\($0).mp3", mimeType: "audio/mpeg") })
        let app = ProbeApplication(drive: drive, audio: audio, shuffled: { Array($0.reversed()) })
        app.setShuffle(true)
        app.selectRoot("https://drive.google.com/drive/folders/a"); await app.scan()
        XCTAssertEqual(app.playback.ready?.selected.id, "3")
        app.setShuffle(false)
        XCTAssertEqual(app.playback.ready?.order.map(\.id), ["3", "1", "2"])
        app.playTrack(id: "2")
        XCTAssertNil(app.playback.ready)
        XCTAssertEqual(app.playback.current?.id, "2")
        XCTAssertEqual(audio.starts.count, 1)
    }
}

@MainActor final class SuspendedDrive: DriveAccess {
    let fixture = FixtureDrive()
    var suspendRoot: String?
    private var continuation: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func inspectRoot(_ root: RootFolder) async throws -> DriveEntry { try await fixture.inspectRoot(root) }
    func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage {
        if folder.id == suspendRoot {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                observer?.resume(); observer = nil
            }
        }
        return try await fixture.list(folder, pageToken: pageToken)
    }
    func waitForSuspension() async {
        if continuation != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release() { suspendRoot = nil; continuation?.resume(); continuation = nil }
    func mediaURL(_ track: DiscoveredTrack) throws -> URL { try fixture.mediaURL(track) }
}

extension ReadyPlayerTests {
    @MainActor func testReadySurvivesScanUntilEligibleSettlement() async {
        let drive = SuspendedDrive(), audio = RecordingAudio()
        for root in ["b", "c"] { drive.fixture.pages[root + ":"] = DrivePage(files: [DriveEntry(id: root, name: root + ".mp3", mimeType: "audio/mpeg")]) }
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/b"); await app.scan()
        app.selectRoot("https://drive.google.com/drive/folders/c")
        drive.suspendRoot = "c"
        let scan = Task { await app.scan() }
        await drive.waitForSuspension()
        XCTAssertEqual(app.playback.ready?.root.id, "b")
        XCTAssertTrue(audio.starts.isEmpty)
        drive.release(); await scan.value
        XCTAssertEqual(app.playback.ready?.root.id, "c")
        XCTAssertTrue(audio.starts.isEmpty)
    }
}
