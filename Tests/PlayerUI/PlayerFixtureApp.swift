import SwiftUI

@main struct PlayerFixtureApp: App {
    @StateObject private var app = ProbeApplication(drive: PlayerFixtureDrive(), audio: PlayerFixtureAudio())
    var body: some Scene {
        WindowGroup {
            PlayerScreen(app: app).task {
                guard ProcessInfo.processInfo.environment["OPENMP3_PLAYER_SCENARIO"] != "empty" else { return }
                app.selectRoot("https://drive.google.com/drive/folders/fixture")
                app.saveSelectedRoot(name: "Ready collection")
                await app.scan()
                if ProcessInfo.processInfo.environment["OPENMP3_PLAYER_SCENARIO"] == "pending" {
                    app.play()
                    app.selectRoot("https://drive.google.com/drive/folders/upcoming")
                    app.saveSelectedRoot(name: "Upcoming collection")
                    await app.scan()
                }
            }
        }
    }
}
@MainActor private final class PlayerFixtureDrive: DriveAccess {
    func inspectRoot(_ root: RootFolder) async throws -> DriveEntry { DriveEntry(id: root.id, name: "Fixture", mimeType: DriveEntry.folderType) }
    func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage {
        DrivePage(files: (1...3).map { DriveEntry(id: "fixture-\($0)", name: "Test track \($0).mp3", mimeType: "audio/mpeg") })
    }
    func mediaURL(_ track: DiscoveredTrack) throws -> URL { URL(string: "https://example.invalid")! }
}
@MainActor private final class PlayerFixtureAudio: AudioOutput {
    var onCommand: ((PlayerCommand) -> Void)?
    var onEvent: ((AudioEvent) -> Void)?
    func start(url: URL, id: String, playing: Bool) throws { onEvent?(.ready(id: id, duration: 120)) }
    func resume() throws {}
    func pause() {}
    func seek(seconds: Double) {}
}
