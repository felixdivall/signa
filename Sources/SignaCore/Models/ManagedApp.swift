import Foundation

/// An application whose icon Signa looks after.
public struct ManagedApp: Identifiable, Codable, Hashable, Sendable {
    public typealias ID = UUID

    /// Something that currently stops Signa from keeping the icon in place.
    public enum Issue: String, Codable, Sendable {
        case needsPermission
        /// An update replaced an application that only an administrator can change.
        case needsPassword
        case missing
    }

    /// What the user sees next to the application name.
    public enum Status: Sendable {
        case needsIcon
        case readyToApply
        case protected
        case unprotected
        case needsPermission
        case needsPassword
        case missing
    }

    public let id: ID
    public var bundleIdentifier: String
    public var applicationPath: String
    public var name: String
    /// The icon Signa has installed on the application.
    public var customIcon: IconAsset.ID?
    /// An icon the user picked but has not applied yet.
    public var stagedIcon: IconAsset.ID?
    /// "Keep after updates".
    public var enabled: Bool
    public var appliedFingerprint: IconFingerprint?
    /// When the icon was last put on the application, by the user or by Signa.
    public var iconAppliedAt: Date?
    public var lastRestored: Date?
    public var issue: Issue?
    public var dateAdded: Date

    public init(
        id: ID = UUID(),
        bundleIdentifier: String,
        applicationPath: String,
        name: String,
        enabled: Bool = ManagedApp.keepsAfterUpdatesByDefault,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.applicationPath = applicationPath
        self.name = name
        self.enabled = enabled
        self.dateAdded = dateAdded
    }

    /// Persistence is the point of Signa, so new applications opt in.
    public static let keepsAfterUpdatesByDefault = true

    public var url: URL {
        URL(fileURLWithPath: applicationPath, isDirectory: true)
    }

    /// Whether Signa should restore this application's icon when it changes.
    public var isGuarded: Bool {
        enabled && customIcon != nil
    }

    /// Whether the application is still showing an older icon in the Dock.
    /// macOS keeps the Dock icon of an application that is already open, so a
    /// change only shows there once the application has been opened again.
    public func awaitsRelaunch(_ state: RunningAppState) -> Bool {
        guard customIcon != nil, let iconAppliedAt, case .running(let launched?) = state else { return false }
        return launched < iconAppliedAt
    }

    public var status: Status {
        switch issue {
        case .missing: return .missing
        case .needsPermission: return .needsPermission
        case .needsPassword: return .needsPassword
        case nil: break
        }
        if stagedIcon != nil { return .readyToApply }
        guard customIcon != nil else { return .needsIcon }
        return enabled ? .protected : .unprotected
    }
}
