import SwiftUI

/// Separate simulator-only executable. Uses the real player screen and coordinator;
/// no fixture selection or synthetic library is compiled into the normal app.
@main struct ScanStatusFixtureApp: App {
    @StateObject private var app = ProbeApplication(drive: ScanUIDrive())
    var body: some Scene {
        WindowGroup {
            PlayerScreen(app: app).task {
                app.selectRoot("https://drive.google.com/drive/folders/fixture")
                app.saveSelectedRoot(name: "Scan status fixture")
                await app.scan()
            }
        }
    }
}

@MainActor private final class ScanUIDrive: DriveAccess {
    private let scenario = ProcessInfo.processInfo.environment["OPENMP3_SCAN_SCENARIO"] ?? "finished"
    func inspectRoot(_ root: RootFolder) async throws -> DriveEntry {
        if scenario == "failed" { throw DriveFailure.access }
        return DriveEntry(id: root.id, name: "Fixture", mimeType: DriveEntry.folderType)
    }
    func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage {
        let empty = scenario == "empty" || scenario == "incomplete-empty"
        return DrivePage(files: empty ? [] : [DriveEntry(id: "sample", name: "Example track.mp3", mimeType: "audio/mpeg")],
                         incompleteSearch: scenario == "incomplete" || scenario == "incomplete-empty",
                         coverageWarning: "Undocumented webpage: pagination and descendant resource keys unverified")
    }
    func mediaURL(_ track: DiscoveredTrack) throws -> URL { throw DriveFailure.access }
}
