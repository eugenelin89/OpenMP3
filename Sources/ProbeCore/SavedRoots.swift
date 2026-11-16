import Foundation

public struct SavedRoot: Codable, Identifiable {
    public let root: RootFolder
    public var name: String
    public var id: String { root.id }
}
public struct SavedRootState: Codable {
    public var roots: [SavedRoot] = []
    public var selectedID: String?
    public init() {}
}
@MainActor public protocol RootStorage {
    func load() throws -> SavedRootState
    func save(_ state: SavedRootState) throws
}
@MainActor public final class LocalRootStorage: RootStorage {
    private let defaults: UserDefaults
    private let key = "OpenMP3.savedRoots.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() throws -> SavedRootState {
        guard let data = defaults.data(forKey: key) else { return SavedRootState() }
        return try JSONDecoder().decode(SavedRootState.self, from: data)
    }
    public func save(_ state: SavedRootState) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }
}
struct SessionCollection {
    let tracks: [DiscoveredTrack]
    let scan: ScanObservation
    let failedPaths: [[String]]
    let error: String?
}

extension RootFolder {
    public var link: String {
        var url = URLComponents()
        url.scheme = "https"; url.host = "drive.google.com"
        url.path = "/drive/folders/" + id
        if let resourceKey { url.queryItems = [URLQueryItem(name: "resourcekey", value: resourceKey)] }
        return url.string ?? ""
    }
}
