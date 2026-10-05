import AppKit
import Foundation

/// The facts Signa needs about an application on disk.
public struct AppInfo: Equatable, Sendable {
    public let bundleIdentifier: String
    public let name: String

    public init(bundleIdentifier: String, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }
}

public protocol AppInspecting: Sendable {
    /// Returns nil when there is no complete application at the location.
    func info(at applicationURL: URL) -> AppInfo?
    /// What it takes to change the application's icon.
    func access(to applicationURL: URL) -> AppAccess
}

public struct BundleAppInspector: AppInspecting {
    public init() {}

    public func info(at applicationURL: URL) -> AppInfo? {
        // Read the file directly: `Bundle` caches, and would keep describing
        // the previous version of an application that was just updated.
        let plistURL = applicationURL.appendingPathComponent("Contents/Info.plist")
        guard
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
            let identifier = plist["CFBundleIdentifier"] as? String,
            let executable = plist["CFBundleExecutable"] as? String,
            FileManager.default.fileExists(
                atPath: applicationURL.appendingPathComponent("Contents/MacOS/\(executable)").path)
        else { return nil }

        var name = FileManager.default.displayName(atPath: applicationURL.path)
        if name.lowercased().hasSuffix(".app") { name.removeLast(4) }
        return AppInfo(bundleIdentifier: identifier, name: name)
    }

    public func access(to applicationURL: URL) -> AppAccess {
        WorkspaceIconProvider.access(to: applicationURL)
    }
}

/// Reads icons for display.
@MainActor
public enum AppIconReader {
    /// The icon the application shows right now, custom or not.
    public static func currentIcon(of applicationURL: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: applicationURL.path)
    }

    /// The icon the application ships with, ignoring any custom icon.
    public static func originalIcon(of applicationURL: URL) -> NSImage {
        guard WorkspaceIconProvider.fingerprint(of: applicationURL) != nil else {
            return currentIcon(of: applicationURL)
        }
        if let bundle = Bundle(url: applicationURL) {
            let info = bundle.infoDictionary ?? [:]
            for key in ["CFBundleIconFile", "CFBundleIconName"] {
                if let name = info[key] as? String, let image = bundle.image(forResource: name) {
                    return image
                }
            }
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
