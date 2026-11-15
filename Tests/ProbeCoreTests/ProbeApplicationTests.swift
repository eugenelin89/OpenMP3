import XCTest
@testable import ProbeCore

final class ProbeApplicationTests: XCTestCase {
    @MainActor func testSelectRootPreservesIdentityAndRejectsNonFolderLinks() {
        let app = ProbeApplication()
        app.selectRoot("https://drive.google.com/drive/u/0/folders/root_123?resourcekey=key-123&usp=sharing")
        XCTAssertEqual(app.selectedRoot?.id, "root_123")
        XCTAssertEqual(app.selectedRoot?.resourceKey, "key-123")
        XCTAssertNil(app.error)
        for invalid in ["nonsense", "https://drive.google.com.evil.test/drive/folders/root", "https://drive.google.com/file/d/file/view", "http://drive.google.com/drive/folders/root", "https://drive.google.com/drive/folders/root?resourcekey=a&resourcekey=b"] {
            app.selectRoot(invalid)
            XCTAssertEqual(app.error, "Invalid Google Drive folder link")
            XCTAssertNil(app.selectedRoot)
        }
        app.selectRoot("https://drive.google.com/open?id=legacy_root&resourcekey=rk")
        XCTAssertEqual(app.selectedRoot?.id, "legacy_root")
    }
}

@MainActor final class FixtureDrive: DriveAccess {
    var pages: [String: DrivePage] = [:]
    var denied: Set<String> = []
    var failures: [String: DriveFailure] = [:]
    func inspectRoot(_ root: RootFolder) async throws -> DriveEntry {
        if denied.contains(root.id) { throw DriveFailure.access }
        return DriveEntry(id: root.id, name: "Fixture", mimeType: DriveEntry.folderType)
    }
    func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage {
        if denied.contains(folder.id) { throw DriveFailure.access }
        if let failure = failures[folder.id] { throw failure }
        return pages[folder.id + ":" + (pageToken ?? "")] ?? DrivePage(files: [])
    }
    func mediaURL(_ track: DiscoveredTrack) throws -> URL { URL(string: "https://example.test/audio")! }
}

extension ProbeApplicationTests {
    @MainActor func testRecursiveDiscoveryKeepsIdentitiesPathsAndPartialCoverage() async {
        let drive = FixtureDrive()
        let mp3 = DriveEntry(id: "root-track", name: "same.mp3", mimeType: "audio/mpeg")
        drive.pages = [
            "root:": DrivePage(files: [mp3, DriveEntry(id: "child", name: "Child", mimeType: DriveEntry.folderType, resourceKey: "child-key")], nextPageToken: "page2"),
            "root:page2": DrivePage(files: [mp3, DriveEntry(id: "private", name: "Private", mimeType: DriveEntry.folderType), DriveEntry(id: "shortcut", name: "skip", mimeType: DriveEntry.shortcutType), DriveEntry(id: "text", name: "notes.txt", mimeType: "text/plain")]),
            "child:": DrivePage(files: [DriveEntry(id: "child-track", name: "same.mp3", mimeType: "audio/mpeg"), DriveEntry(id: "grandchild", name: "Grandchild", mimeType: DriveEntry.folderType)]),
            "grandchild:": DrivePage(files: [DriveEntry(id: "deep-track", name: "same.mp3", mimeType: "audio/mpeg")])
        ]
        drive.denied = ["private"]
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        await app.scan()
        XCTAssertEqual(app.tracks.map(\.id), ["root-track", "child-track", "deep-track"])
        XCTAssertEqual(app.tracks.map(\.path), [[], ["Child"], ["Child", "Grandchild"]])
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.scanObservation.shortcuts, 1)
        XCTAssertEqual(app.scanObservation.ignoredFiles, 1)
        XCTAssertEqual(app.scanObservation.listingRequests, 5)
    }
}

extension ProbeApplicationTests {
    @MainActor func testNonAudioPaginationStopsAtExperimentalRequestBudget() async {
        let drive = FixtureDrive()
        drive.pages["root:"] = DrivePage(files: [DriveEntry(id: "track", name: "song.mp3", mimeType: "audio/mpeg")], nextPageToken: "two")
        drive.pages["root:two"] = DrivePage(files: [DriveEntry(id: "text", name: "notes", mimeType: "text/plain")], nextPageToken: "three")
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        var controls = ExperimentControls()
        controls.listingRequests = 2
        await app.scan(controls: controls)
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.scanObservation.listingRequests, 2)
        XCTAssertEqual(app.tracks.map(\.id), ["track"])
        XCTAssertTrue(app.scanObservation.reasons.contains("Experimental listing-request limit"))
    }
}

@MainActor final class FixtureAudio: AudioOutput {
    var onEvent: ((AudioEvent) -> Void)?
    func start(url: URL, id: String) throws { onEvent?(.ready(id: id, duration: 120)) }
    func pause() {}
    func seek(seconds: Double) {}
}

