import Foundation
import ProbeCore

@main struct DriveProbe {
    @MainActor static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args.isEmpty || args.contains("--help") {
                print("""
                drive-probe --root-file PATH --output PATH [--ranges] [--requests N] [--seconds N]
                Anonymous no-key experiment. Root file contains only the authorized folder URL.
                --ranges explicitly samples two byte ranges from each of the first two discovered tracks.
                All bounds are TEMPORARY EXPERIMENT CONTROLS, not measured application budgets.
                Reports omit shared URLs, resource keys, filenames and raw Drive identities.
                """)
                return
            }
            var options: [String: String] = [:]
            var ranges = false, index = 0
            while index < args.count {
                if args[index] == "--ranges" { ranges = true; index += 1; continue }
                guard ["--root-file", "--output", "--requests", "--seconds"].contains(args[index]), index + 1 < args.count else { throw UsageError() }
                options[args[index]] = args[index + 1]; index += 2
            }
            guard let rootPath = options["--root-file"], let output = options["--output"] else { throw UsageError() }
            var controls = ExperimentControls()
            if let value = options["--requests"] { guard let number = Int(value) else { throw UsageError() }; controls.listingRequests = number }
            if let value = options["--seconds"] { guard let number = Double(value) else { throw UsageError() }; controls.seconds = number }
            guard controls.isValid else { throw UsageError() }
            let drive = AnonymousDrive()
            let app = ProbeApplication(drive: drive)
            app.selectRoot(try String(contentsOfFile: rootPath, encoding: .utf8))
            guard app.selectedRoot != nil else { print("Invalid Google Drive folder link"); exit(2) }
            await app.scan(controls: controls)
            var mediaResults: [String] = []
            if ranges {
                for track in app.tracks.prefix(2) {
                    for offset in [0, 65_536] {
                        do { try await drive.sampleMedia(track, offset: offset); mediaResults.append("range retrieval passed") }
                        catch { mediaResults.append("range retrieval failed") }
                    }
                }
            }
            let report = app.evidence(controls: controls, requests: drive.observations, media: mediaResults)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: output), options: .atomic)
            print("Discovered \(app.tracks.count) tracks; scan \(app.scanObservation.state). Report written. Gate OPEN.")
        } catch {
            // Do not emit error descriptions that can contain shared URLs or keys.
            print("Probe failed: check arguments, local file access, and the evidence report. Use --help.")
            exit(2)
        }
    }
    struct UsageError: Error {}
}
