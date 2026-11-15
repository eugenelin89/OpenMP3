import Foundation

public struct DriveEntry: Equatable, Decodable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let resourceKey: String?
    public let webContentLink: URL?
    public let capabilities: Capabilities?
    public struct Capabilities: Equatable, Decodable { public let canDownload: Bool? }
    public init(id: String, name: String, mimeType: String, resourceKey: String? = nil) {
        self.id = id; self.name = name; self.mimeType = mimeType; self.resourceKey = resourceKey
        webContentLink = nil; capabilities = nil
    }
    public static let folderType = "application/vnd.google-apps.folder"
    public static let shortcutType = "application/vnd.google-apps.shortcut"
}

public struct DrivePage: Decodable {
    public let files: [DriveEntry]
    public let nextPageToken: String?
    public let incompleteSearch: Bool?
    public let coverageWarning: String?
    public init(files: [DriveEntry], nextPageToken: String? = nil, incompleteSearch: Bool? = nil, coverageWarning: String? = nil) {
        self.files = files; self.nextPageToken = nextPageToken; self.incompleteSearch = incompleteSearch; self.coverageWarning = coverageWarning
    }
}

public struct DiscoveredTrack: Equatable, Identifiable {
    public let entry: DriveEntry
    public let path: [String]
    public var id: String { entry.id }
}

public enum DriveFailure: Error, Equatable {
    case access, transient, malformedResponse, restriction, experimentalLimit
}

@MainActor public protocol DriveAccess {
    func inspectRoot(_ root: RootFolder) async throws -> DriveEntry
    func list(_ folder: RootFolder, pageToken: String?) async throws -> DrivePage
    func mediaURL(_ track: DiscoveredTrack) throws -> URL
}

/// These are explicitly temporary experiment controls, NOT measured application budgets.
public struct ExperimentControls: Codable {
    public var listingRequests = 20
    public var seconds: Double = 60
    public var retriesPerRequest = 1
    public var totalRetries = 2
    public var retryDelay: Double = 1
    public var folders = 100
    public var tracks = 1_000
    public init() {}
    public var isValid: Bool {
        listingRequests > 0 && seconds.isFinite && seconds > 0 && retriesPerRequest >= 0 && totalRetries >= 0 &&
        retryDelay.isFinite && retryDelay >= 0 && folders > 0 && tracks > 0
    }
}

public struct ScanObservation: Codable {
    public var state = "not started"
    public var listingRequests = 0
    public var metadataRequests = 0
    public var retries = 0
    public var folders = 0
    public var shortcuts = 0
    public var ignoredFiles = 0
    public var elapsedSeconds: Double = 0
    public var reasons: [String] = []
}
