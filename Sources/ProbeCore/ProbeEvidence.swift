import Foundation

/// Publishable aggregate evidence. Raw identities, names, paths and resource keys
/// remain in memory; even deterministic hashes of names can disclose metadata.
public struct ProbeEvidence: Encodable {
    public let schema = 2
    public let mode = "anonymous-no-key"
    public let gate = "OPEN — representative discovery and scan-budget evidence unresolved"
    public let controls: ExperimentControls
    public let scan: ScanObservation
    public let requests: [HTTPObservation]
    public let discoveredTracks: Int
    public let tracksByDepth: [String: Int]
    public let duplicateFilenameGroups: Int
    public let media: [String]
    public let nativeAudio = "not tested by this network command"
}

extension ProbeApplication {
    public func evidence(controls: ExperimentControls, requests: [HTTPObservation], media: [String]) -> ProbeEvidence {
        let depths = Dictionary(grouping: tracks, by: { String($0.path.count) }).mapValues(\.count)
        let duplicateNames = Dictionary(grouping: tracks, by: { $0.entry.name }).values.filter { $0.count > 1 }.count
        return ProbeEvidence(controls: controls, scan: scanObservation, requests: requests,
                             discoveredTracks: tracks.count, tracksByDepth: depths,
                             duplicateFilenameGroups: duplicateNames, media: media)
    }
}
