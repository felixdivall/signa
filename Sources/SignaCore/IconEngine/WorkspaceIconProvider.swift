import AppKit
import CryptoKit
import Foundation

/// Applies icons with the same mechanism Finder's Get Info window uses.
///
/// The icon is stored beside the application's contents rather than inside
/// them, so the application's own files, and its signature over them, are
/// never modified.
public struct WorkspaceIconProvider: IconProvider {
    public init() {}

    public func apply(iconAt iconURL: URL, to applicationURL: URL) async throws -> IconFingerprint {
        try await MainActor.run {
            try Self.checkAccess(to: applicationURL)
            guard let image = NSImage(contentsOf: iconURL), image.isValid else {
                throw IconError.unreadableIcon
            }
            let workspace = NSWorkspace.shared
            // Finder keeps showing the previous custom icon when one is simply
            // overwritten. Taking the old one off first makes it look again.
            if Self.fingerprint(of: applicationURL) != nil {
                _ = workspace.setIcon(nil, forFile: applicationURL.path, options: [])
            }
            guard workspace.setIcon(image, forFile: applicationURL.path, options: []),
                let fingerprint = Self.fingerprint(of: applicationURL)
            else { throw IconError.permissionDenied }
            return fingerprint
        }
    }

    public func remove(from applicationURL: URL) async throws {
        try await MainActor.run {
            guard Self.fingerprint(of: applicationURL) != nil else { return }
            try Self.checkAccess(to: applicationURL)
            guard NSWorkspace.shared.setIcon(nil, forFile: applicationURL.path, options: []) else {
                throw IconError.permissionDenied
            }
        }
    }

    public func current(for applicationURL: URL) async -> IconFingerprint? {
        Self.fingerprint(of: applicationURL)
    }

    // MARK: - Inspection

    /// What it takes to change the icon of the application at this location.
    ///
    /// This looks only at ownership, permission bits and system protection. It
    /// deliberately does not ask the system "may I write here?", because macOS
    /// answers no to that for any application it guards until the user allows
    /// Signa to manage apps. That case is a permission to ask for, not a dead end.
    public static func access(to applicationURL: URL) -> AppAccess {
        let resolved = applicationURL.resolvingSymlinksInPath()
        var info = stat()
        guard stat(resolved.path, &info) == 0 else { return .sealed }
        // Applications that ship with macOS live on a sealed volume or carry the system's own lock.
        let readOnlyVolume = (try? resolved.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) ?? false
        if resolved.path.hasPrefix("/System/") || readOnlyVolume || info.st_flags & UInt32(SF_RESTRICTED) != 0 {
            return .sealed
        }
        let mode = info.st_mode
        if info.st_uid == getuid() { return mode & S_IWUSR != 0 ? .open : .sealed }
        if mode & S_IWOTH != 0 { return .open }
        if mode & S_IWGRP != 0 {
            var groups = [gid_t](repeating: 0, count: Int(NGROUPS_MAX))
            let count = getgroups(Int32(groups.count), &groups)
            if count > 0, groups.prefix(Int(count)).contains(info.st_gid) { return .open }
        }
        // Someone else's, typically the system administrator's after an installer or the App Store.
        return .administrator
    }

    private static func checkAccess(to applicationURL: URL) throws {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw IconError.applicationNotFound
        }
        switch access(to: applicationURL) {
        case .open: return
        case .administrator: throw IconError.needsAdministrator
        case .sealed: throw IconError.locked
        }
    }

    static let customIconFile = "Icon\r"

    static func fingerprint(of applicationURL: URL) -> IconFingerprint? {
        guard hasCustomIconFlag(applicationURL) else { return nil }
        let iconFile = applicationURL.appendingPathComponent(customIconFile)
        guard let fork = extendedAttribute(XATTR_RESOURCEFORK_NAME, of: iconFile), !fork.isEmpty else {
            return nil
        }
        let digest = SHA256.hash(data: fork)
        return IconFingerprint(rawValue: digest.map { String(format: "%02x", $0) }.joined())
    }

    /// Finder only shows a custom icon while this flag is set on the bundle.
    static func hasCustomIconFlag(_ applicationURL: URL) -> Bool {
        guard let info = extendedAttribute(XATTR_FINDERINFO_NAME, of: applicationURL), info.count >= 10
        else { return false }
        let hasCustomIcon: UInt8 = 0x04
        return info[info.startIndex + 8] & hasCustomIcon != 0
    }

    static func extendedAttribute(_ name: String, of url: URL) -> Data? {
        url.withUnsafeFileSystemRepresentation { path -> Data? in
            guard let path else { return nil }
            let size = getxattr(path, name, nil, 0, 0, 0)
            guard size > 0 else { return nil }
            var data = Data(count: size)
            let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, 0) }
            return read == size ? data : nil
        }
    }
}
