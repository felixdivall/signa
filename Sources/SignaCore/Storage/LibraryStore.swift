import Foundation

/// Persists the list of managed applications. Icon files live elsewhere,
/// in an `IconAssetStoring`.
public protocol LibraryStoring: Sendable {
    func load() throws -> [ManagedApp]
    func save(_ apps: [ManagedApp]) throws
}

/// Stores the library as a single human-readable JSON file.
public struct JSONLibraryStore: LibraryStoring {
    private struct Manifest: Codable {
        var version: Int
        var applications: [ManagedApp]
    }

    private static let currentVersion = 1

    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("Library.json")
    }

    public func load() throws -> [ManagedApp] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Manifest.self, from: Data(contentsOf: fileURL)).applications
    }

    public func save(_ apps: [ManagedApp]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(Manifest(version: Self.currentVersion, applications: apps))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