extension ProbeApplicationTests {
    @MainActor func testExplicitPlaybackSeekAndNaturalTransitionRemainIndependentOfBrowsing() async {
        let drive = FixtureDrive()
        drive.pages["root:"] = DrivePage(files: [
            DriveEntry(id: "second", name: "10.mp3", mimeType: "audio/mpeg"),
            DriveEntry(id: "first", name: "2.mp3", mimeType: "audio/mpeg")])
        let audio = FixtureAudio()
        let app = ProbeApplication(drive: drive, audio: audio)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        await app.scan()
        XCTAssertEqual(app.playback.state, "idle")
        app.playAll()
        XCTAssertEqual(app.playback.current?.id, "first")
        app.receive(.progress(id: "first", seconds: 3))
        app.seek(seconds: 60)
        app.receive(.seeked(id: "first", requested: 60, actual: 60.1, finished: true))
        XCTAssertTrue(app.playback.events.contains("Seek completed: requested 60.0s, actual 60.1s"))
        app.selectRoot("https://drive.google.com/drive/folders/other")
        await app.scan()
        XCTAssertEqual(app.playback.queueSource?.id, "root")
        app.receive(.ended(id: "first"))
        XCTAssertEqual(app.playback.current?.id, "second")
        app.receive(.progress(id: "first", seconds: 119))
        XCTAssertEqual(app.playback.seconds, 0)
        app.receive(.failed(id: "first")) // late callback from previous item
        XCTAssertNotEqual(app.playback.state, "failed")
        app.receive(.ended(id: "second"))
        XCTAssertEqual(app.playback.state, "ended")
    }
}

extension ProbeApplicationTests {
    @MainActor func testAccessFailureIsDifferentFromInvalidInputAndReadableEmptyRoot() async {
        let drive = FixtureDrive()
        drive.denied = ["private"]
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/private")
        XCTAssertNil(app.error)
        await app.scan()
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.error, "Drive access or response failure")
        app.selectRoot("https://drive.google.com/drive/folders/empty")
        await app.scan()
        XCTAssertEqual(app.scanObservation.state, "complete")
        XCTAssertTrue(app.tracks.isEmpty)
        app.playAll()
        XCTAssertTrue(app.playback.queue.isEmpty)
    }

    @MainActor func testExactTrackLimitIsCompleteButOverflowRetainsDiscoveries() async {
        let drive = FixtureDrive()
        let first = DriveEntry(id: "one", name: "1.mp3", mimeType: "audio/mpeg")
        drive.pages["root:"] = DrivePage(files: [first])
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        var controls = ExperimentControls(); controls.tracks = 1
        await app.scan(controls: controls)
        XCTAssertEqual(app.scanObservation.state, "complete")
        drive.pages["root:"] = DrivePage(files: [first, DriveEntry(id: "two", name: "2.mp3", mimeType: "audio/mpeg")])
        await app.scan(controls: controls)
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.tracks.map(\.id), ["one"])
    }

    @MainActor func testRepeatedPaginationTokenCannotLoop() async {
        let drive = FixtureDrive()
        drive.pages["root:"] = DrivePage(files: [], nextPageToken: "again")
        drive.pages["root:again"] = DrivePage(files: [], nextPageToken: "again")
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        await app.scan()
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.scanObservation.listingRequests, 2)
    }
}

@MainActor final class FailingDrive: DriveAccess {
    var delay = false
    func inspectRoot(_ root: RootFolder) async throws -> DriveEntry {
        DriveEntry(id: root.id, name: "Root", mimeType: DriveEntry.folderType)
    }
    func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage {
        if delay { try await Task.sleep(nanoseconds: 5_000_000_000) }
        throw DriveFailure.transient
    }
    func mediaURL(_ track: DiscoveredTrack) throws -> URL { throw DriveFailure.access }
}

extension ProbeApplicationTests {
    @MainActor func testTransientFailuresConsumeBoundedRetriesWithoutClaimingEmptySuccess() async {
        let drive = FailingDrive()
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        var controls = ExperimentControls(); controls.retryDelay = 0
        await app.scan(controls: controls)
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.scanObservation.listingRequests, 2)
        XCTAssertEqual(app.scanObservation.retries, 1)
        XCTAssertTrue(app.error?.contains("retry controls exhausted") == true)
    }

    @MainActor func testWallClockControlCancelsAnInFlightRequest() async {
        let drive = FailingDrive(); drive.delay = true
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        var controls = ExperimentControls(); controls.seconds = 0.03
        await app.scan(controls: controls)
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.error, "Experimental wall-clock limit")
        XCTAssertEqual(app.scanObservation.listingRequests, 1)
    }

    @MainActor func testLeavingForegroundStopsDiscovery() async {
        let drive = FailingDrive(); drive.delay = true
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        let scan = Task { await app.scan() }
        while app.scanObservation.listingRequests == 0 { await Task.yield() }
        app.stopScan(backgrounded: true)
        await scan.value
        XCTAssertEqual(app.scanObservation.state, "incomplete")
        XCTAssertEqual(app.error, "App left foreground")
        XCTAssertEqual(app.scanObservation.listingRequests, 1)
    }
}

