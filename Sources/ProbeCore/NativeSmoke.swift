import Foundation

/// An opt-in real-player procedure, separate from deterministic behavioral tests.
/// A human must still report audibility and the physical device/audio route.
@MainActor public func runNativeSmoke(_ app: ProbeApplication, onStage: (String) -> Void = { _ in }) async -> [String] {
    var results: [String] = []
    let deadline = ProcessInfo.processInfo.systemUptime + 90
    func waitFor(_ condition: () -> Bool) async -> Bool {
        while !condition(), ProcessInfo.processInfo.systemUptime < deadline, !Task.isCancelled {
            if app.playback.state == "failed" { return false }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return !Task.isCancelled && condition()
    }
    guard app.tracks.count >= 2 else { return ["NOT TESTED: need at least two discovered tracks"] }
    onStage("Listen: first track")
    app.playAll()
    defer { app.pause() }
    guard await waitFor({ app.playback.index == 0 && app.playback.seconds >= 6 && app.playback.duration > 20 }) else {
        return ["FAIL: first native item did not progress before timeout"]
    }
    results.append("PASS: first native item progressed; audibility requires human confirmation")
    let target = app.playback.duration / 2
    let beforeSeek = app.playback.events.count
    onStage("Listen: midpoint seek and continued audio")
    app.seek(seconds: target)
    guard await waitFor({ app.playback.events.dropFirst(beforeSeek).contains(where: { $0.hasPrefix("Seek completed") }) && abs(app.playback.seconds - target) < 3 }) else {
        return results + ["FAIL: midpoint seek not confirmed before timeout"]
    }
    guard await waitFor({ app.playback.index == 0 && app.playback.seconds >= target + 5 && app.playback.seconds < app.playback.duration }) else {
        return results + ["FAIL: playback did not progress after midpoint seek"]
    }
    results.append("PASS: native midpoint seek completed and playback progressed afterward")
    onStage("Listen: end of first track, then automatic second track")
    app.seek(seconds: max(0, app.playback.duration - 4))
    guard await waitFor({ app.playback.index == 1 && app.playback.duration > 0 && app.playback.seconds >= 6 && app.playback.seconds < app.playback.duration }) else {
        return results + ["FAIL: natural second-track progression not observed before timeout"]
    }
    results.append("PASS: natural end advanced to second native item and time progressed; audibility requires human confirmation")
    return results
}
