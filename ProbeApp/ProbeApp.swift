import SwiftUI
import AVFoundation
#if canImport(ProbeCore)
import ProbeCore
#endif

@main struct OpenMP3ProbeApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.environment["OPENMP3_RUN_SMOKE"] == "1" || ProcessInfo.processInfo.environment["OPENMP3_PROBE"] == "1" {
                ProbeView()
            } else { PlayerContainer() }
        }
    }
}

struct PlayerContainer: View {
    @StateObject private var player = ProbeApplication(drive: AnonymousDrive(), audio: NativeAudio(), storage: LocalRootStorage())
    var body: some View { PlayerScreen(app: player) }
}

struct ProbeView: View {
    @Environment(\.scenePhase) private var phase
    @StateObject private var app: ProbeApplication
    private let drive: AnonymousDrive
    @State private var link = ProcessInfo.processInfo.environment["OPENMP3_ROOT_URL"] ?? ""
    @State private var audibleFirst = "not tested"
    @State private var audibleSeek = "not tested"
    @State private var audibleSecond = "not tested"
    @State private var naturalNext = "not tested"
    @State private var copied = false
    @State private var smokeStarted = false
    @State private var smokeStatus = "Manual mode"

    init() {
        let drive = AnonymousDrive()
        self.drive = drive
        _app = StateObject(wrappedValue: ProbeApplication(drive: drive, audio: NativeAudio()))
    }
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Anonymous Drive experiment")) {
                    Text("Feasibility gate OPEN. Discovery uses an undocumented webpage format. Complete coverage is unverified.")
                    Text("Streaming uses mobile data when on cellular.")
                    Text(smokeStatus)
                    TextField("Public Google Drive folder link", text: $link)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL).accessibilityLabel("Public folder URL")
                    Button("Scan") {
                        app.selectRoot(link)
                        Task { await app.scan() }
                    }.disabled(app.scanObservation.state == .scanning)
                    Button("Stop scan") { app.stopScan() }.disabled(app.scanObservation.state != .scanning)
                    Text("Scan: \(app.scanObservation.state.rawValue); \(app.tracks.count) discovered tracks")
                    Text("Listing requests: \(app.scanObservation.listingRequests); elapsed: \(app.scanObservation.elapsedSeconds, specifier: "%.2f")s")
                    if let error = app.error { Text(error).foregroundColor(.red) }
                    ForEach(Array(Set(app.scanObservation.reasons)).sorted(), id: \.self) { Text($0) }
                    ForEach(app.scanObservation.coverageNotices, id: \.self) { Text($0).foregroundColor(.secondary) }
                    ForEach(Array(app.failedFolderPaths.enumerated()), id: \.offset) { Text("Unreadable folder: " + $0.element.joined(separator: " / ")) }
                }
                Section(header: Text("Native playback")) {
                    Text("Queue source: \(app.playback.queueSource?.id ?? "none")")
                    Text("Selected root: \(app.selectedRoot?.id ?? "none")")
                    Text(app.playback.current?.entry.name ?? "No current track")
                    Text("\(app.playback.state): \(app.playback.seconds, specifier: "%.1f") / \(app.playback.duration, specifier: "%.1f")s")
                    Button("Play All") { app.playAll() }.disabled(app.tracks.isEmpty || app.scanObservation.state == .scanning)
                    Button("Pause") { app.pause() }
                    Button("Next track") { app.next() }
                    Button("Seek to midpoint") { app.seek(seconds: app.playback.duration / 2) }
                    Button("Seek near end (then wait for natural next)") { app.seek(seconds: max(0, app.playback.duration - 5)) }
                }
                Section(header: Text("Human audio observations")) {
                    observation("Audible first track", value: $audibleFirst)
                    observation("Audible seek", value: $audibleSeek)
                    observation("Audible second track", value: $audibleSecond)
                    observation("Natural next track", value: $naturalNext)
                    Button(copied ? "Evidence copied" : "Copy evidence") {
                        UIPasteboard.general.string = evidence
                        copied = true
                    }
                }
                Section(header: Text("Native events (not proof of audibility)")) {
                    ForEach(Array(app.playback.events.enumerated()), id: \.offset) { Text($0.element) }
                }
                Section(header: Text("Discovered tracks")) {
                    ForEach(app.tracks) { track in
                        VStack(alignment: .leading) {
                            Text(track.entry.name)
                            Text(track.path.isEmpty ? "Root" : track.path.joined(separator: " / ")).font(.caption)
                        }
                    }
                }
            }.navigationTitle("OpenMP3 Probe")
        }.onChange(of: phase) { if $0 != .active { app.stopScan(backgrounded: true) } }
        .task(id: phase) {
            guard phase == .active, !smokeStarted, ProcessInfo.processInfo.environment["OPENMP3_RUN_SMOKE"] == "1" else { return }
            smokeStarted = true
            smokeStatus = "Automated smoke: scanning"
            writeSmokeEvidence("Started; native playback not yet tested")
            app.selectRoot(link)
            await app.scan()
            guard !Task.isCancelled else { writeSmokeEvidence("Stopped: app left foreground during scan"); return }
            smokeStatus = "Automated smoke: native playback"
            writeSmokeEvidence("Scan settled; native playback in progress")
            let results = await runNativeSmoke(app) { smokeStatus = $0 }
            smokeStatus = "Automated smoke finished; report saved"
            writeSmokeEvidence(results.joined(separator: "\n"))
        }
    }
    private func writeSmokeEvidence(_ results: String) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let report = evidence + "\nAutomated native procedure:\n" + results
        do { try report.write(to: documents.appendingPathComponent("smoke.txt"), atomically: true, encoding: .utf8) }
        catch { smokeStatus = "Could not save smoke evidence" }
    }

    private func observation(_ title: String, value: Binding<String>) -> some View {
        Picker(title, selection: value) {
            ForEach(["not tested", "pass", "fail"], id: \.self) { Text($0) }
        }
    }
    private var evidence: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let network = (try? encoder.encode(drive.observations)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
        OpenMP3 T01 — gate OPEN
        Device: \(UIDevice.current.model); OS: \(UIDevice.current.systemVersion)
        Physical device / exact model: RECORD MANUALLY (simulator is not physical evidence)
        Audio route: \(AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", "))
        Access: anonymous-no-key
        First track: \(audibleFirst); seek: \(audibleSeek); second track: \(audibleSecond); natural next: \(naturalNext)
        Scan: \(app.scanObservation.state.rawValue); tracks: \(app.tracks.count); requests: \(app.scanObservation.listingRequests); elapsed: \(app.scanObservation.elapsedSeconds)
        Native events:
        \(app.playback.events.joined(separator: "\n"))
        Listing HTTP observations (AVPlayer traffic is separate):
        \(network)
        Legacy compatibility, Maps, interruptions and remote controls: NOT TESTED
        """
    }
}