private class EncodedPageProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    var page: String { #"<script>window['_DRIVE_ivd'] = '[[[\"emoji\",[],\"\uD83D\uDE00.mp3\",\"audio/mpeg\"]]]';</script>"# }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(page.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension ProbeApplicationTests {
    @MainActor func testUnreadableChildPageDoesNotHideAccessibleSibling() async {
        let drive = FixtureDrive()
        drive.pages["root:"] = DrivePage(files: [DriveEntry(id: "bad", name: "Bad", mimeType: DriveEntry.folderType), DriveEntry(id: "good", name: "Good", mimeType: DriveEntry.folderType)])
        drive.failures["bad"] = .malformedResponse
        drive.pages["good:"] = DrivePage(files: [DriveEntry(id: "song", name: "song.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        await app.scan()
        XCTAssertEqual(app.tracks.map(\.id), ["song"])
        XCTAssertEqual(app.failedFolderPaths, [["Bad"]])
        XCTAssertEqual(app.scanObservation.state, "incomplete")
    }
    @MainActor func testAnonymousEscapedUnicodeFilenameIsDiscoveredWithoutClaimingCompleteCoverage() async {
        let drive = AnonymousDrive(protocolClasses: [EncodedPageProtocol.self])
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/root")
        await app.scan()
        XCTAssertEqual(app.tracks.map { $0.entry.name }, ["😀.mp3"])
        XCTAssertEqual(app.scanObservation.state, "incomplete")
    }
}

private final class BrokenChildPageProtocol: EncodedPageProtocol {
    override var page: String {
        switch request.url?.lastPathComponent {
        case "root": return #"<script>window['_DRIVE_ivd'] = '[[["bad",[],"Bad","application/vnd.google-apps.folder"],["good",[],"Good","application/vnd.google-apps.folder"]]]';</script>"#
        case "bad": return #"<script>window['_DRIVE_ivd'] = 'not valid JSON';</script>"#
        default: return #"<script>window['_DRIVE_ivd'] = '[[["song",[],"song.mp3","audio/mpeg"]]]';</script>"#
        }
    }
}

extension ProbeApplicationTests {
    @MainActor func testMalformedChildJSONDoesNotHideAccessibleSibling() async {
        let app = ProbeApplication(drive: AnonymousDrive(protocolClasses: [BrokenChildPageProtocol.self]))
        app.selectRoot("https://drive.google.com/drive/folders/root")
        await app.scan()
        XCTAssertEqual(app.tracks.map(\.id), ["song"])
        XCTAssertEqual(app.failedFolderPaths, [["Bad"]])
        XCTAssertEqual(app.scanObservation.state, "incomplete")
    }
}

extension ProbeApplicationTests {
    @MainActor func testPublishableEvidenceContainsCountsButNoPrivateMetadata() async throws {
        let drive = FixtureDrive()
        drive.pages["secret-root:"] = DrivePage(files: [
            DriveEntry(id: "secret-file-one", name: "private-title.mp3", mimeType: "audio/mpeg", resourceKey: "private-resource-key"),
            DriveEntry(id: "secret-file-two", name: "private-title.mp3", mimeType: "audio/mpeg")])
        let app = ProbeApplication(drive: drive)
        app.selectRoot("https://drive.google.com/drive/folders/secret-root?resourcekey=private-root-key")
        let controls = ExperimentControls()
        await app.scan(controls: controls)
        let report = app.evidence(controls: controls, requests: [], media: [])
        XCTAssertEqual(report.discoveredTracks, 2)
        XCTAssertEqual(report.tracksByDepth, ["0": 2])
        XCTAssertEqual(report.duplicateFilenameGroups, 1)
        let json = String(decoding: try JSONEncoder().encode(report), as: UTF8.self)
        for privateValue in ["secret-root", "secret-file", "private-title", "private-resource-key", "private-root-key", "drive.google.com"] {
            XCTAssertFalse(json.contains(privateValue))
        }
    }
}

private final class EmptyPublicFolderProtocol: EncodedPageProtocol {
    override var page: String {
        #"<script>window['_DRIVE_ivd'] = '[null,null,null,null,[]]';</script>"#
    }
}
extension ProbeApplicationTests {
    @MainActor func testObservedEmptyPublicFolderIsNotAnAccessOrParsingFailure() async {
        let app = ProbeApplication(drive: AnonymousDrive(protocolClasses: [EmptyPublicFolderProtocol.self]))
        app.selectRoot("https://drive.google.com/drive/folders/empty")
        await app.scan()
        XCTAssertNil(app.error)
        XCTAssertTrue(app.tracks.isEmpty)
        XCTAssertEqual(app.scanObservation.listingRequests, 1)
        XCTAssertEqual(app.scanObservation.state, "incomplete") // Coverage contract remains unverified.
        XCTAssertEqual(app.failedFolderPaths, [])
    }
}
