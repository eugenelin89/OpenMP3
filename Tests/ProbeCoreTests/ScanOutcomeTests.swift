import XCTest
@testable import ProbeCore

final class ScanOutcomeTests: XCTestCase {
    @MainActor func testBadDescendantPaginationDoesNotHideAccessibleSiblings() async {
        let drive = FixtureDrive()
        drive.pages["root:"] = DrivePage(files: [child, DriveEntry(id: "sibling", name: "Sibling", mimeType: DriveEntry.folderType)])
        drive.pages["child:"] = DrivePage(files: [], nextPageToken: "again")
        drive.pages["child:again"] = DrivePage(files: [], nextPageToken: "again")
        drive.pages["sibling:"] = DrivePage(files: [song])
        let app = ProbeApplication(drive: drive)
        app.selectRoot(rootLink); await app.scan()
        XCTAssertEqual(app.scanObservation.state, .incomplete)
        XCTAssertEqual(app.tracks.map(\.id), ["song"])
        XCTAssertEqual(app.failedFolderPaths, [["Child"]])
        XCTAssertEqual(app.scanObservation.reasons, ["Could not continue descendant pagination at depth 1; accessible siblings retained"])
    }

    @MainActor func testPartialSearchAndDeniedDescendantsStayIncompleteIncludingZeroTracks() async {
        for hasTrack in [false, true] {
            for deniedChild in [false, true] {
                let drive = FixtureDrive(), audio = ScanAudio()
                let entries = hasTrack ? [song] : []
                drive.pages["root:"] = DrivePage(
                    files: entries + (deniedChild ? [child] : []),
                    incompleteSearch: !deniedChild, coverageWarning: "Coverage uncertain")
                drive.denied = ["child"]
                let app = ProbeApplication(drive: drive, audio: audio)
                app.selectRoot(rootLink)
                await app.scan()
                XCTAssertEqual(app.scanObservation.state, .incomplete)
                XCTAssertEqual(app.scanStatusText, "Incomplete scan · \(hasTrack ? 1 : 0) tracks found")
                XCTAssertEqual(app.scanObservation.coverageNotices, ["Coverage uncertain"])
                XCTAssertEqual(app.scanObservation.reasons, [deniedChild
                    ? "Unreadable descendant at depth 1; accessible siblings retained"
                    : "Drive reported incomplete search"])
                XCTAssertTrue(audio.operations.isEmpty)
                XCTAssertEqual(app.canPlayCollection, hasTrack)
                app.playAll()
                XCTAssertEqual(app.playback.queue.map(\.id), hasTrack ? ["song"] : [])
            }
        }
    }

    @MainActor func testLaterPageFailuresRetainTracksForExplicitPlayback() async {
        for failure in [DriveFailure.access, .restriction, .malformedResponse, .transient, .experimentalLimit, .pagination] {
            let drive = FixtureDrive(), audio = ScanAudio()
            drive.pages["root:"] = DrivePage(files: [song], nextPageToken: "later", coverageWarning: "Coverage uncertain")
            drive.pageFailures["root:later"] = failure
            let app = ProbeApplication(drive: drive, audio: audio)
            app.selectRoot(rootLink)
            var controls = ExperimentControls(); controls.retryDelay = 0
            await app.scan(controls: controls)
            XCTAssertEqual(app.scanObservation.state, .incomplete, "\(failure)")
            XCTAssertEqual(app.scanStatusText, "Incomplete scan · 1 tracks found")
            XCTAssertFalse(app.scanObservation.reasons.isEmpty)
            XCTAssertEqual(app.tracks.map(\.id), ["song"])
            XCTAssertTrue(audio.operations.isEmpty)
            app.playTrack(id: "song")
            XCTAssertEqual(audio.operations, ["start song"])
            XCTAssertEqual(app.playback.queueSource?.id, "root")
        }
    }

    @MainActor func testEmptyAndFailedScansPreserveExistingPlayingAndPausedMusic() async {
        for paused in [false, true] {
            let drive = FixtureDrive(), audio = ScanAudio()
            drive.pages["root:"] = DrivePage(files: [song])
            let app = ProbeApplication(drive: drive, audio: audio)
            app.selectRoot(rootLink); await app.scan(); app.playAll()
            app.receive(.progress(id: "song", seconds: 17))
            if paused { app.pause() }
            let originalOperations = audio.operations
            for failure in [false, true] {
                drive.failures["other"] = failure ? .access : nil
                app.selectRoot("https://drive.google.com/drive/folders/other")
                await app.scan()
                XCTAssertEqual(app.scanObservation.state, failure ? .failed : .finished)
                XCTAssertEqual(app.scanStatusText, failure ? "Scan failed" : "Scan finished · 0 tracks found")
                XCTAssertFalse(app.canPlayCollection)
                app.playAll(); app.shuffleAll(); app.playTrack(id: "missing")
                XCTAssertEqual(audio.operations, originalOperations)
                XCTAssertEqual(app.playback.current?.id, "song")
                XCTAssertEqual(app.playback.queueSource?.id, "root")
                XCTAssertEqual(app.playback.seconds, 17)
                XCTAssertEqual(app.playback.state, paused ? "paused" : "playing")
            }
            app.play()
            XCTAssertEqual(audio.operations.last, "resume")
        }
    }

