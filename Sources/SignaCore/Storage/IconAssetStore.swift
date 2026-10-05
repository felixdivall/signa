import CryptoKit
import Foundation

/// Keeps icon files in Signa's own storage, independent of the applications
/// that use them.
public protocol IconAssetStoring: Sendable {
    /// Saves a rendered icon together with the artwork it was made from.
    func store(_ icon: RenderedIcon) throws -> IconAsset.ID
    /// The `.icns` file for an asset.
    func iconURL(for id: IconAsset.ID) -> URL
    /// The original artwork the user provided, if it is still available.
    func sourceURL(for id: IconAsset.ID) -> URL?
    func remove(_ id: IconAsset.ID)
    func allIDs() -> [IconAsset.ID]
}

/// One folder per asset: `Icons/<id>/icon.icns` plus `source.<ext>`.
/// The folder leaves room for more renditions of the same artwork later.
public struct FileIconAssetStore: IconAssetStoring {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory.appendingPathComponent("Icons", isDirectory: true)
    }

    public func store(_ icon: RenderedIcon) throws -> IconAsset.ID {
        // Content-derived, so dropping the same artwork twice reuses one asset.
        let digest = SHA256.hash(data: icon.source)
        let id = IconAsset.ID(rawValue: digest.prefix(16).map { String(format: "%02x", $0) }.joined())
        let folder = folder(for: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try icon.icns.write(to: iconURL(for: id), options: .atomic)
        try icon.source.write(
            to: folder.appendingPathComponent("source.\(icon.sourceExtension)"), options: .atomic)
        return id
    }

    public func iconURL(for id: IconAsset.ID) -> URL {
        folder(for: id).appendingPathComponent("icon.icns")
    }

    public func sourceURL(for id: IconAsset.ID) -> URL? {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: folder(for: id), includingPropertiesForKeys: nil)
        return contents?.first { $0.deletingPathExtension().lastPathComponent == "source" }
    }

    public func remove(_ id: IconAsset.ID) {
        try? FileManager.default.removeItem(at: folder(for: id))
    }

    public func allIDs() -> [IconAsset.ID] {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        return (contents ?? []).map { IconAsset.ID(rawValue: $0.lastPathComponent) }
    }

    private func folder(for id: IconAsset.ID) -> URL {
        directory.appendingPathComponent(id.rawValue, isDirectory: true)
    }
}