    @MainActor func testStopAndForegroundExitRetainPartialResultsWithoutAutoplay() async {
        for backgrounded in [false, true] {
            for hasTrack in [false, true] {
                let drive = SuspendedScanDrive(entries: hasTrack ? [song] : [])
                let audio = ScanAudio()
                let app = ProbeApplication(drive: drive, audio: audio)
                app.selectRoot(rootLink)
                let waiting = expectation(description: "Continuation request started")
                drive.onSuspend = { waiting.fulfill() }
                let scan = Task { await app.scan() }
                await fulfillment(of: [waiting], timeout: 2)
                XCTAssertEqual(app.scanObservation.state, .scanning)
                XCTAssertFalse(app.canPlayCollection)
                app.stopScan(backgrounded: backgrounded)
                await scan.value
                XCTAssertEqual(app.scanObservation.state, .incomplete)
                XCTAssertEqual(app.scanObservation.reasons, ["Drive reported incomplete search", backgrounded ? "App left foreground" : "Scan stopped"])
                XCTAssertEqual(app.tracks.map(\.id), hasTrack ? ["song"] : [])
                XCTAssertEqual(app.canPlayCollection, hasTrack)
                XCTAssertTrue(audio.operations.isEmpty)
                app.playAll()
                XCTAssertEqual(audio.operations, hasTrack ? ["start song"] : [])
            }
        }
    }

    @MainActor func testWorkCutoffsRemainIncompleteWithRetainedTracks() async {
        for cutoff in ["requests", "folders", "tracks", "clock", "response"] {
            let drive = FixtureDrive()
            drive.pages["root:"] = DrivePage(files: [song, child])
            var controls = ExperimentControls()
            var time = 0.0
            switch cutoff {
            case "requests": controls.listingRequests = 1
            case "folders": controls.folders = 1
            case "tracks":
                controls.tracks = 1
                drive.pages["child:"] = DrivePage(files: [DriveEntry(id: "second", name: "second.mp3", mimeType: "audio/mpeg")])
            case "clock": drive.onList = { if $0.id == "child" { time = controls.seconds } }
            default: drive.failures["child"] = .experimentalLimit
            }
            let app = ProbeApplication(drive: drive, now: { time })
            app.selectRoot(rootLink)
            await app.scan(controls: controls)
            XCTAssertEqual(app.scanObservation.state, .incomplete, cutoff)
            XCTAssertEqual(app.tracks.map(\.id), ["song"], cutoff)
            XCTAssertTrue(app.canPlayCollection)
            XCTAssertFalse(app.scanObservation.reasons.isEmpty)
        }
    }

    @MainActor func testFailedInitialListingIsNotAnEmptySuccessAndCachedCoverageStaysSeparate() async {
        let drive = FixtureDrive()
        // Initial listing can fail even when root inspection succeeded.
        drive.failures["root"] = .malformedResponse
        let failed = ProbeApplication(drive: drive)
        failed.selectRoot(rootLink); await failed.scan()
        XCTAssertEqual(failed.scanObservation.state, .failed)
        XCTAssertFalse(failed.canPlayCollection)
        XCTAssertNotNil(failed.error)
        drive.failures = [:]
        drive.pages["root:"] = DrivePage(files: [song], coverageWarning: "Raw coverage detail")
        let cached = ProbeApplication(drive: drive)
        cached.selectRoot(rootLink); await cached.scan()
        cached.selectRoot("https://drive.google.com/drive/folders/other")
        cached.selectRoot(rootLink)
        XCTAssertEqual(cached.scanObservation.state, .finished)
        XCTAssertEqual(cached.scanObservation.coverageNotices, ["Raw coverage detail"])
        XCTAssertTrue(cached.scanObservation.reasons.isEmpty)
        XCTAssertTrue(cached.playback.queue.isEmpty)
    }

    private var rootLink: String { "https://drive.google.com/drive/folders/root" }
    private var song: DriveEntry { DriveEntry(id: "song", name: "song.mp3", mimeType: "audio/mpeg") }
    private var child: DriveEntry { DriveEntry(id: "child", name: "Child", mimeType: DriveEntry.folderType) }
}

@MainActor private final class ScanAudio: AudioOutput {
    var operations: [String] = []
    var onCommand: ((PlayerCommand) -> Void)?
    var onEvent: ((AudioEvent) -> Void)?
    func start(url: URL, id: String, playing: Bool) throws {
        operations.append("start " + id)
        onEvent?(.ready(id: id, duration: 120))
    }
    func resume() throws { operations.append("resume") }
    func pause() { operations.append("pause") }
    func seek(seconds: Double) { operations.append("seek") }
}

@MainActor private final class SuspendedScanDrive: DriveAccess {
    let entries: [DriveEntry]
    var onSuspend: (() -> Void)?
    init(entries: [DriveEntry]) { self.entries = entries }
    func inspectRoot(_ root: RootFolder) async throws -> DriveEntry {
        DriveEntry(id: root.id, name: "Root", mimeType: DriveEntry.folderType)
    }
    func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage {
        if pageToken == nil { return DrivePage(files: entries, nextPageToken: "wait", incompleteSearch: true) }
        let stream = AsyncStream<Void> { _ in }
        onSuspend?()
        for await _ in stream { }
        try Task.checkCancellation()
        return DrivePage(files: [])
    }
    func mediaURL(_ track: DiscoveredTrack) throws -> URL { URL(string: "https://example.test/audio")! }
}
